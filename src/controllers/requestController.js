// ============================================================
// Request Controller — Corporate Pooling Backend
// Full Request Lifecycle with Atomic Stored Procedures & FCM Push Pipeline
// Source of Truth: SRS §5.3, §8.1 (Escrow & Multi-Request), §8.3 (Cancellations), §8.9, §15.2, §21.2
// ============================================================

'use strict';

const { supabaseAdmin } = require('../config/supabase');
const { generatePickupOtp } = require('../services/otpService');
const walletService = require('../services/walletService');
const notificationService = require('../services/notificationService');
const { ok, created, badRequest, notFound, forbidden, conflict, serverError } = require('../utils/response');

// ============================================================
// SUBTASK 6.1: CREATE RIDE REQUEST (RIDER)
// POST /api/v1/rides/:id/request
// Body: { pickup_address, pickup_lat, pickup_lng, drop_address, drop_lat, drop_lng,
//         seats_requested, pickup_distance_m }
// ============================================================

async function createRequest(req, res) {
  try {
    const rideId = req.params.id;
    const riderId = req.user.id;
    const {
      pickup_address, pickup_lat, pickup_lng,
      drop_address, drop_lat, drop_lng,
      seats_requested = 1,
      pickup_distance_m = 0,
      pickup_route_index = null,
      drop_route_index = null,
    } = req.body;

    // 1. Basic format validation
    if (!pickup_address || !drop_address) return badRequest(res, 'Pickup and drop addresses are required.');
    if (!pickup_lat || !pickup_lng || !drop_lat || !drop_lng) return badRequest(res, 'Valid coordinates are required.');

    const seats = Math.max(1, parseInt(seats_requested, 10) || 1);
    const pLat = parseFloat(pickup_lat);
    const pLng = parseFloat(pickup_lng);
    const dLat = parseFloat(drop_lat);
    const dLng = parseFloat(drop_lng);
    const detourMeters = parseFloat(pickup_distance_m) || 0;

    // 2. Fetch ride details
    const { data: ride, error: rideErr } = await supabaseAdmin
      .from('rides')
      .select('id, driver_id, ride_status, seats_available, vehicle_type, distance_km, time_type, women_only')
      .eq('id', rideId)
      .single();

    if (rideErr || !ride) return notFound(res, 'Ride not found.');

    // ─── PRE-FLIGHT EXCLUSION GATES (SRS §6.6) ───────────────
    // Gate 1: Driver self-booking guard
    if (ride.driver_id === riderId) {
      return badRequest(res, 'You cannot request your own ride.');
    }

    // Gate 2: Active ride status guard
    if (ride.ride_status !== 'posted' && ride.ride_status !== 'started') {
      return badRequest(res, `Ride is no longer open for booking (status: ${ride.ride_status}).`);
    }

    // Gate 3: Available capacity guard
    if ((ride.seats_available || 0) < seats) {
      return badRequest(res, `Insufficient seats available. Only ${ride.seats_available || 0} seats left.`);
    }

    // Gate 4: 2-Wheeler capacity guard (SRS §6.6 Gate 3)
    const isBike = ride.vehicle_type === 'bike' || ride.vehicle_type === 'scooter' || ride.vehicle_type === 'motorcycle';
    if (isBike && seats > 1) {
      return badRequest(res, 'Two-wheelers only support 1 passenger seat.');
    }

    // Gate 5: Women-Only safety guard (SRS §6.6 Gate 1)
    if (ride.women_only && req.user.gender !== 'female') {
      return forbidden(res, 'This ride is reserved exclusively for women commuters.');
    }

    // Gate 6: Duplicate active request guard
    const { data: existing } = await supabaseAdmin
      .from('ride_requests')
      .select('id, status')
      .eq('ride_id', rideId)
      .eq('rider_id', riderId)
      .single();

    if (existing && ['pending', 'accepted'].includes(existing.status)) {
      return conflict(res, 'You already have an active request for this ride.');
    }

    // 3. Multi-Seat & Detour Fare Calculation (SRS §4.9 & §5.3)
    const fareEstimate = walletService.calculateFare(
      Number(ride.distance_km) || 10.0,
      ride.vehicle_type,
      detourMeters,
      seats
    );

    // 4. 3-Tier Wallet Solvency Check (SRS §11.2)
    const isRecurring = ride.time_type === 'recurring';
    const solvency = await walletService.checkSufficiency(riderId, fareEstimate.total_rider_fare, isRecurring);
    if (!solvency.sufficient) {
      return badRequest(res, solvency.message);
    }

    // 5. Generate 4-digit spoken boarding PIN / OTP (SRS §8.9)
    const otp = generatePickupOtp();

    // 6. Create request record in public.ride_requests
    const { data: request, error: insertErr } = await supabaseAdmin
      .from('ride_requests')
      .insert({
        ride_id: rideId,
        rider_id: riderId,
        pickup_address,
        pickup_lat: pLat,
        pickup_lng: pLng,
        drop_address,
        drop_lat: dLat,
        drop_lng: dLng,
        seats_requested: seats,
        pickup_route_index: pickup_route_index || null,
        drop_route_index: drop_route_index || null,
        pickup_distance_m: Math.round(detourMeters),
        coins_locked: fareEstimate.total_rider_fare,
        otp,
        status: 'pending',
      })
      .select()
      .single();

    if (insertErr) {
      console.error('[RequestController] Request creation insert error:', insertErr.message);
      return serverError(res, insertErr, 'Failed to create ride request.');
    }

    // 7. Fire Push Notification to Driver (SRS §16.3)
    notificationService.sendPushNotification(
      ride.driver_id,
      '🚗 New Ride Request!',
      `${req.user.full_name || 'A colleague'} requested ${seats} seat(s) on your route. Tap to view.`,
      'ride_request',
      { request_id: request.id, ride_id: rideId }
    ).catch((e) => console.warn('[RequestController] Driver push dispatch failed:', e.message));

    return created(res, {
      request,
      fare_breakdown: fareEstimate,
      solvency_info: solvency,
    }, 'Ride request sent. Waiting for driver to accept.');
  } catch (err) {
    return serverError(res, err);
  }
}

