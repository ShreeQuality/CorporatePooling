// ============================================================
// Matching Service — Corporate Pooling App
// Ported from KarmaRide matchingAlgorithm.js + rideMatchHelpers.js
// Phase-based: generous when ride POSTED, tight when STARTED
// ============================================================

'use strict';

const { supabaseAdmin } = require('../config/supabase');
const { isNearRouteSegment, distanceMeters } = require('../utils/haversine');

// ─── Configurable Radius Values ─────────────────────────────
const CONFIG = {
  pickup_radius_posted: 500,   // meters — generous before ride starts
  pickup_radius_started: 150,  // meters — tight, driver is moving
  drop_radius_posted: 500,     // meters
  drop_radius_started: 300,    // meters — passing nearby is enough
  max_matches: 20,             // cap on results shown to rider
};

// ─── Day/Time Helpers (from rideMatchHelpers.js) ────────────

const DAY_KEYS = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];

function dayKeyOfDate(d) {
  const date = d instanceof Date ? d : new Date(d);
  return DAY_KEYS[date.getDay()];
}

function isSameCalendarDay(d1, d2) {
  const a = d1 instanceof Date ? d1 : new Date(d1);
  const b = d2 instanceof Date ? d2 : new Date(d2);
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  );
}

/**
 * Check day compatibility between rider's ride_want and driver's ride.
 * rideWant: { time_type, recurring_days, depart_timestamp }
 * driverRide: { time_type, recurring_days, depart_timestamp, depart_time }
 */
function dayCompatible(rideWant, driverRide) {
  const wantDays = rideWant.recurring_days || [];

  if (rideWant.time_type === 'recurring') {
    if (driverRide.time_type === 'recurring') {
      const driverDays = driverRide.recurring_days || [];
      return driverDays.some((d) => wantDays.includes(d));
    }
    if (driverRide.time_type === 'scheduled') {
      if (!driverRide.depart_timestamp) return false;
      return wantDays.includes(dayKeyOfDate(driverRide.depart_timestamp));
    }
    return wantDays.includes(dayKeyOfDate(new Date()));
  }

  if (rideWant.time_type === 'scheduled') {
    if (!rideWant.depart_timestamp) return false;
    const wantDate = new Date(rideWant.depart_timestamp);

    if (driverRide.time_type === 'scheduled') {
      if (!driverRide.depart_timestamp) return false;
      return isSameCalendarDay(wantDate, driverRide.depart_timestamp);
    }
    if (driverRide.time_type === 'recurring') {
      return (driverRide.recurring_days || []).includes(dayKeyOfDate(wantDate));
    }
    return isSameCalendarDay(wantDate, new Date());
  }

  // time_type === 'now' → match anything available today
  return true;
}

/**
 * Check departure time compatibility.
 * Driver must depart within [riderTime, riderTime + 2×flexibility].
 */
function timesCompatible(rideWant, driverRide) {
  if (!rideWant.depart_timestamp) return true;
  const wantDate = new Date(rideWant.depart_timestamp);
  const wantMins = wantDate.getHours() * 60 + wantDate.getMinutes();

  // Parse driver's "8:00 AM" time string
  const parseTimeString = (s) => {
    if (!s) return null;
    const m = s.match(/(\d{1,2}):(\d{2})\s*(AM|PM)/i);
    if (!m) return null;
    let hr = parseInt(m[1]);
    const min = parseInt(m[2]);
    const ampm = m[3].toUpperCase();
    if (ampm === 'PM' && hr !== 12) hr += 12;
    if (ampm === 'AM' && hr === 12) hr = 0;
    return hr * 60 + min;
  };

  const driverMins = parseTimeString(driverRide.depart_time);
  if (driverMins === null) return true;

  const flex = rideWant.flexibility || 0;
  return driverMins >= wantMins && driverMins <= wantMins + flex * 2;
}

// ─── Main Matching Function ──────────────────────────────────

/**
 * Match a rider's search against available driver rides.
 *
 * @param {Array} rides - array of ride objects from DB
 * @param {number} riderPickupLat
 * @param {number} riderPickupLng
 * @param {number} riderDropLat
 * @param {number} riderDropLng
 * @param {object} rideWant - rider's time/day preferences { time_type, depart_timestamp, recurring_days, flexibility }
 * @param {object} options - { excludeLiveStatuses: bool }
 * @returns {Array} matched rides sorted by score
 */
