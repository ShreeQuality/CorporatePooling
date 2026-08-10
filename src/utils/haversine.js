// ============================================================
// Haversine Distance Utility
// Ported from KarmaRide matchingAlgorithm.js
// ============================================================

'use strict';

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

function distanceKm(lat1, lng1, lat2, lng2) {
  const m = distanceMeters(lat1, lng1, lat2, lng2);
  return m === Infinity ? null : m / 1000;
}

function findClosestRoutePoint(routePoints, lat, lng) {
  if (!routePoints || routePoints.length === 0) return { index: -1, distance: Infinity };
  let minDist = Infinity, minIdx = -1;
  for (let i = 0; i < routePoints.length; i++) {
    const d = distanceMeters(lat, lng, routePoints[i].lat, routePoints[i].lng);
    if (d < minDist) { minDist = d; minIdx = i; }
  }
  return { index: minIdx, distance: minDist };
}

function isNearRouteSegment(routePoints, fromIndex, toIndex, lat, lng, radius) {
  if (!routePoints || routePoints.length === 0) return { match: false, distance: Infinity, index: -1 };
  const start = Math.max(0, fromIndex);
  const end = Math.min(routePoints.length - 1, toIndex);
  let minDist = Infinity, bestIdx = -1;
  for (let i = start; i <= end; i++) {
    const d = distanceMeters(lat, lng, routePoints[i].lat, routePoints[i].lng);
    if (d < minDist) { minDist = d; bestIdx = i; }
  }
  return { match: minDist <= radius, distance: minDist, index: bestIdx };
}

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

module.exports = { distanceMeters, distanceKm, findClosestRoutePoint, isNearRouteSegment, routeTotalKm, estimateEtaText };
