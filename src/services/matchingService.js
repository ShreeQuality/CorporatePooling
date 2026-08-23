// ============================================================
// Matching Service — Corporate Pooling Backend
// 2-Tier Hybrid Funnel Architecture: PostGIS Spatial Pre-Filter + In-Memory Polyline Engine
// Source of Truth: SRS §5.1.1 (Barrier Landmarks), §6.1, §6.3, §6.5 (Trust Scoring), §6.6 (Exclusion Gates)
// ============================================================

'use strict';

const { supabaseAdmin } = require('../config/supabase');
const { isNearRouteSegment, distanceMeters, pointToSegmentDistanceMeters } = require('../utils/haversine');
const walletService = require('./walletService');

// ─── Phase-Based Configurable Radius Values (SRS §6.3) ─────────
const MATCH_CONFIG = {
  pickup_radius_posted: 500,     // meters — generous standard matching
  pickup_radius_extended: 1500,  // meters — extended campus matching if same building_id
  pickup_radius_started: 150,    // meters — tight, driver is moving on-route
  drop_radius_posted: 500,       // meters
  drop_radius_started: 300,      // meters
  max_matches: 20,               // max candidate results returned
  min_results_extended_threshold: 5, // if < 5 direct matches, trigger extended campus search
  average_walk_speed_m_per_min: 80, // ~4.8 km/h walking speed
  barrier_landmark_search_radius_m: 500, // meters for safe transit landmark suggestions
};

// ============================================================
// 1. TIER 1: POSTGIS SPATIAL CANDIDATE FETCH
// ============================================================

/**
 * Executes PostGIS ST_DWithin query via RPC to prune 99% of non-relevant rides in < 5ms.
 */
async function fetchSpatialCandidateRides(riderId, pickupLat, pickupLng, dropLat, dropLng, options = {}) {
  const {
    seatsRequested = 1,
    maxRadiusMeters = MATCH_CONFIG.pickup_radius_extended,
    timeType = null,
    targetDate = null,
  } = options;

  const { data, error } = await supabaseAdmin.rpc('find_candidate_rides_spatial', {
    p_rider_id: riderId,
    p_pickup_lat: parseFloat(pickupLat),
    p_pickup_lng: parseFloat(pickupLng),
    p_drop_lat: parseFloat(dropLat),
    p_drop_lng: parseFloat(dropLng),
    p_seats_requested: parseInt(seatsRequested, 10),
    p_max_radius_m: parseInt(maxRadiusMeters, 10),
    p_time_type: timeType,
    p_target_date: targetDate,
  });

  if (error) {
    console.error('[MatchingService] Tier 1 PostGIS query error:', error.message);
    throw new Error(`Spatial candidate search failed: ${error.message}`);
  }

  return data || [];
}

/**
 * Fetches nearest physical barrier transit landmark (e.g. railway foot overbridge, highway bus bay)
 * Source of Truth: SRS §5.1.1 (Physical Barrier Handling) & Migration 018.
 */
async function fetchNearbyBarrierLandmark(pickupLat, pickupLng, maxRadiusMeters = 500) {
  try {
    const { data, error } = await supabaseAdmin.rpc('get_suggested_barrier_pickup', {
      p_rider_lat: parseFloat(pickupLat),
      p_rider_lng: parseFloat(pickupLng),
      p_max_radius_m: parseInt(maxRadiusMeters, 10),
    });

    if (error || !data || data.length === 0) return null;
    const l = data[0];
    return {
      landmark_id: l.landmark_id,
      name: l.landmark_name,
      barrier_type: l.barrier_type,
      suggested_pickup_note: l.suggested_pickup_note,
      distance_meters: Math.round(l.distance_meters || 0),
      pickup_lat: l.pickup_lat,
      pickup_lng: l.pickup_lng,
    };
  } catch (err) {
    console.warn('[MatchingService] Barrier landmark fetch failed (non-fatal):', err.message);
    return null;
  }
}

// ============================================================
// 2. HARD EXCLUSION GATES (SRS §6.6 — 5 Safety & Feasibility Gates)
// ============================================================

/**
 * Evaluates binary safety and operational constraints.
 * If any gate fails, returns { pass: false, reason: string }.
 */