// ============================================================
// SUBTASK 6.2: ATOMIC REQUEST ACCEPTANCE (DRIVER)
// PATCH /api/v1/requests/:id/accept
// ============================================================

async function acceptRequest(req, res) {
  try {
    const reqId = req.params.id;
    const driverId = req.user.id;

    // 1. Fetch request details to verify existence & fetch rider ID
    const { data: rideReq, error: reqErr } = await supabaseAdmin
      .from('ride_requests')
      .select('id, ride_id, rider_id, status, seats_requested, coins_locked')
      .eq('id', reqId)
      .single();

    if (reqErr || !rideReq) return notFound(res, 'Ride request not found.');
    if (rideReq.status !== 'pending') return badRequest(res, `Request is already in status '${rideReq.status}'.`);

    // 2. Call live PostgreSQL Stored Procedure: accept_ride_request_atomic(p_request_id, p_driver_id)
    // Executes inside row-level lock (FOR UPDATE):
    // • Decrements seats_available
    // • Transfers coins from available_balance -> locked_balance (escrow)
    // • Auto-cancels competing requests to other drivers (SRS §8.1 Multi-Request Rule)
    // • Provisions / joins per-ride chat room
    const { data: rpcResult, error: rpcErr } = await supabaseAdmin.rpc('accept_ride_request_atomic', {
      p_request_id: reqId,
      p_driver_id: driverId,
    });

    if (rpcErr) {
      console.error('[RequestController] accept_ride_request_atomic error:', rpcErr.message);
      return badRequest(res, rpcErr.message || 'Failed to accept request.');
    }

    // 3. Fire High-Priority Push Notification to Rider (SRS §16.3)
    notificationService.sendPushNotification(
      rideReq.rider_id,
      '🎉 Ride Confirmed!',
      `${req.user.full_name || 'Driver'} accepted your ride request. Tap to track live route.`,
      'request_accepted',
      { request_id: reqId, ride_id: rideReq.ride_id }
    ).catch((e) => console.warn('[RequestController] Rider accept push failed:', e.message));

    return ok(res, {
      request_id: reqId,
      ride_id: rideReq.ride_id,
      status: 'accepted',
      rpc_details: rpcResult,
    }, 'Ride request accepted successfully. Rider notified.');
  } catch (err) {
    return serverError(res, err);
  }
}

