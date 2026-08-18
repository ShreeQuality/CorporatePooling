// ============================================================
// Request Controller — Corporate Pooling App
// Ride request lifecycle: create → accept/reject → OTP → arrive → complete
// ============================================================

'use strict';

const { supabaseAdmin } = require('../config/supabase');
const { generatePickupOtp } = require('../services/otpService');
const { clearDriverLocation } = require('../services/gpsService');
const { checkSufficiency } = require('../services/walletService'); // ← 3-Tier Waterfall (Subtask 2.3)
const { ok, created, badRequest, notFound, forbidden, conflict, serverError } = require('../utils/response');

// ─── Create Ride Request (Rider) ─────────────────────────────

/**
 * POST /rides/:id/request
 * Body: { pickup_address, pickup_lat, pickup_lng, drop_address, drop_lat, drop_lng }
 */
async function createRequest(req, res) {
  try {
    const rideId = req.params.id;
    const riderId = req.user.id;
    const { pickup_address, pickup_lat, pickup_lng, drop_address, drop_lat, drop_lng,
            pickup_route_index, drop_route_index, pickup_distance_m } = req.body;

    if (!pickup_address || !drop_address) return badRequest(res, 'Pickup and drop addresses required');
    if (!pickup_lat || !pickup_lng || !drop_lat || !drop_lng) return badRequest(res, 'Coordinates required');

    // Get ride
    const { data: ride } = await supabaseAdmin
      .from('rides').select('id, driver_id, ride_status, available_seats, coin_per_seat').eq('id', rideId).single();

    if (!ride) return notFound(res, 'Ride not found');
    if (ride.driver_id === riderId) return badRequest(res, 'You cannot request your own ride');
    if (ride.ride_status !== 'posted' && ride.ride_status !== 'started') {
      return badRequest(res, `Ride is not available (status: ${ride.ride_status})`);
    }
    if (ride.available_seats <= 0) return badRequest(res, 'Ride is full');

    // Check not already requested
    const { data: existing } = await supabaseAdmin
      .from('ride_requests')
      .select('id, status')
      .eq('ride_id', rideId)
      .eq('rider_id', riderId)
      .single();

    if (existing && ['pending', 'accepted'].includes(existing.status)) {
      return conflict(res, 'You already have a pending or accepted request for this ride');
    }

    // ── Wallet Solvency Check — 3-Tier Waterfall (walletService §2.3) ──────
    // Uses: Corporate Grant Balance → Personal Balance → Recurring Overdraft
    // This replaces the old flat coin_balance check which ignored grant coins.
    const coinsNeeded = ride.coin_per_seat;
    const isRecurring = ride.time_type === 'recurring';
    const solvency = await checkSufficiency(riderId, coinsNeeded, isRecurring);
    if (!solvency.sufficient) {
      return badRequest(res, solvency.message); // e.g. "Insufficient coins. Shortfall of 8 Coins."
    }

    // Generate pickup OTP
    const otp = generatePickupOtp();

    const { data: request, error } = await supabaseAdmin
      .from('ride_requests')
      .insert({
        ride_id: rideId,
        rider_id: riderId,
        pickup_address,
        pickup_lat: parseFloat(pickup_lat),
        pickup_lng: parseFloat(pickup_lng),
        drop_address,
        drop_lat: parseFloat(drop_lat),
        drop_lng: parseFloat(drop_lng),
        pickup_route_index: pickup_route_index || null,
        drop_route_index: drop_route_index || null,
        pickup_distance_m: pickup_distance_m || null,
        coins_locked: 0,  // locked on accept, not on request
        otp,
        status: 'pending',
      })
      .select()
      .single();

    if (error) return serverError(res, error, 'Failed to create request');
    return created(res, request, 'Ride request sent. Waiting for driver to accept.');
  } catch (err) {
    return serverError(res, err);
  }
}

// ─── Accept Request (Driver) ──────────────────────────────────

/**
 * PATCH /requests/:id/accept
 */
