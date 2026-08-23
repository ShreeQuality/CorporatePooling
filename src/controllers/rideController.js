// ============================================================
// Ride Controller — Corporate Pooling Backend
// Pure Route Polyline Engine, Auto-Fare, State Machine, Boarding & Drop-off Settlement
// Source of Truth: SRS §4.7, §4.9 (Fare Math), §8.4 (Ola Maps Routing),
//                  §8.9 (Boarding Verification), §10.1 (Drop-Off Settlement)
// ============================================================

'use strict';

const axios = require('axios');
const { v4: uuidv4 } = require('uuid');
const { supabaseAdmin } = require('../config/supabase');
const walletService = require('../services/walletService');
const notificationService = require('../services/notificationService');
const { findMatchesForRider } = require('../services/matchingService');
const { updateDriverLocation, clearDriverLocation } = require('../services/gpsService');
const { distanceKm, routeTotalKm } = require('../utils/haversine');
const { ok, created, badRequest, notFound, forbidden, serverError } = require('../utils/response');

// ============================================================
// SUBTASK 7.1: OLA MAPS ROUTING HELPER & AUTO-FARE ENGINE
// ============================================================

/**
 * Fetches real road polylines from Ola Maps Directions API with Haversine fallback.
 *
 * @param {number} fromLat - Origin Latitude
 * @param {number} fromLng - Origin Longitude
 * @param {number} toLat   - Destination Latitude
 * @param {number} toLng   - Destination Longitude
 * @returns {Promise<{ overview_polyline: string|null, distance_km: number, estimated_duration_mins: number, route_points: Array<{lat: number, lng: number}>, is_fallback: boolean }>}
 */
async function fetchRoutePolyline(fromLat, fromLng, toLat, toLng) {
  const fLat = parseFloat(fromLat);
  const fLng = parseFloat(fromLng);
  const tLat = parseFloat(toLat);
  const tLng = parseFloat(toLng);

  const apiKey = process.env.OLA_MAPS_API_KEY;

  // 1. Attempt live Ola Maps Directions API call if API key is configured
  if (apiKey && apiKey !== 'mock_key' && apiKey !== 'placeholder') {
    try {
      const url = 'https://api.olamaps.io/routing/v1/directions';
      const response = await axios.get(url, {
        params: {
          origin: `${fLat},${fLng}`,
          destination: `${tLat},${tLng}`,
          api_key: apiKey,
        },
        headers: {
          'X-Request-Id': uuidv4(),
        },
        timeout: 5000,
      });

      if (response.data && response.data.routes && response.data.routes.length > 0) {
        const route = response.data.routes[0];
        const polyline = route.overview_polyline || (route.overview_polyline && route.overview_polyline.points) || null;
        
        let distKm = 0;
        let durationMins = 0;

        if (route.legs && route.legs.length > 0) {
          const leg = route.legs[0];
          distKm = leg.distance?.value ? leg.distance.value / 1000 : (parseFloat(leg.distance) || 0);
          durationMins = leg.duration?.value ? Math.round(leg.duration.value / 60) : (parseInt(leg.duration, 10) || 0);
        } else if (route.distance) {
          distKm = parseFloat(route.distance) > 100 ? parseFloat(route.distance) / 1000 : parseFloat(route.distance);
          durationMins = route.duration ? Math.round(parseFloat(route.duration) / 60) : 0;
        }

        // Generate or extract route points
        let points = [];
        if (Array.isArray(route.points) && route.points.length > 0) {
          points = route.points.map((p) => ({ lat: parseFloat(p.lat || p[0]), lng: parseFloat(p.lng || p[1]) }));
        } else {
          // Sample 8 interpolated points if raw coordinate array not present
          const steps = 8;
          for (let i = 0; i <= steps; i++) {
            const frac = i / steps;
            points.push({
              lat: Number((fLat + (tLat - fLat) * frac).toFixed(6)),
              lng: Number((fLng + (tLng - fLng) * frac).toFixed(6)),
            });
          }
        }

        return {
          overview_polyline: polyline,
          distance_km: Number(distKm.toFixed(2)),
          estimated_duration_mins: durationMins || Math.max(5, Math.round((distKm / 25) * 60)),
          route_points: points,
          is_fallback: false,
        };
      }
    } catch (err) {
      console.warn('[RideController] Ola Maps API call failed, falling back to Haversine tortuosity model:', err.message);
    }
  }

  // 2. Graceful Fallback: Haversine distance * 1.3 (tortuosity factor)
  const straightDistKm = distanceKm(fLat, fLng, tLat, tLng) || 0;
  const tortuosityFactor = 1.3;
  const routeDistKm = Number((straightDistKm * tortuosityFactor).toFixed(2));
  const estimatedDurationMins = Math.max(5, Math.round((routeDistKm / 25) * 60)); // Avg 25 km/h urban speed

  // Generate 8 interpolated route waypoints between origin & destination
  const steps = 8;
  const interpolatedPoints = [];
  for (let i = 0; i <= steps; i++) {
    const fraction = i / steps;
    interpolatedPoints.push({
      lat: Number((fLat + (tLat - fLat) * fraction).toFixed(6)),
      lng: Number((fLng + (tLng - fLng) * fraction).toFixed(6)),
    });
  }

  return {
    overview_polyline: null,
    distance_km: routeDistKm,
    estimated_duration_mins: estimatedDurationMins,
    route_points: interpolatedPoints,
    is_fallback: true,
  };
}