function matchRides(
  rides,
  riderPickupLat,
  riderPickupLng,
  riderDropLat,
  riderDropLng,
  rideWant = {},
  options = {}
) {
  if (!rides || rides.length === 0) return [];
  if (riderPickupLat == null || riderDropLat == null) return [];

  const { excludeLiveStatuses = true } = options;

  const matches = [];

  for (const ride of rides) {
    const rideStatus = ride.ride_status || 'posted';

    // Skip completed / cancelled — dead rides
    if (rideStatus === 'completed' || rideStatus === 'cancelled') continue;

    const isLive = rideStatus === 'in_progress' || rideStatus === 'waiting_otp';
    if (isLive && (ride.time_type !== 'recurring' || excludeLiveStatuses)) continue;

    // Skip rides with no seats
    if ((ride.available_seats || 0) <= 0) continue;

    const routePoints = ride.route_points || [];
    if (routePoints.length === 0) {
      console.warn(`[matchRides] Ride ${ride.id} has no route_points — skipping`);
      continue;
    }

    // Day/time filter (only apply if rideWant has time info)
    if (rideWant.time_type && rideWant.time_type !== 'now') {
      if (!dayCompatible(rideWant, ride)) continue;
      if (!timesCompatible(rideWant, ride)) continue;
    }

    // ── PHASE 1: Posted (generous 500m radius) ──────────────
    if (rideStatus === 'posted' || (isLive && !excludeLiveStatuses)) {
      const pickupCheck = isNearRouteSegment(
        routePoints, 0, routePoints.length - 1,
        riderPickupLat, riderPickupLng, CONFIG.pickup_radius_posted
      );
      if (!pickupCheck.match) continue;

      const dropCheck = isNearRouteSegment(
        routePoints, pickupCheck.index, routePoints.length - 1,
        riderDropLat, riderDropLng, CONFIG.drop_radius_posted
      );
      if (!dropCheck.match) continue;

      const matchScore = Math.max(0, Math.min(100,
        100 - Math.round((pickupCheck.distance + dropCheck.distance) / 20)
      ));

      matches.push({
        ...ride,
        _pickup_distance_m: Math.round(pickupCheck.distance),
        _drop_distance_m: Math.round(dropCheck.distance),
        _pickup_route_index: pickupCheck.index,
        _drop_route_index: dropCheck.index,
        _match_score: matchScore,
        _phase: 'posted',
      });
    }

    // ── PHASE 2: Started (tight 150m/300m, remaining route only) ──
    if (rideStatus === 'started') {
      const currentLat = ride.current_lat || ride.from_lat;
      const currentLng = ride.current_lng || ride.from_lng;
      const currentRouteIndex = ride.current_route_index != null ? ride.current_route_index : 0;

      const pickupCheck = isNearRouteSegment(
        routePoints, currentRouteIndex, routePoints.length - 1,
        riderPickupLat, riderPickupLng, CONFIG.pickup_radius_started
      );
      if (!pickupCheck.match) continue;

      // Must be AHEAD of driver
      if (pickupCheck.index < currentRouteIndex) continue;

      const dropCheck = isNearRouteSegment(
        routePoints, pickupCheck.index, routePoints.length - 1,
        riderDropLat, riderDropLng, CONFIG.drop_radius_started
      );
      if (!dropCheck.match) continue;

      const matchScore = Math.max(0, Math.min(100,
        100 - Math.round((pickupCheck.distance + dropCheck.distance) / 10)
      ));

      matches.push({
        ...ride,
        _pickup_distance_m: Math.round(pickupCheck.distance),
        _drop_distance_m: Math.round(dropCheck.distance),
        _pickup_route_index: pickupCheck.index,
        _drop_route_index: dropCheck.index,
        _match_score: matchScore,
        _phase: 'started',
        _driver_distance_m: Math.round(
          distanceMeters(currentLat, currentLng, riderPickupLat, riderPickupLng)
        ),
      });
    }
  }

  // Sort best score first, cap at max_matches
  matches.sort((a, b) => b._match_score - a._match_score);
  return matches.slice(0, CONFIG.max_matches);
}

// ============================================================
// TIER 1: PostGIS Spatial Pre-Filter (Step 4)
// Calls PostgreSQL RPC: find_candidate_rides_spatial (020_spatial_matching_rpc.sql)
// ============================================================

/**
 * Fetches candidate rides within spatial bounding circle using PostGIS GiST index.
 * Prunes 95%–99% of non-relevant rides at the database layer in < 5ms.
 * 
 * @param {string|null} riderId - UUID of the searching rider (to exclude self-rides)
 * @param {number} pickupLat - Rider pickup latitude
 * @param {number} pickupLng - Rider pickup longitude
 * @param {number} dropLat - Rider drop latitude
 * @param {number} dropLng - Rider drop longitude
 * @param {object} options - { seatsRequested, maxRadiusMeters, timeType, targetDate }
 * @returns {Promise<Array>} Normalized candidate rides for Tier 2 polyline & scoring
 */
