// ============================================================
// Ride Controller — Corporate Pooling App
// POST ride, search rides, get ride, start/complete/cancel
// ============================================================

'use strict';

const { supabaseAdmin } = require('../config/supabase');
const { matchRides, fetchSpatialCandidateRides } = require('../services/matchingService');
const { updateDriverLocation, clearDriverLocation } = require('../services/gpsService');
const { routeTotalKm } = require('../utils/haversine');
const { ok, created, badRequest, notFound, forbidden, serverError } = require('../utils/response');

// ─── Post a Ride (Driver) ─────────────────────────────────────

/**
 * POST /rides
 * Body: {
 *   from_address, from_lat, from_lng,
 *   to_address, to_lat, to_lng,
 *   route_points: [{lat,lng},...],
 *   vehicle_id, total_seats, coin_per_seat,
 *   time_type, depart_time, depart_timestamp,
 *   recurring_days, valid_until
 * }
 */
async function postRide(req, res) {
  try {
    const {
      from_address, from_lat, from_lng,
      to_address, to_lat, to_lng,
      route_points,
      vehicle_id, total_seats, coin_per_seat,
      time_type, depart_time, depart_timestamp,
      recurring_days, valid_until,
    } = req.body;

    // Validations
    if (!from_address || !to_address) return badRequest(res, 'from_address and to_address are required');
    if (!from_lat || !from_lng || !to_lat || !to_lng) return badRequest(res, 'Coordinates are required');
    if (!route_points || !Array.isArray(route_points) || route_points.length < 2) {
      return badRequest(res, 'route_points must be an array with at least 2 points [{lat,lng},...]');
    }
    if (!total_seats || total_seats < 1) return badRequest(res, 'total_seats must be at least 1');
    if (coin_per_seat == null || coin_per_seat < 0) return badRequest(res, 'coin_per_seat is required');
    if (!time_type || !['now', 'scheduled', 'recurring'].includes(time_type)) {
      return badRequest(res, 'time_type must be: now, scheduled, or recurring');
    }

    const driverId = req.user.id;

    // Check driver is verified (non-corporate must have is_driver_verified)
    if (req.user.user_type === 'public' && !req.user.is_driver_verified) {
      return forbidden(res, 'Driver document verification pending. You cannot post rides until approved.');
    }

    // Calculate route distance
    const distKm = routeTotalKm(route_points);

    // Geohash for origin (simplified — store lat,lng for geo queries)
    const { data: ride, error } = await supabaseAdmin
      .from('rides')
      .insert({
        driver_id: driverId,
        vehicle_id: vehicle_id || null,
        from_address,
        from_lat: parseFloat(from_lat),
        from_lng: parseFloat(from_lng),
        to_address,
        to_lat: parseFloat(to_lat),
        to_lng: parseFloat(to_lng),
        route_points,
        total_seats: parseInt(total_seats),
        available_seats: parseInt(total_seats),
        coin_per_seat: parseInt(coin_per_seat),
        time_type,
        depart_time: depart_time || null,
        depart_timestamp: depart_timestamp || null,
        recurring_days: recurring_days || null,
        valid_until: valid_until || null,
        ride_status: 'posted',
        distance_km: distKm,
        is_open_to_public: true,
      })
      .select()
      .single();

    if (error) return serverError(res, error, 'Failed to post ride');
    return created(res, ride, 'Ride posted successfully');
  } catch (err) {
    return serverError(res, err);
  }
}

// ─── Search Rides (Rider) ─────────────────────────────────────

/**
 * GET /rides/search
 * Query: pickup_lat, pickup_lng, drop_lat, drop_lng,
 *        time_type?, depart_timestamp?, recurring_days?, flexibility?
 */
async function searchRides(req, res) {
  try {
    const {
      pickup_lat, pickup_lng, drop_lat, drop_lng,
      time_type, depart_timestamp, depart_date, recurring_days, flexibility,
      seats_requested, max_radius_m,
    } = req.query;

    if (!pickup_lat || !pickup_lng || !drop_lat || !drop_lng) {
      return badRequest(res, 'pickup_lat, pickup_lng, drop_lat, drop_lng are required');
    }

    const riderId = req.user ? req.user.id : null;
    const pLat = parseFloat(pickup_lat);
    const pLng = parseFloat(pickup_lng);
    const dLat = parseFloat(drop_lat);
    const dLng = parseFloat(drop_lng);
    const seats = parseInt(seats_requested, 10) || 1;
    const radius = parseInt(max_radius_m, 10) || 1500;

    // Determine target date if scheduled or timestamp provided
    let targetDate = depart_date || null;
    if (!targetDate && depart_timestamp) {
      try {
        const d = new Date(depart_timestamp);
        if (!isNaN(d.getTime())) {
          targetDate = d.toISOString().split('T')[0];
        }
      } catch (_) {}
    }

    // ── Tier 1: PostGIS Spatial Pre-Filter (< 5ms via GiST Index) ───────────
    // Replaces the old full-table-scan query on public.rides
    const candidateRides = await fetchSpatialCandidateRides(
      riderId,
      pLat,
      pLng,
      dLat,
      dLng,
      {
        seatsRequested: seats,
        maxRadiusMeters: radius,
        timeType: time_type || null,
        targetDate: targetDate,
      }
    );

    const rideWant = {
      time_type: time_type || 'now',
      depart_timestamp: depart_timestamp || null,
      recurring_days: recurring_days ? recurring_days.split(',') : [],
      flexibility: parseInt(flexibility || '30', 10),
    };

    // ── Tier 2: In-Memory Cross-Track Polyline Matching ─────────────────────
    const matched = matchRides(
      candidateRides || [],
      pLat,
      pLng,
      dLat,
      dLng,
      rideWant
    );

    return ok(res, {
      count: matched.length,
      spatial_candidates_count: (candidateRides || []).length,
      rides: matched,
    });
  } catch (err) {
    return serverError(res, err);
  }
}