async function acceptRequest(req, res) {
  try {
    const reqId = req.params.id;
    const driverId = req.user.id;

    const { data: rideReq } = await supabaseAdmin
      .from('ride_requests')
      .select('id, ride_id, rider_id, coins_locked, status')
      .eq('id', reqId).single();

    if (!rideReq) return notFound(res, 'Request not found');
    if (rideReq.status !== 'pending') return badRequest(res, `Request is already ${rideReq.status}`);

    const { data: ride } = await supabaseAdmin
      .from('rides').select('driver_id, available_seats, coin_per_seat, ride_status').eq('id', rideReq.ride_id).single();

    if (!ride) return notFound(res, 'Ride not found');
    if (ride.driver_id !== driverId) return forbidden(res, 'Not your ride');
    if (ride.available_seats <= 0) return badRequest(res, 'Ride is full');

    // ── Re-verify rider solvency at accept time (walletService §2.3) ────────
    // Guards against the rare case where a rider's balance dropped between
    // request submission and driver acceptance.
    const riderSolvency = await checkSufficiency(rideReq.rider_id, ride.coin_per_seat, false);
    if (!riderSolvency.sufficient) {
      await supabaseAdmin.from('ride_requests').update({ status: 'rejected' }).eq('id', reqId);
      return badRequest(res, `Rider has insufficient coins (${riderSolvency.shortfall} Coins short). Request auto-rejected.`);
    }

    // ── Atomic ACID lock: escrow coins + accept request + decrement seat ─────
    // Calls 015_stored_procedures.sql → accept_ride_request_atomic()
    const { error: rpcErr } = await supabaseAdmin.rpc('accept_ride_request_atomic', {
      p_request_id: reqId,
      p_ride_id: rideReq.ride_id,
      p_rider_id: rideReq.rider_id,
      p_coins: ride.coin_per_seat,
    });

    if (rpcErr) return serverError(res, rpcErr, 'Failed to accept request');

    return ok(res, { request_id: reqId, coins_locked: ride.coin_per_seat }, 'Request accepted. Rider notified.');
  } catch (err) {
    return serverError(res, err);
  }
}

// ─── Reject Request (Driver) ──────────────────────────────────

/**
 * PATCH /requests/:id/reject
 */
async function rejectRequest(req, res) {
  try {
    const reqId = req.params.id;

    const { data: rideReq } = await supabaseAdmin
      .from('ride_requests').select('id, ride_id, status').eq('id', reqId).single();

    if (!rideReq) return notFound(res, 'Request not found');
    if (rideReq.status !== 'pending') return badRequest(res, `Request already ${rideReq.status}`);

    const { data: ride } = await supabaseAdmin
      .from('rides').select('driver_id').eq('id', rideReq.ride_id).single();
    if (!ride || ride.driver_id !== req.user.id) return forbidden(res, 'Not your ride');

    await supabaseAdmin.from('ride_requests').update({ status: 'rejected' }).eq('id', reqId);
    return ok(res, null, 'Request rejected');
  } catch (err) {
    return serverError(res, err);
  }
}

// ─── Verify Pickup OTP ────────────────────────────────────────

/**
 * POST /rides/:id/verify-otp
 * Body: { rider_id, otp }
 * Called by driver when rider shows OTP at pickup
 */
async function verifyPickupOtp(req, res) {
  try {
    const rideId = req.params.id;
    const { rider_id, otp } = req.body;
    if (!rider_id || !otp) return badRequest(res, 'rider_id and otp required');

    // Verify driver owns this ride
    const { data: ride } = await supabaseAdmin
      .from('rides').select('driver_id, ride_status').eq('id', rideId).single();
    if (!ride) return notFound(res, 'Ride not found');
    if (ride.driver_id !== req.user.id) return forbidden(res, 'Not your ride');
    if (!['started', 'in_progress'].includes(ride.ride_status)) {
      return badRequest(res, 'Ride not in progress');
    }

    // Find rider's request
    const { data: rideReq } = await supabaseAdmin
      .from('ride_requests')
      .select('id, otp, otp_verified, status')
      .eq('ride_id', rideId)
      .eq('rider_id', rider_id)
      .single();

    if (!rideReq) return notFound(res, 'Rider request not found');
    if (rideReq.otp_verified) return badRequest(res, 'OTP already verified');
    if (rideReq.otp !== String(otp)) return badRequest(res, 'Incorrect OTP');

    await supabaseAdmin.from('ride_requests').update({
      otp_verified: true,
      status: 'accepted',
    }).eq('id', rideReq.id);

    // If all riders are onboard, set ride to in_progress
    await supabaseAdmin.from('rides').update({ ride_status: 'in_progress' }).eq('id', rideId);

    return ok(res, { rider_id, otp_verified: true }, 'OTP verified. Rider onboard!');
  } catch (err) {
    return serverError(res, err);
  }
}

// ─── Driver Marks Arrival at Drop ────────────────────────────

/**
 * PATCH /requests/:id/driver-arrive
 * Driver signals they've arrived at rider's drop location
 */