/**
 * Helper to add minutes to a "HH:MM:SS" or "HH:MM" time string.
 */
function addMinutesToTime(timeStr, minutesToAdd) {
  if (!timeStr) return '09:00:00';
  const parts = timeStr.split(':').map((p) => parseInt(p, 10));
  const h = parts[0] || 0;
  const m = parts[1] || 0;
  const totalMins = h * 60 + m + minutesToAdd;
  const newH = Math.floor(totalMins / 60) % 24;
  const newM = totalMins % 60;
  const pad = (n) => String(n).padStart(2, '0');
  return `${pad(newH)}:${pad(newM)}:00`;
}

/**
 * POST /api/v1/rides
 * Body: {
 *   from_address, from_lat, from_lng,
 *   to_address, to_lat, to_lng,
 *   vehicle_id, total_seats / seats_offered, coin_per_seat / fare_coins,
 *   time_type, depart_time, depart_date, depart_timestamp,
 *   recurring_days, valid_until, women_only / women_only_flag,
 *   route_points, building_id, is_open_to_public
 * }
 */
async function postRide(req, res) {
  try {
    const {
      from_address, from_lat, from_lng,
      to_address, to_lat, to_lng,
      vehicle_id, total_seats, seats_offered, coin_per_seat, fare_coins,
      time_type, depart_time, depart_date, depart_timestamp,
      recurring_days, valid_until, women_only, women_only_flag,
      route_points, building_id, is_open_to_public,
    } = req.body;

    // 1. Mandatory Field Validations
    if (!from_address || !to_address) return badRequest(res, 'from_address and to_address are required.');
    if (from_lat == null || from_lng == null || to_lat == null || to_lng == null) {
      return badRequest(res, 'from_lat, from_lng, to_lat, and to_lng coordinates are required.');
    }

    const seats = parseInt(seats_offered || total_seats, 10) || 1;
    if (seats < 1) return badRequest(res, 'seats_offered must be at least 1.');

    if (!time_type || !['now', 'scheduled', 'recurring'].includes(time_type)) {
      return badRequest(res, 'time_type must be: now, scheduled, or recurring.');
    }

    const driverId = req.user.id;

    // 2. Driver verification check
    if (req.user.user_type === 'public' && !req.user.is_driver_verified) {
      return forbidden(res, 'Driver document verification pending. You cannot post rides until approved.');
    }

    const fLat = parseFloat(from_lat);
    const fLng = parseFloat(from_lng);
    const tLat = parseFloat(to_lat);
    const tLng = parseFloat(to_lng);

    // 3. Resolve Vehicle Type
    let vehicleType = 'car';
    if (vehicle_id) {
      const { data: vehicle } = await supabaseAdmin
        .from('vehicles')
        .select('vehicle_type, is_active')
        .eq('id', vehicle_id)
        .single();

      if (vehicle?.vehicle_type) {
        vehicleType = vehicle.vehicle_type;
      }
    }

    // 4. Route & Distance Calculation (Ola Maps / Haversine fallback)
    let calculatedRoute;
    if (route_points && Array.isArray(route_points) && route_points.length >= 2) {
      const dist = routeTotalKm(route_points);
      calculatedRoute = {
        distance_km: Number(dist.toFixed(2)),
        estimated_duration_mins: Math.max(5, Math.round((dist / 25) * 60)),
        route_points,
      };
    } else {
      calculatedRoute = await fetchRoutePolyline(fLat, fLng, tLat, tLng);
    }

    const distKm = calculatedRoute.distance_km || 1.0;
    const durationMins = calculatedRoute.estimated_duration_mins || 15;
    const finalRoutePoints = calculatedRoute.route_points;

    // 5. Auto-Fare Calculation Engine (SRS §4.9)
    const fareEstimate = walletService.calculateFare(distKm, vehicleType, 0, 1);
    const assignedFarePerSeat = (fare_coins != null || coin_per_seat != null)
      ? parseFloat(fare_coins || coin_per_seat)
      : fareEstimate.base_fare_per_seat;

    // 6. Format Time & Dates
    let departTimeStr = depart_time || '08:30:00';
    if (departTimeStr.length === 5) departTimeStr += ':00'; // HH:MM -> HH:MM:SS

    let departDateStr = depart_date || null;
    if (!departDateStr && depart_timestamp) {
      try {
        const d = new Date(depart_timestamp);
        if (!isNaN(d.getTime())) {
          departDateStr = d.toISOString().split('T')[0];
        }
      } catch (_) {}
    }

    const reachTimeStr = addMinutesToTime(departTimeStr, durationMins);

    // 7. Generate 4-digit spoken boarding PIN / daily word (SRS §8.9)
    const boardingDailyWord = String(Math.floor(1000 + Math.random() * 9000));

    // 8. PostGIS Geometries WKT string representations
    const fromLocationWkt = `POINT(${fLng} ${fLat})`;
    const toLocationWkt = `POINT(${tLng} ${tLat})`;
    const routeGeometryWkt = `LINESTRING(${finalRoutePoints.map((p) => `${p.lng} ${p.lat}`).join(', ')})`;

    // 9. Insert into public.rides
    const { data: ride, error } = await supabaseAdmin
      .from('rides')
      .insert({
        driver_id: driverId,
        vehicle_id: vehicle_id || null,
        from_address,
        from_location: fromLocationWkt,
        to_address,
        to_location: toLocationWkt,
        building_id: building_id || null,
        route_geometry: routeGeometryWkt,
        route_points: finalRoutePoints,
        distance_km: distKm,
        estimated_duration_mins: durationMins,
        depart_time: departTimeStr,
        approx_reach_time: reachTimeStr,
        depart_date: departDateStr,
        seats_offered: seats,
        seats_available: seats,
        fare_coins: assignedFarePerSeat,
        time_type,
        recurring_days: Array.isArray(recurring_days) ? recurring_days : [],
        valid_until: valid_until || null,
        ride_status: 'posted',
        women_only_flag: Boolean(women_only || women_only_flag),
        boarding_daily_word: boardingDailyWord,
        is_open_to_public: is_open_to_public !== false,
      })
      .select()
      .single();

    if (error) {
      console.error('[RideController] postRide insert error:', error.message);
      return serverError(res, error, 'Failed to post ride.');
    }

    return created(res, {
      ride,
      fare_breakdown: fareEstimate,
    }, 'Ride posted successfully.');
  } catch (err) {
    return serverError(res, err);
  }
}