// ============================================================
// SUBTASK 6.3: REJECT REQUEST (DRIVER)
// PATCH /api/v1/requests/:id/reject
// ============================================================

async function rejectRequest(req, res) {
  try {
    const reqId = req.params.id;
    const driverId = req.user.id;

    // 1. Verify driver ownership & active pending state
    const { data: rideReq, error: reqErr } = await supabaseAdmin
      .from('ride_requests')
      .select('id, ride_id, rider_id, status, rides!inner(driver_id)')
      .eq('id', reqId)
      .single();

    if (reqErr || !rideReq) return notFound(res, 'Ride request not found.');
    if (rideReq.rides?.driver_id !== driverId) return forbidden(res, 'Unauthorized. Not your ride.');
    if (rideReq.status !== 'pending') return badRequest(res, `Cannot reject request in status '${rideReq.status}'.`);

    // 2. Update status to rejected
    await supabaseAdmin
      .from('ride_requests')
      .update({ status: 'rejected' })
      .eq('id', reqId);

    // 3. Fire Notification to Rider
    notificationService.sendPushNotification(
      rideReq.rider_id,
      'Ride Request Update',
      `${req.user.full_name || 'Driver'} was unable to accept your request. Tap to browse other available colleagues.`,
      'ride_cancelled',
      { ride_id: rideReq.ride_id }
    ).catch((e) => console.warn('[RequestController] Rider reject push failed:', e.message));

    return ok(res, { request_id: reqId, status: 'rejected' }, 'Request rejected.');
  } catch (err) {
    return serverError(res, err);
  }
}

// ============================================================
// SUBTASK 6.4: DYNAMIC CANCELLATION & LATE FEE ENGINE
// POST /api/v1/requests/:id/cancel
// Body: { reason: string }
// ============================================================

async function cancelRequest(req, res) {
  try {
    const reqId = req.params.id;
    const userId = req.user.id;
    const { reason = 'User requested cancellation' } = req.body;

    // 1. Fetch request details
    const { data: rideReq, error: reqErr } = await supabaseAdmin
      .from('ride_requests')
      .select('id, ride_id, rider_id, status, rides!inner(driver_id)')
      .eq('id', reqId)
      .single();

    if (reqErr || !rideReq) return notFound(res, 'Ride request not found.');

    const isRider = rideReq.rider_id === userId;
    const isDriver = rideReq.rides?.driver_id === userId;

    if (!isRider && !isDriver) {
      return forbidden(res, 'You are not authorized to cancel this booking.');
    }

    if (['completed', 'cancelled'].includes(rideReq.status)) {
      return badRequest(res, `Request is already '${rideReq.status}'.`);
    }

    // 2. Call live PostgreSQL Stored Procedure: cancel_ride_request_atomic(p_request_id, p_cancelled_by, p_reason)
    // Executes atomic cancellation:
    // • Handles >30 min free cancel vs <15 min late cancellation fee
    // • Restores seats_available on the ride
    // • Refunds escrow coins to rider wallet
    const { data: cancelResult, error: cancelErr } = await supabaseAdmin.rpc('cancel_ride_request_atomic', {
      p_request_id: reqId,
      p_cancelled_by: userId,
      p_reason: reason,
    });

    if (cancelErr) {
      console.error('[RequestController] cancel_ride_request_atomic error:', cancelErr.message);
      return badRequest(res, cancelErr.message || 'Failed to cancel booking.');
    }

    // 3. Notify counterpart
    const targetUserId = isRider ? rideReq.rides?.driver_id : rideReq.rider_id;
    const cancellerName = req.user.full_name || (isRider ? 'Rider' : 'Driver');

    notificationService.sendPushNotification(
      targetUserId,
      '⚠️ Ride Booking Cancelled',
      `${cancellerName} cancelled the booking. Reason: ${reason}.`,
      'ride_cancelled',
      { request_id: reqId, ride_id: rideReq.ride_id }
    ).catch((e) => console.warn('[RequestController] Cancel push failed:', e.message));

    return ok(res, {
      request_id: reqId,
      status: 'cancelled',
      cancellation_details: cancelResult,
    }, 'Ride booking cancelled successfully.');
  } catch (err) {
    return serverError(res, err);
  }
}