async function driverMarkArrival(req, res) {
  try {
    const reqId = req.params.id;

    const { data: rideReq } = await supabaseAdmin
      .from('ride_requests').select('id, ride_id, rider_id, status, rider_marked_arrival').eq('id', reqId).single();
    if (!rideReq) return notFound(res, 'Request not found');

    const { data: ride } = await supabaseAdmin
      .from('rides').select('driver_id, ride_status').eq('id', rideReq.ride_id).single();
    if (!ride || ride.driver_id !== req.user.id) return forbidden(res, 'Not your ride');

    // If rider already marked arrival → mutual confirm → complete now
    // Calls 015_stored_procedures.sql → complete_single_dropoff()
    if (rideReq.rider_marked_arrival) {
      const result = await supabaseAdmin.rpc('complete_single_dropoff', {
        p_ride_id: rideReq.ride_id,
        p_rider_id: rideReq.rider_id,
      });
      return ok(res, { completed: true, mutual_agreement: true }, 'Mutual confirmation — ride completed!');
    }

    await supabaseAdmin.from('ride_requests').update({
      awaiting_confirm: true,
      driver_marked_arrival_at: new Date().toISOString(),
    }).eq('id', reqId);

    await supabaseAdmin.from('rides').update({ ride_status: 'awaiting_rider_confirm' }).eq('id', rideReq.ride_id);
    return ok(res, null, 'Arrival signaled. Waiting for rider to confirm.');
  } catch (err) {
    return serverError(res, err);
  }
}

// ─── Rider Confirms Arrival ───────────────────────────────────

/**
 * PATCH /requests/:id/rider-confirm
 * Rider confirms they've been dropped — triggers coin transfer
 */
async function riderConfirmArrival(req, res) {
  try {
    const reqId = req.params.id;

    const { data: rideReq } = await supabaseAdmin
      .from('ride_requests').select('id, ride_id, rider_id, status, awaiting_confirm').eq('id', reqId).single();
    if (!rideReq) return notFound(res, 'Request not found');
    if (rideReq.rider_id !== req.user.id) return forbidden(res, 'Not your request');

    // If driver already marked arrival → mutual confirm → complete
    if (rideReq.awaiting_confirm) {
      // Calls 015_stored_procedures.sql → complete_single_dropoff()
      const { data: result, error } = await supabaseAdmin.rpc('complete_single_dropoff', {
        p_request_id: reqId,
        p_ride_id: rideReq.ride_id,
        p_rider_id: rideReq.rider_id,
      });

      if (error) return serverError(res, error, 'Completion failed');

      // Check if ALL riders for this ride are now completed
      const { data: remaining } = await supabaseAdmin
        .from('ride_requests')
        .select('id')
        .eq('ride_id', rideReq.ride_id)
        .eq('status', 'accepted');

      if (!remaining || remaining.length === 0) {
        await supabaseAdmin.from('rides').update({
          ride_status: 'completed',
          completed_at: new Date().toISOString(),
        }).eq('id', rideReq.ride_id);
        await clearDriverLocation(rideReq.ride_id);
      }

      return ok(res, { completed: true }, 'Ride completed! Coins transferred to driver.');
    }

    // Driver hasn't marked yet — rider signals first
    await supabaseAdmin.from('ride_requests').update({
      rider_marked_arrival: true,
      rider_marked_arrival_at: new Date().toISOString(),
    }).eq('id', reqId);

    await supabaseAdmin.from('rides').update({ ride_status: 'awaiting_driver_confirm' }).eq('id', rideReq.ride_id);
    return ok(res, null, 'Arrival signaled. Waiting for driver to confirm.');
  } catch (err) {
    return serverError(res, err);
  }
}

// ─── Get My Requests (Rider) ──────────────────────────────────

/**
 * GET /requests/my
 */
async function getMyRequests(req, res) {
  try {
    const { status, limit = 20, offset = 0 } = req.query;
    let query = supabaseAdmin
      .from('ride_requests')
      .select(`
        id, status, pickup_address, drop_address, coins_locked, otp, otp_verified, created_at,
        rides(id, from_address, to_address, ride_status, depart_time, coin_per_seat,
          users!driver_id(full_name, photo_url, karma_score))
      `)
      .eq('rider_id', req.user.id)
      .order('created_at', { ascending: false })
      .range(parseInt(offset), parseInt(offset) + parseInt(limit) - 1);

    if (status) query = query.eq('status', status);
    const { data, error } = await query;
    if (error) return serverError(res, error);
    return ok(res, data);
  } catch (err) {
    return serverError(res, err);
  }
}

module.exports = { createRequest, acceptRequest, rejectRequest, verifyPickupOtp, driverMarkArrival, riderConfirmArrival, getMyRequests };