function evaluateExclusionGates(ride, riderProfile = {}, seatsRequested = 1) {
  // Gate 1: Driver Self-Match Guard
  if (ride.driver_id === riderProfile.id) {
    return { pass: false, reason: 'SELF_MATCH_GUARD' };
  }

  // Gate 2: Women-Only Safety Guard (SRS §6.6 Gate 1)
  const isWomenOnly = Boolean(ride.women_only || ride.women_only_flag);
  if (isWomenOnly && riderProfile.gender !== 'female') {
    return { pass: false, reason: 'WOMEN_ONLY_GUARD' };
  }

  // Gate 3: 2-Wheeler Helmet & Seat Guard (SRS §6.6 Gate 3)
  const isBike = ride.vehicle_type === 'bike' || ride.vehicle_type === 'scooter' || ride.vehicle_type === 'motorcycle';
  if (isBike && seatsRequested > 1) {
    return { pass: false, reason: 'TWO_WHEELER_SEAT_LIMIT' };
  }

  // Gate 4: Available Seats Capacity Guard (SRS §6.6 Gate 4)
  if ((ride.seats_available || 0) < seatsRequested) {
    return { pass: false, reason: 'INSUFFICIENT_SEATS' };
  }

  // Gate 5: Driver Account Suspension Guard (SRS §6.6 Gate 5)
  if (ride.is_banned || ride.driver_is_banned) {
    return { pass: false, reason: 'DRIVER_BANNED' };
  }

  return { pass: true };
}

// ============================================================
// 3. SRS §6.5 TRUST & PRIORITY SCORING ENGINE (0 to 100 Points)
// ============================================================

/**
 * Calculates dynamic mathematical match score from 0 to 100:
 *   Total Score = S_proximity (40) + S_trust (30) + S_time (20) + S_karma (10)
 */
function calculateMatchScore(ride, riderProfile = {}, pickupDistM = 0, dropDistM = 0, timeDiffMins = 0) {
  // 1. Proximity Score (Max 40 Pts) — closer pickup/drop = higher score
  const totalDetourDist = Math.max(0, pickupDistM + dropDistM);
  const proximityScore = Math.max(0, Math.min(40, 40 - Math.round(totalDetourDist / 25)));

  // 2. Corporate Trust Score (Max 30 Pts)
  let trustScore = 10; // Default: Verified Public User (+10)
  if (ride.driver_company_id && riderProfile.company_id && ride.driver_company_id === riderProfile.company_id) {
    trustScore = 30; // Same Company Colleague (+30)
  } else if (ride.driver_building_id && riderProfile.building_id && ride.driver_building_id === riderProfile.building_id) {
    trustScore = 25; // Same Tech Park / Building (+25)
  } else if (ride.driver_role === 'corporate_employee') {
    trustScore = 15; // Other Corporate Employee (+15)
  }

  // 3. Time Schedule Score (Max 20 Pts) — departure time alignment
  const timeScore = Math.max(0, Math.min(20, 20 - Math.round(Math.abs(timeDiffMins) / 3)));

  // 4. Driver Karma / Safety Score (Max 10 Pts)
  const driverTrust = ride.driver_trust_score != null ? ride.driver_trust_score : 50;
  const karmaScore = Math.max(0, Math.min(10, Math.round(driverTrust / 10)));

  // Total Combined Score (0 to 100)
  const totalScore = Math.max(0, Math.min(100, proximityScore + trustScore + timeScore + karmaScore));

  return {
    total_score: totalScore,
    breakdown: {
      proximity: proximityScore,
      corporate_trust: trustScore,
      time_alignment: timeScore,
      driver_karma: karmaScore,
    },
  };
}

// ─── Time Difference Helper ──────────────────────────────────
function computeTimeDifferenceMinutes(rideDepartTime, riderTargetTime) {
  if (!rideDepartTime || !riderTargetTime) return 0;

  const parseMins = (t) => {
    if (typeof t === 'string') {
      const parts = t.split(':');
      if (parts.length >= 2) return parseInt(parts[0], 10) * 60 + parseInt(parts[1], 10);
    }
    if (t instanceof Date) return t.getHours() * 60 + t.getMinutes();
    return 0;
  };

  const driverMins = parseMins(rideDepartTime);
  const riderMins = parseMins(riderTargetTime);
  return Math.abs(driverMins - riderMins);
}

// ============================================================
// 4. TIER 2: COMPLETE IN-MEMORY MATCHING & RANKING PIPELINE
// ============================================================