async function fetchSpatialCandidateRides(riderId, pickupLat, pickupLng, dropLat, dropLng, options = {}) {
  const {
    seatsRequested = 1,
    maxRadiusMeters = 1500,
    timeType = null,
    targetDate = null,
  } = options;

  try {
    const { data, error } = await supabaseAdmin.rpc('find_candidate_rides_spatial', {
      p_rider_id: riderId || null,
      p_pickup_lat: parseFloat(pickupLat),
      p_pickup_lng: parseFloat(pickupLng),
      p_drop_lat: parseFloat(dropLat),
      p_drop_lng: parseFloat(dropLng),
      p_seats_requested: parseInt(seatsRequested, 10) || 1,
      p_max_radius_m: parseInt(maxRadiusMeters, 10) || 1500,
      p_time_type: timeType || null,
      p_target_date: targetDate || null,
    });

    if (error) {
      console.warn('[MatchingService] Tier 1 PostGIS RPC error, falling back to basic query:', error.message);
      return await _fallbackCandidateQuery(riderId);
    }

    if (!data || !Array.isArray(data)) {
      return [];
    }

    // Normalize returned rows for Tier 2 polyline matcher + Flutter consumer compatibility
    return data.map((row) => ({
      id: row.ride_id,
      ride_id: row.ride_id,
      driver_id: row.driver_id,
      from_address: row.from_address,
      to_address: row.to_address,
      from_lat: parseFloat(pickupLat),
      from_lng: parseFloat(pickupLng),
      to_lat: parseFloat(dropLat),
      to_lng: parseFloat(dropLng),
      route_points: Array.isArray(row.route_points) ? row.route_points : [],
      total_seats: row.seats_offered,
      seats_offered: row.seats_offered,
      available_seats: row.seats_available,
      seats_available: row.seats_available,
      coin_per_seat: Number(row.fare_coins || 0),
      fare_coins: Number(row.fare_coins || 0),
      time_type: row.time_type,
      depart_date: row.depart_date,
      depart_time: row.depart_time,
      approx_reach_time: row.approx_reach_time,
      recurring_days: row.recurring_days || [],
      skip_dates: row.skip_dates || [],
      distance_km: Number(row.distance_km || 0),
      estimated_duration_mins: row.estimated_duration_mins || 0,
      ride_status: row.ride_status,
      women_only_flag: Boolean(row.women_only_flag),
      is_open_to_public: row.is_open_to_public !== false,
      current_lat: row.current_lat != null ? parseFloat(row.current_lat) : null,
      current_lng: row.current_lng != null ? parseFloat(row.current_lng) : null,
      current_route_index: row.current_route_index || 0,
      _spatial_pickup_dist_m: Math.round(row.pickup_dist_meters || 0),
      _spatial_drop_dist_m: Math.round(row.drop_dist_meters || 0),
      driver: {
        id: row.driver_id,
        full_name: row.driver_name,
        phone_number: row.driver_phone,
        gender: row.driver_gender,
        role: row.driver_role,
        trust_score: row.driver_trust_score,
        company_id: row.driver_company_id,
        building_id: row.driver_building_id,
        company_name: row.driver_company_name,
        photo_url: row.driver_photo_url,
      },
      vehicle: {
        id: row.vehicle_id,
        type: row.vehicle_type,
        model: row.vehicle_model,
        registration_number: row.vehicle_number,
        color: row.vehicle_color,
        has_spare_helmet: row.has_spare_helmet,
      },
      users: {
        id: row.driver_id,
        full_name: row.driver_name,
        photo_url: row.driver_photo_url,
        trust_score: row.driver_trust_score,
        gender: row.driver_gender,
      },
      vehicles: {
        type: row.vehicle_type,
        model: row.vehicle_model,
        registration_number: row.vehicle_number,
        color: row.vehicle_color,
      },
    }));
  } catch (err) {
    console.error('[MatchingService] Error in fetchSpatialCandidateRides:', err.message);
    return await _fallbackCandidateQuery(riderId);
  }
}

/**
 * Fallback query in case RPC has not yet been compiled on Supabase instance.
 */
async function _fallbackCandidateQuery(riderId) {
  let query = supabaseAdmin
    .from('rides')
    .select(`
      *,
      users!driver_id(id, full_name, photo_url, trust_score, gender, role, company_id, building_id),
      vehicles(id, type, model, registration_number, color, has_spare_helmet)
    `)
    .in('ride_status', ['posted', 'started'])
    .gt('seats_available', 0)
    .limit(50);

  if (riderId) {
    query = query.neq('driver_id', riderId);
  }

  const { data } = await query;
  return data || [];
}

module.exports = {
  matchRides,
  dayCompatible,
  timesCompatible,
  fetchSpatialCandidateRides,
  CONFIG,
};