// ─── Get Single Ride ──────────────────────────────────────────

/**
 * GET /rides/:id
 */
async function getRide(req, res) {
  try {
    const { data: ride, error } = await supabaseAdmin
      .from('rides')
      .select(`
        *,
        users!driver_id(id, full_name, photo_url, karma_score, phone, total_rides_given),
        vehicles(type, registration_number, model, color),
        ride_requests(id, rider_id, status, pickup_address, drop_address, coins_locked,
          users!rider_id(full_name, photo_url))
      `)
      .eq('id', req.params.id)
      .single();

    if (error || !ride) return notFound(res, 'Ride not found');
    return ok(res, ride);
  } catch (err) {
    return serverError(res, err);
  }
}

// ─── Start Ride (Driver) ──────────────────────────────────────

/**
 * PATCH /rides/:id/start
 */
async function startRide(req, res) {
  try {
    const rideId = req.params.id;
    const driverId = req.user.id;

    const { data: ride } = await supabaseAdmin
      .from('rides').select('id, driver_id, ride_status, route_points').eq('id', rideId).single();

    if (!ride) return notFound(res, 'Ride not found');
    if (ride.driver_id !== driverId) return forbidden(res, 'Not your ride');
    if (ride.ride_status !== 'posted') {
      return badRequest(res, `Cannot start ride in status: ${ride.ride_status}`);
    }

    await supabaseAdmin.from('rides').update({
      ride_status: 'started',
      started_at: new Date().toISOString(),
    }).eq('id', rideId);

    return ok(res, { ride_id: rideId, status: 'started' }, 'Ride started. GPS tracking active.');
  } catch (err) {
    return serverError(res, err);
  }
}

// ─── Update GPS Location (Driver) ────────────────────────────

/**
 * PATCH /rides/:id/location
 * Body: { lat, lng }
 */
async function updateLocation(req, res) {
  try {
    const { lat, lng } = req.body;
    if (!lat || !lng) return badRequest(res, 'lat and lng are required');

    const rideId = req.params.id;

    // Get route_points for index calculation
    const { data: ride } = await supabaseAdmin
      .from('rides').select('route_points, driver_id').eq('id', rideId).single();

    if (!ride) return notFound(res, 'Ride not found');
    if (ride.driver_id !== req.user.id) return forbidden(res, 'Not your ride');

    const result = await updateDriverLocation(
      rideId, req.user.id, parseFloat(lat), parseFloat(lng), ride.route_points || []
    );

    // Also update rides table with current lat/lng for Phase 2 matching
    await supabaseAdmin.from('rides').update({
      current_lat: parseFloat(lat),
      current_lng: parseFloat(lng),
      current_route_index: result.routeIndex,
    }).eq('id', rideId);

    return ok(res, { route_index: result.routeIndex });
  } catch (err) {
    return serverError(res, err);
  }
}

// ─── Cancel Ride ──────────────────────────────────────────────

/**
 * DELETE /rides/:id
 */
async function cancelRide(req, res) {
  try {
    const rideId = req.params.id;
    const driverId = req.user.id;

    const { data: ride } = await supabaseAdmin
      .from('rides').select('id, driver_id, ride_status').eq('id', rideId).single();

    if (!ride) return notFound(res, 'Ride not found');
    if (ride.driver_id !== driverId) return forbidden(res, 'Not your ride');
    if (['completed', 'cancelled'].includes(ride.ride_status)) {
      return badRequest(res, 'Ride already ended');
    }

    await supabaseAdmin.from('rides').update({ ride_status: 'cancelled' }).eq('id', rideId);

    // Refund locked coins to all accepted riders
    const { data: requests } = await supabaseAdmin
      .from('ride_requests')
      .select('id, rider_id, coins_locked')
      .eq('ride_id', rideId)
      .eq('status', 'accepted');

    for (const req of (requests || [])) {
      if (req.coins_locked > 0) {
        await supabaseAdmin.rpc('refund_coins', {
          p_rider_id: req.rider_id,
          p_ride_id: rideId,
          p_amount: req.coins_locked,
        });
      }
      await supabaseAdmin.from('ride_requests').update({ status: 'cancelled' }).eq('id', req.id);
    }

    await clearDriverLocation(rideId);
    return ok(res, null, 'Ride cancelled. Coins refunded to riders.');
  } catch (err) {
    return serverError(res, err);
  }
}

// ─── Get My Posted Rides ──────────────────────────────────────

/**
 * GET /rides/my
 */
async function getMyRides(req, res) {
  try {
    const { status, limit = 20, offset = 0 } = req.query;
    let query = supabaseAdmin
      .from('rides')
      .select('id, from_address, to_address, ride_status, depart_time, depart_timestamp, coin_per_seat, available_seats, total_seats, distance_km, started_at, completed_at, created_at')
      .eq('driver_id', req.user.id)
      .order('created_at', { ascending: false })
      .range(parseInt(offset), parseInt(offset) + parseInt(limit) - 1);

    if (status) query = query.eq('ride_status', status);

    const { data, error } = await query;
    if (error) return serverError(res, error);
    return ok(res, data);
  } catch (err) {
    return serverError(res, err);
  }
}

module.exports = { postRide, searchRides, getRide, startRide, updateLocation, cancelRide, getMyRides };