/**
 * Main matching orchestrator: Runs Tier 1 PostGIS fetch + Tier 2 Polyline & Scoring + Barrier Landmarks.
 * 
 * @param {object} riderProfile - { id, gender, role, company_id, building_id }
 * @param {number} pickupLat - Rider pickup latitude
 * @param {number} pickupLng - Rider pickup longitude
 * @param {number} dropLat - Rider dropoff latitude
 * @param {number} dropLng - Rider dropoff longitude
 * @param {object} searchOptions - { seats_requested, time_type, target_date, target_time, vehicle_type }
 * @returns {Array<object>} Ranked, formatted candidate rides for Flutter UI
 */
async function findMatchesForRider(
  riderProfile,
  pickupLat,
  pickupLng,
  dropLat,
  dropLng,
  searchOptions = {}
) {
  const seatsRequested = parseInt(searchOptions.seats_requested, 10) || 1;
  const targetDate = searchOptions.target_date || new Date().toISOString().split('T')[0];
  const targetTime = searchOptions.target_time || null;
  const requestedVehicle = (searchOptions.vehicle_type || 'all').toLowerCase();

  // 1. Concurrently Execute Tier 1 PostGIS fetch + Nearby Barrier Landmark lookup
  const [candidateRides, suggestedBarrierLandmark] = await Promise.all([
    fetchSpatialCandidateRides(
      riderProfile.id,
      pickupLat,
      pickupLng,
      dropLat,
      dropLng,
      {
        seatsRequested,
        maxRadiusMeters: MATCH_CONFIG.pickup_radius_extended,
        timeType: searchOptions.time_type,
        targetDate,
      }
    ),
    fetchNearbyBarrierLandmark(pickupLat, pickupLng, MATCH_CONFIG.barrier_landmark_search_radius_m),
  ]);

  if (!candidateRides || candidateRides.length === 0) {
    return [];
  }

  const directMatches = [];
  const extendedCampusMatches = [];

  for (const ride of candidateRides) {
    // 2. Evaluate Hard Exclusion Gates (SRS §6.6)
    const gateCheck = evaluateExclusionGates(ride, riderProfile, seatsRequested);
    if (!gateCheck.pass) continue;

    // Vehicle Type Filter (if rider explicitly specified car/bike)
    if (requestedVehicle !== 'all') {
      const isBike = ride.vehicle_type === 'bike' || ride.vehicle_type === 'scooter';
      if (requestedVehicle === 'car' && isBike) continue;
      if (requestedVehicle === 'bike' && !isBike) continue;
    }

    // Parse route waypoints
    let waypoints = [];
    if (Array.isArray(ride.route_waypoints)) {
      waypoints = ride.route_waypoints;
    } else if (Array.isArray(ride.route_points)) {
      waypoints = ride.route_points;
    } else if (typeof ride.route_waypoints === 'string') {
      try {
        waypoints = JSON.parse(ride.route_waypoints);
      } catch (e) {
        waypoints = [];
      }
    } else if (typeof ride.route_points === 'string') {
      try {
        waypoints = JSON.parse(ride.route_points);
      } catch (e) {
        waypoints = [];
      }
    }

    // If no waypoints, synthesize from start & end points
    if (waypoints.length === 0 && ride.pickup_dist_meters != null && ride.drop_dist_meters != null) {
      waypoints = [
        { lat: pickupLat, lng: pickupLng },
        { lat: dropLat, lng: dropLng },
      ];
    }

    const isLiveTrip = ride.ride_status === 'started';
    const activePickupRadius = isLiveTrip ? MATCH_CONFIG.pickup_radius_started : MATCH_CONFIG.pickup_radius_posted;
    const activeDropRadius = isLiveTrip ? MATCH_CONFIG.drop_radius_started : MATCH_CONFIG.drop_radius_posted;

    // 3. Polyline Cross-Track Match: Check Pickup Point with true perpendicular line-segment projection
    const pickupCheck = isNearRouteSegment(
      waypoints,
      0,
      waypoints.length - 1,
      pickupLat,
      pickupLng,
      activePickupRadius
    );

    // 4. Directionality Guard (SRS §6.4 & §6.6 Gate 2): Drop MUST be after pickup
    const dropStartIndex = pickupCheck.match ? pickupCheck.index : 0;
    const dropCheck = isNearRouteSegment(
      waypoints,
      dropStartIndex,
      waypoints.length - 1,
      dropLat,
      dropLng,
      activeDropRadius
    );

    const timeDiffMins = computeTimeDifferenceMinutes(ride.depart_time, targetTime);
    const pickupDistM = Math.round(pickupCheck.distance === Infinity ? (ride.pickup_dist_meters || 0) : pickupCheck.distance);
    const dropDistM = Math.round(dropCheck.distance === Infinity ? (ride.drop_dist_meters || 0) : dropCheck.distance);

    // 5. Calculate Fare Breakdown via WalletService (SRS §4.9)
    const fareEstimate = walletService.calculateFare(
      Number(ride.distance_km) || 10.0,
      ride.vehicle_type,
      pickupDistM,
      seatsRequested
    );

    // 6. Calculate Trust & Match Score (SRS §6.5)
    const scoreResult = calculateMatchScore(ride, riderProfile, pickupDistM, dropDistM, timeDiffMins);

    const formattedRide = {
      ride_id: ride.ride_id,
      driver_id: ride.driver_id,
      driver_name: ride.driver_name,
      driver_phone: ride.driver_phone,
      driver_gender: ride.driver_gender,
      driver_role: ride.driver_role,
      driver_trust_score: ride.driver_trust_score,
      driver_company_id: ride.driver_company_id,
      driver_company_name: ride.driver_company_name || 'Verified Corporate',
      driver_building_id: ride.driver_building_id,
      driver_photo_url: ride.driver_photo_url,
      vehicle_type: ride.vehicle_type,
      vehicle_model: ride.vehicle_model,
      vehicle_plate: ride.vehicle_plate || ride.vehicle_number,
      seats_offered: ride.seats_offered,
      seats_available: ride.seats_available,
      time_type: ride.time_type,
      depart_date: ride.depart_date,
      depart_time: ride.depart_time,
      distance_km: ride.distance_km,
      ride_status: ride.ride_status,
      women_only: Boolean(ride.women_only || ride.women_only_flag),
      // Spatial & Fare Data
      pickup_distance_meters: pickupDistM,
      drop_distance_meters: dropDistM,
      fare_coins: fareEstimate.total_rider_fare,
      fare_breakdown: fareEstimate,
      // Ranking & Scoring Data
      match_score: scoreResult.total_score,
      score_breakdown: scoreResult.breakdown,
      // Physical Barrier Landmark (SRS §5.1.1)
      suggested_barrier_landmark: suggestedBarrierLandmark,
      // UI Tags
      _is_extended_match: false,
      _badge_color: scoreResult.breakdown.corporate_trust === 30 ? 'blue' : (scoreResult.breakdown.corporate_trust === 25 ? 'purple' : 'neutral'),
      _badge_label: scoreResult.breakdown.corporate_trust === 30 ? '🏢 Same Company' : (scoreResult.breakdown.corporate_trust === 25 ? '📍 Same Tech Park' : null),
    };

    // Case A: Direct Match within 500m
    if (pickupCheck.match && dropCheck.match) {
      directMatches.push(formattedRide);
    } 
    // Case B: Campus Match (500m to 1500m) with same building_id (SRS §6.3.1)
    else if (
      !isLiveTrip &&
      pickupDistM <= MATCH_CONFIG.pickup_radius_extended &&
      ride.driver_building_id &&
      riderProfile.building_id &&
      ride.driver_building_id === riderProfile.building_id
    ) {
      const walkMins = Math.ceil(pickupDistM / MATCH_CONFIG.average_walk_speed_m_per_min);
      extendedCampusMatches.push({
        ...formattedRide,
        _is_extended_match: true,
        _walk_distance_m: pickupDistM,
        _walk_time_mins: walkMins,
        _badge_color: 'amber',
        _badge_label: `⚡ Nearby (${walkMins} min walk required)`,
      });
    }
  }

  // If direct matches are fewer than 5, merge extended campus matches (SRS §6.3.1)
  let finalMatches = [...directMatches];
  if (finalMatches.length < MATCH_CONFIG.min_results_extended_threshold && extendedCampusMatches.length > 0) {
    finalMatches = finalMatches.concat(extendedCampusMatches);
  }

  // Sort best match score first (Descending)
  finalMatches.sort((a, b) => b.match_score - a.match_score);

  return finalMatches.slice(0, MATCH_CONFIG.max_matches);
}

module.exports = {
  MATCH_CONFIG,
  fetchSpatialCandidateRides,
  fetchNearbyBarrierLandmark,
  evaluateExclusionGates,
  calculateMatchScore,
  findMatchesForRider,
};
