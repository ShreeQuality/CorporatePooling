// ============================================================
// GPS Service — Driver Location (Supabase Realtime)
// Driver writes location every 5s to driver_locations table
// Supabase Realtime pushes updates to Flutter app via WebSocket
// Same concept as KarmaRide's Firebase RTDB /ride_locations/{rideId}
// ============================================================

'use strict';

const { supabaseAdmin } = require('../config/supabase');
const { findClosestRoutePoint } = require('../utils/haversine');

/**
 * Update driver's live GPS position for a ride.
 * Called from the driver's app every ~5 seconds.
 *
 * @param {string} rideId
 * @param {string} driverId
 * @param {number} lat
 * @param {number} lng
 * @param {Array<{lat,lng}>} routePoints - stored on the ride
 */
async function updateDriverLocation(rideId, driverId, lat, lng, routePoints = []) {
  // Find nearest route point index (for Phase 2 matching)
  const { index: routeIndex, distance: routeDistance } = findClosestRoutePoint(routePoints, lat, lng);

  const { error } = await supabaseAdmin
    .from('driver_locations')
    .upsert({
      ride_id: rideId,
      driver_id: driverId,
      lat,
      lng,
      current_route_index: routeIndex >= 0 ? routeIndex : 0,
      route_distance_m: Math.round(routeDistance === Infinity ? 0 : routeDistance),
      updated_at: new Date().toISOString(),
    }, { onConflict: 'ride_id' });

  if (error) throw new Error(`GPS update failed: ${error.message}`);
  return { routeIndex, routeDistance };
}

/**
 * Get last known driver location for a ride
 */
async function getDriverLocation(rideId) {
  const { data, error } = await supabaseAdmin
    .from('driver_locations')
    .select('lat, lng, current_route_index, route_distance_m, updated_at')
    .eq('ride_id', rideId)
    .single();

  if (error) return null;
  return data;
}

/**
 * Remove driver location when ride ends
 */
async function clearDriverLocation(rideId) {
  const { error } = await supabaseAdmin
    .from('driver_locations')
    .delete()
    .eq('ride_id', rideId);

  if (error) console.warn(`[gpsService] clearDriverLocation error for ${rideId}:`, error.message);
}

module.exports = { updateDriverLocation, getDriverLocation, clearDriverLocation };
