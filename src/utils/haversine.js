// ============================================================
// Haversine Distance & Cross-Track Line-Segment Projection Utility
// Source of Truth: SRS §5.1, §6.3, §6.4
// ============================================================

'use strict';

/**
 * Calculates great-circle distance between two points in meters using Haversine formula.
 */
function distanceMeters(lat1, lng1, lat2, lng2) {
  if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) return Infinity;
  const toNum = (v) => (v === '' ? NaN : Number(v));
  const nLat1 = toNum(lat1), nLng1 = toNum(lng1), nLat2 = toNum(lat2), nLng2 = toNum(lng2);
  if ([nLat1, nLng1, nLat2, nLng2].some((n) => Number.isNaN(n))) return Infinity;
  const R = 6371000;
  const dLat = (nLat2 - nLat1) * (Math.PI / 180);
  const dLng = (nLng2 - nLng1) * (Math.PI / 180);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(nLat1 * (Math.PI / 180)) * Math.cos(nLat2 * (Math.PI / 180)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

/**
 * Calculates distance in kilometers.
 */
function distanceKm(lat1, lng1, lat2, lng2) {
  const m = distanceMeters(lat1, lng1, lat2, lng2);
  return m === Infinity ? null : m / 1000;
}

/**
 * Calculates perpendicular shortest distance from a point P to a line segment AB.
 * Uses equirectangular projection approximation for local urban coordinates (< 50km).
 *
 * @param {number} latP - Point latitude
 * @param {number} lngP - Point longitude
 * @param {number} latA - Segment start latitude
 * @param {number} lngA - Segment start longitude
 * @param {number} latB - Segment end latitude
 * @param {number} lngB - Segment end longitude
 * @returns {number} Shortest distance in meters from P to segment AB
 */
function pointToSegmentDistanceMeters(latP, lngP, latA, lngA, latB, lngB) {
  const lenM = distanceMeters(latA, lngA, latB, lngB);
  if (lenM === 0) return distanceMeters(latP, lngP, latA, lngA);

  const meanLatRad = ((latA + latB) / 2) * (Math.PI / 180);
  const x = (lngB - lngA) * Math.cos(meanLatRad);
  const y = latB - latA;

  const dx = (lngP - lngA) * Math.cos(meanLatRad);
  const dy = latP - latA;

  const dot = dx * x + dy * y;
  const lenSq = x * x + y * y;
  const t = Math.max(0, Math.min(1, dot / lenSq));

  const projLat = latA + t * (latB - latA);
  const projLng = lngA + t * (lngB - lngA);

  return distanceMeters(latP, lngP, projLat, projLng);
}

/**
 * Finds closest waypoint index among discrete vertices.
 */
function findClosestRoutePoint(routePoints, lat, lng) {
  if (!routePoints || routePoints.length === 0) return { index: -1, distance: Infinity };
  let minDist = Infinity, minIdx = -1;
  for (let i = 0; i < routePoints.length; i++) {
    const d = distanceMeters(lat, lng, routePoints[i].lat, routePoints[i].lng);
    if (d < minDist) { minDist = d; minIdx = i; }
  }
  return { index: minIdx, distance: minDist };
}

/**
 * Evaluates whether a point (lat, lng) falls within 'radius' meters of any continuous
 * line segment along routePoints[fromIndex ... toIndex].
 * Performs true perpendicular cross-track line-segment projection.
 */
function isNearRouteSegment(routePoints, fromIndex, toIndex, lat, lng, radius) {
  if (!routePoints || routePoints.length === 0) return { match: false, distance: Infinity, index: -1 };
  if (routePoints.length === 1) {
    const d = distanceMeters(lat, lng, routePoints[0].lat, routePoints[0].lng);
    return { match: d <= radius, distance: d, index: 0 };
  }

  const start = Math.max(0, fromIndex);
  const end = Math.min(routePoints.length - 1, toIndex);
  let minDist = Infinity;
  let bestIdx = -1;

  for (let i = start; i < end; i++) {
    const p1 = routePoints[i];
    const p2 = routePoints[i + 1];
    const d = pointToSegmentDistanceMeters(lat, lng, p1.lat, p1.lng, p2.lat, p2.lng);
    if (d < minDist) {
      minDist = d;
      bestIdx = i;
    }
  }

  // Also check end vertex directly
  const lastD = distanceMeters(lat, lng, routePoints[end].lat, routePoints[end].lng);
  if (lastD < minDist) {
    minDist = lastD;
    bestIdx = end;
  }

  return { match: minDist <= radius, distance: minDist, index: bestIdx };
}

/**
 * Calculates total road distance of polyline waypoints in kilometers.
 */
function routeTotalKm(routePoints) {
  if (!routePoints || routePoints.length < 2) return 0;
  let total = 0;
  for (let i = 0; i < routePoints.length - 1; i++) {
    total += distanceMeters(routePoints[i].lat, routePoints[i].lng, routePoints[i + 1].lat, routePoints[i + 1].lng);
  }
  return total / 1000;
}

function estimateEtaText(km) {
  if (km == null || km <= 0) return '';
  const minutes = Math.max(1, Math.round((km / 20) * 60));
  if (minutes < 60) return `${minutes} min${minutes === 1 ? '' : 's'}`;
  const hrs = Math.floor(minutes / 60);
  const rem = minutes % 60;
  return rem === 0 ? `${hrs} hr` : `${hrs} hr ${rem} min${rem === 1 ? '' : 's'}`;
}

module.exports = {
  distanceMeters,
  distanceKm,
  pointToSegmentDistanceMeters,
  findClosestRoutePoint,
  isNearRouteSegment,
  routeTotalKm,
  estimateEtaText,
};