// ============================================================
// SUBTASK 7.2: RIDE START & LIVE GPS RADAR ACTIVATION
// PATCH /api/v1/rides/:id/start
// ============================================================

async function startRide(req, res) {
  try {
    const rideId = req.params.id;
    const driverId = req.user.id;

    // 1. Verify driver ownership & ride existence
    const { data: ride, error: rideErr } = await supabaseAdmin
      .from('rides')
      .select('id, driver_id, ride_status, from_address, to_address')
      .eq('id', rideId)
      .single();

    if (rideErr || !ride) return notFound(res, 'Ride not found.');
    if (ride.driver_id !== driverId) return forbidden(res, 'Unauthorized. Not your ride.');
    if (ride.ride_status !== 'posted' && ride.ride_status !== 'driver_en_route') {
      return badRequest(res, `Cannot start ride in status '${ride.ride_status}'.`);
    }

    // 2. Set ride_status = 'started', started_at = NOW()
    const { error: updateErr } = await supabaseAdmin
      .from('rides')
      .update({
        ride_status: 'started',
        started_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq('id', rideId);

    if (updateErr) return serverError(res, updateErr, 'Failed to update ride status.');

    // 3. Fetch all accepted riders for this ride
    const { data: acceptedRequests } = await supabaseAdmin
      .from('ride_requests')
      .select('id, rider_id')
      .eq('ride_id', rideId)
      .in('status', ['accepted', 'pending']);

    // 4. Dispatch High-Priority Push Notification to Accepted Riders (SRS §16.2 & §16.3)
    const riderIds = (acceptedRequests || []).map((r) => r.rider_id);
    for (const r of (acceptedRequests || [])) {
      notificationService.sendPushNotification(
        r.rider_id,
        '🚗 Driver is on the way!',
        'Your driver has started the commute. Tap to open live GPS radar.',
        'request_accepted',
        { ride_id: rideId, request_id: r.id }
      ).catch((e) => console.warn('[RideController] Rider start push error:', e.message));
    }

    return ok(res, {
      ride_id: rideId,
      status: 'started',
      riders_notified: riderIds.length,
    }, 'Ride started. Live GPS radar active.');
  } catch (err) {
    return serverError(res, err);
  }
}

// ============================================================
// SUBTASK 7.3: ATOMIC BOARDING VERIFICATION ENGINE
// POST /api/v1/rides/:id/verify-boarding
// Body: { rider_id, request_id, entered_pin, pin_word, ble_token, ble_uuid, method }
// ============================================================

async function verifyBoarding(req, res) {
  try {
    const rideId = req.params.id;
    const {
      rider_id,
      request_id,
      entered_pin,
      pin_word,
      ble_token,
      ble_uuid,
      method,
    } = req.body;

    // 1. Resolve Target Ride Request
    let targetRequestId = request_id;
    let targetRiderId = rider_id;

    if (!targetRequestId) {
      if (!targetRiderId) {
        return badRequest(res, 'Either request_id or rider_id is required.');
      }
      const { data: reqRow, error: reqFindErr } = await supabaseAdmin
        .from('ride_requests')
        .select('id, rider_id, status')
        .eq('ride_id', rideId)
        .eq('rider_id', targetRiderId)
        .in('status', ['accepted', 'pending'])
        .single();

      if (reqFindErr || !reqRow) {
        return notFound(res, 'Active accepted booking request not found for this rider on this ride.');
      }
      targetRequestId = reqRow.id;
    } else if (!targetRiderId) {
      const { data: reqRow } = await supabaseAdmin
        .from('ride_requests')
        .select('rider_id')
        .eq('id', targetRequestId)
        .single();
      if (reqRow) targetRiderId = reqRow.rider_id;
    }

    // 2. Determine verification method and token
    const isBle = Boolean(ble_token || ble_uuid || method === 'ble');
    const pMethod = isBle ? 'ble' : 'pin';
    const pPinWord = isBle ? null : (entered_pin || pin_word || null);
    const pBleUuid = isBle ? (ble_token || ble_uuid || null) : null;

    if (pMethod === 'pin' && !pPinWord) {
      return badRequest(res, 'entered_pin or pin_word is required for PIN verification.');
    }
    if (pMethod === 'ble' && !pBleUuid) {
      return badRequest(res, 'ble_token or ble_uuid is required for BLE verification.');
    }

    // 3. Call live PostgreSQL stored procedure: verify_boarding_atomic
    const { data: rpcResult, error: rpcErr } = await supabaseAdmin.rpc('verify_boarding_atomic', {
      p_request_id: targetRequestId,
      p_method: pMethod,
      p_pin_word: pPinWord,
      p_ble_uuid: pBleUuid,
    });

    if (rpcErr) {
      console.error('[RideController] verify_boarding_atomic error:', rpcErr.message);
      return badRequest(res, rpcErr.message || 'Boarding verification failed.');
    }

    if (rpcResult && !rpcResult.success) {
      return badRequest(res, rpcResult.error || 'INCORRECT_PIN_OR_TOKEN');
    }

    // 4. Dispatch celebratory FCM push notification to rider (SRS §16.3)
    if (targetRiderId) {
      notificationService.sendPushNotification(
        targetRiderId,
        '✅ Boarding Verified!',
        'Boarding verified! Enjoy your commute.',
        'request_accepted',
        { ride_id: rideId, request_id: targetRequestId }
      ).catch((e) => console.warn('[RideController] Boarding verified push error:', e.message));
    }

    return ok(res, {
      request_id: targetRequestId,
      ride_id: rideId,
      status: 'in_ride',
      details: rpcResult,
    }, 'Boarding verified successfully. Enjoy your commute.');
  } catch (err) {
    return serverError(res, err);
  }
}

// ============================================================
// SUBTASK 7.4: ATOMIC DROP-OFF & ESCROW SETTLEMENT
// PATCH /api/v1/rides/:id/complete
// ============================================================

async function completeRide(req, res) {
  try {
    const rideId = req.params.id;
    const driverId = req.user.id;

    // 1. Verify driver ownership & ride existence
    const { data: ride, error: rideErr } = await supabaseAdmin
      .from('rides')
      .select('id, driver_id, ride_status, distance_km')
      .eq('id', rideId)
      .single();

    if (rideErr || !ride) return notFound(res, 'Ride not found.');
    if (ride.driver_id !== driverId) return forbidden(res, 'Unauthorized. Not your ride.');

    // Fetch in-ride passengers before settlement for notification dispatch
    const { data: passengers } = await supabaseAdmin
      .from('ride_requests')
      .select('id, rider_id, status')
      .eq('ride_id', rideId)
      .in('status', ['in_ride', 'accepted', 'completed']);

    // 2. Call live PostgreSQL stored procedure: complete_ride(p_ride_id, p_driver_id)
    // Executes atomic settlement:
    // • Transfers locked escrow coins -> driver available balance
    // • Inserts corporate_attendance ESG log
    // • Updates ride_status = 'completed' (or resets for recurring)
    const { data: rpcResult, error: rpcErr } = await supabaseAdmin.rpc('complete_ride', {
      p_ride_id: rideId,
      p_driver_id: driverId,
    });

    if (rpcErr) {
      console.error('[RideController] complete_ride RPC error:', rpcErr.message);
      return badRequest(res, rpcErr.message || 'Failed to complete ride settlement.');
    }

    if (rpcResult && !rpcResult.success) {
      return badRequest(res, rpcResult.error || 'Failed to complete ride.');
    }

    // 3. Clear live GPS location from driver_locations table
    await clearDriverLocation(rideId);

    // 4. Dispatch Celebratory FCM Push to all riders with deep-link /rating/:ride_id (SRS §16.3)
    for (const p of (passengers || [])) {
      notificationService.sendPushNotification(
        p.rider_id,
        '🎉 Commute Completed!',
        'You have reached your destination. Please rate your ride and driver!',
        'ride_completed',
        { ride_id: rideId, request_id: p.id }
      ).catch((e) => console.warn('[RideController] Complete ride push error:', e.message));
    }

    return ok(res, {
      ride_id: rideId,
      status: 'completed',
      settlement_details: rpcResult,
    }, 'Ride completed successfully. Escrow settled and ESG attendance logged.');
  } catch (err) {
    return serverError(res, err);
  }
}

// ============================================================
// SUBTASK 7.5: RIDE QUERIES, LOCATION & LIFECYCLE CONTROLLERS
// ============================================================

/**
 * GET /api/v1/rides/search
 * Query: pickup_lat, pickup_lng, drop_lat, drop_lng,
 *        time_type?, depart_timestamp?, depart_date?, seats_requested?, max_radius_m?
 */
async function searchRides(req, res) {
  try {
    const {
      pickup_lat, pickup_lng, drop_lat, drop_lng,
      time_type, depart_timestamp, depart_date, seats_requested, max_radius_m,
    } = req.query;

    if (!pickup_lat || !pickup_lng || !drop_lat || !drop_lng) {
      return badRequest(res, 'pickup_lat, pickup_lng, drop_lat, drop_lng are required.');
    }

    const riderId = req.user ? req.user.id : null;
    const pLat = parseFloat(pickup_lat);
    const pLng = parseFloat(pickup_lng);
    const dLat = parseFloat(drop_lat);
    const dLng = parseFloat(drop_lng);
    const seats = parseInt(seats_requested, 10) || 1;
    const radius = parseInt(max_radius_m, 10) || 1500;

    let targetDate = depart_date || null;
    if (!targetDate && depart_timestamp) {
      try {
        const d = new Date(depart_timestamp);
        if (!isNaN(d.getTime())) {
          targetDate = d.toISOString().split('T')[0];
        }
      } catch (_) {}
    }

    const riderProfile = req.user || {
      id: riderId,
      gender: 'prefer_not_to_say',
      role: 'public_user',
      company_id: null,
      building_id: null,
    };

    // 2-Tier Funnel: PostGIS Spatial Pre-Filter + In-Memory Polyline & Trust Scoring
    const matched = await findMatchesForRider(
      riderProfile,
      pLat,
      pLng,
      dLat,
      dLng,
      {
        seats_requested: seats,
        time_type: time_type || 'now',
        target_date: targetDate,
        target_time: req.query.depart_time || null,
        vehicle_type: req.query.vehicle_type || 'all',
      }
    );

    return ok(res, {
      count: matched.length,
      rides: matched,
    });
  } catch (err) {
    return serverError(res, err);
  }
}

/**
 * GET /api/v1/rides/my
 * Paginated list of caller's posted rides.
 */
async function getMyRides(req, res) {
  try {
    const { status, limit = 20, offset = 0 } = req.query;
    let query = supabaseAdmin
      .from('rides')
      .select('id, from_address, to_address, ride_status, depart_time, depart_date, fare_coins, seats_available, seats_offered, distance_km, started_at, completed_at, created_at')
      .eq('driver_id', req.user.id)
      .order('created_at', { ascending: false })
      .range(parseInt(offset, 10), parseInt(offset, 10) + parseInt(limit, 10) - 1);

    if (status) query = query.eq('ride_status', status);

    const { data, error } = await query;
    if (error) return serverError(res, error, 'Failed to fetch my rides.');
    return ok(res, data || []);
  } catch (err) {
    return serverError(res, err);
  }
}

/**
 * GET /api/v1/rides/:id
 * Full single ride details sheet with passengers and driver profile.
 */
async function getRide(req, res) {
  try {
    const { data: ride, error } = await supabaseAdmin
      .from('rides')
      .select(`
        *,
        users!driver_id(id, full_name, profile_photo_url, trust_score, phone_number, role, company_id),
        vehicles(id, vehicle_type, vehicle_number, vehicle_model, vehicle_color),
        ride_requests(id, rider_id, status, pickup_address, drop_address, coins_locked, seats_requested,
          users!rider_id(id, full_name, profile_photo_url, trust_score))
      `)
      .eq('id', req.params.id)
      .single();

    if (error || !ride) return notFound(res, 'Ride not found.');
    return ok(res, ride);
  } catch (err) {
    return serverError(res, err);
  }
}

/**
 * PATCH /api/v1/rides/:id/location
 * Driver live GPS telemetry broadcast.
 * Body: { lat, lng }
 */
async function updateLocation(req, res) {
  try {
    const { lat, lng } = req.body;
    if (lat == null || lng == null) return badRequest(res, 'lat and lng coordinates are required.');

    const rideId = req.params.id;

    // Verify driver owns ride
    const { data: ride, error: rideErr } = await supabaseAdmin
      .from('rides')
      .select('route_points, driver_id')
      .eq('id', rideId)
      .single();

    if (rideErr || !ride) return notFound(res, 'Ride not found.');
    if (ride.driver_id !== req.user.id) return forbidden(res, 'Unauthorized. Not your ride.');

    const result = await updateDriverLocation(
      rideId,
      req.user.id,
      parseFloat(lat),
      parseFloat(lng),
      ride.route_points || []
    );

    // Sync rides table coordinates for Phase 2 spatial candidate matching
    await supabaseAdmin
      .from('rides')
      .update({
        current_lat: parseFloat(lat),
        current_lng: parseFloat(lng),
        current_route_index: result.routeIndex,
        updated_at: new Date().toISOString(),
      })
      .eq('id', rideId);

    return ok(res, { route_index: result.routeIndex, distance_m: result.routeDistance });
  } catch (err) {
    return serverError(res, err);
  }
}

/**
 * DELETE /api/v1/rides/:id
 * Driver cancels entire posted ride and refunds all passengers.
 */
async function cancelRide(req, res) {
  try {
    const rideId = req.params.id;
    const driverId = req.user.id;

    const { data: ride, error: rideErr } = await supabaseAdmin
      .from('rides')
      .select('id, driver_id, ride_status')
      .eq('id', rideId)
      .single();

    if (rideErr || !ride) return notFound(res, 'Ride not found.');
    if (ride.driver_id !== driverId) return forbidden(res, 'Unauthorized. Not your ride.');
    if (['completed', 'cancelled_by_driver', 'cancelled_by_user'].includes(ride.ride_status)) {
      return badRequest(res, 'Ride has already ended.');
    }

    // 1. Mark ride cancelled
    await supabaseAdmin
      .from('rides')
      .update({
        ride_status: 'cancelled_by_driver',
        updated_at: new Date().toISOString(),
      })
      .eq('id', rideId);

    // 2. Refund locked escrow coins to all accepted riders
    const { data: requests } = await supabaseAdmin
      .from('ride_requests')
      .select('id, rider_id, coins_locked')
      .eq('ride_id', rideId)
      .in('status', ['accepted', 'pending', 'in_ride']);

    for (const r of (requests || [])) {
      if (r.coins_locked > 0) {
        // Unlock rider coins
        await supabaseAdmin
          .from('wallets')
          .update({
            locked_balance: supabaseAdmin.raw ? undefined : 0, // Fallback if direct
          })
          .eq('user_id', r.rider_id);

        // Or call cancel_ride_request_atomic
        await supabaseAdmin.rpc('cancel_ride_request_atomic', {
          p_request_id: r.id,
          p_cancelled_by: driverId,
          p_reason: 'Driver cancelled entire ride',
        });
      }

      // Notify rider of ride cancellation
      notificationService.sendPushNotification(
        r.rider_id,
        '⚠️ Commute Cancelled by Driver',
        'Your scheduled ride was cancelled by the driver. All locked coins have been refunded.',
        'ride_cancelled',
        { ride_id: rideId, request_id: r.id }
      ).catch((e) => console.warn('[RideController] Cancel notification failed:', e.message));
    }

    // 3. Clear driver location
    await clearDriverLocation(rideId);

    return ok(res, null, 'Ride cancelled. All passenger escrows refunded.');
  } catch (err) {
    return serverError(res, err);
  }
}

module.exports = {
  fetchRoutePolyline,
  postRide,
  startRide,
  verifyBoarding,
  completeRide,
  searchRides,
  getMyRides,
  getRide,
  updateLocation,
  cancelRide,
};