// ============================================================
// SUBTASK 6.5: REQUEST QUERIES & SINGLE REQUEST SHEET
// ============================================================

/**
 * GET /api/v1/requests/my
 * Paginated list of caller's active & completed ride requests.
 */
async function getMyRequests(req, res) {
  try {
    const userId = req.user.id;
    const { status, limit = 20, offset = 0 } = req.query;

    let query = supabaseAdmin
      .from('ride_requests')
      .select(`
        id, ride_id, rider_id, status, seats_requested, pickup_address, drop_address,
        pickup_lat, pickup_lng, drop_lat, drop_lng, pickup_distance_m, coins_locked,
        otp, otp_verified, created_at, updated_at,
        rides (
          id, driver_id, ride_status, from_address, to_address, depart_time, depart_date,
          vehicle_type, vehicle_model, vehicle_plate, distance_km,
          users!driver_id (
            id, full_name, phone_number, photo_url, trust_score, role, company_id
          )
        )
      `, { count: 'exact' })
      .eq('rider_id', userId)
      .order('created_at', { ascending: false })
      .range(parseInt(offset, 10), parseInt(offset, 10) + parseInt(limit, 10) - 1);

    if (status) query = query.eq('status', status);

    const { data: requests, error, count } = await query;
    if (error) return serverError(res, error, 'Failed to fetch ride requests.');

    return ok(res, {
      requests: requests || [],
      total_count: count || (requests || []).length,
      limit: parseInt(limit, 10),
      offset: parseInt(offset, 10),
    }, 'Ride requests retrieved successfully.');
  } catch (err) {
    return serverError(res, err);
  }
}

/**
 * GET /api/v1/requests/:id
 * Detailed single request sheet with live route and driver info.
 */
async function getRequestDetails(req, res) {
  try {
    const reqId = req.params.id;
    const userId = req.user.id;

    const { data: request, error } = await supabaseAdmin
      .from('ride_requests')
      .select(`
        *,
        rides (
          *,
          users!driver_id (
            id, full_name, phone_number, photo_url, trust_score, role, company_id,
            companies (name, domain)
          )
        )
      `)
      .eq('id', reqId)
      .single();

    if (error || !request) return notFound(res, 'Ride request not found.');

    // Enforce authorization: only rider, driver, or admin can view
    const isRider = request.rider_id === userId;
    const isDriver = request.rides?.driver_id === userId;
    const isAdmin = req.user.role === 'superadmin';

    if (!isRider && !isDriver && !isAdmin) {
      return forbidden(res, 'You do not have permission to view this request.');
    }

    return ok(res, request, 'Request details retrieved successfully.');
  } catch (err) {
    return serverError(res, err);
  }
}

module.exports = {
  createRequest,
  acceptRequest,
  rejectRequest,
  cancelRequest,
  getMyRequests,
  getRequestDetails,
};
