// Comprehensive Automated Test Suite for Matching Service (Tier 1 & Tier 2)
// Source of Truth: SRS §5.1.1, §6.1, §6.3, §6.4, §6.5, §6.6
require('dotenv').config();
const matchingService = require('./src/services/matchingService');
const { isNearRouteSegment, pointToSegmentDistanceMeters } = require('./src/utils/haversine');

async function runMatchingTests() {
  console.log('\n==================================================');
  console.log('🧪 RUNNING MATCHING ENGINE AUDIT TEST SUITE (AREA 1)');
  console.log('==================================================\n');

  let passed = 0;
  let failed = 0;

  function assert(title, condition, extra = '') {
    if (condition) {
      console.log(`  ✅ [PASS] ${title} ${extra}`);
      passed++;
    } else {
      console.log(`  ❌ [FAIL] ${title} ${extra}`);
      failed++;
    }
  }

  // ─── 1. PERPENDICULAR CROSS-TRACK LINE SEGMENT MATCHING ──────
  console.log('--- 1. Testing Perpendicular Cross-Track Line Segment Math (SRS §6.3) ---');
  // Segment A -> B is 1 km along a straight horizontal latitude line (lat: 13.0000, lng: 77.5000 to 77.5093)
  const pA = { lat: 13.0000, lng: 77.5000 };
  const pB = { lat: 13.0000, lng: 77.5100 };
  // Point P is in the middle (lng: 77.5050), but 50m north (lat: 13.00045)
  const pMidOffroad = { lat: 13.00045, lng: 77.5050 };

  const crossTrackDist = pointToSegmentDistanceMeters(pMidOffroad.lat, pMidOffroad.lng, pA.lat, pA.lng, pB.lat, pB.lng);
  assert('Pos 1.1: Perpendicular distance from midpoint to segment is ~50m', crossTrackDist >= 45 && crossTrackDist <= 55, `(Got ${Math.round(crossTrackDist)}m)`);

  const segmentCheck = isNearRouteSegment([pA, pB], 0, 1, pMidOffroad.lat, pMidOffroad.lng, 500);
  assert('Pos 1.2: Point between 1km sparse vertices matches within 500m radius', segmentCheck.match === true);

  // ─── 2. HARD EXCLUSION GATES (SRS §6.6) ─────────────────────
  console.log('\n--- 2. Testing Hard Exclusion Gates (SRS §6.6) ---');

  // Gate 1: Self-Match
  const gate1 = matchingService.evaluateExclusionGates(
    { driver_id: 'user-123', seats_available: 3 },
    { id: 'user-123' },
    1
  );
  assert('Gate 1: Driver self-match is REJECTED', gate1.pass === false && gate1.reason === 'SELF_MATCH_GUARD');

  // Gate 2: Women-Only Guard
  const gate2Male = matchingService.evaluateExclusionGates(
    { driver_id: 'd1', women_only: true, seats_available: 3 },
    { id: 'r1', gender: 'male' },
    1
  );
  assert('Gate 2: Male rider rejected from women-only ride', gate2Male.pass === false && gate2Male.reason === 'WOMEN_ONLY_GUARD');

  const gate2Female = matchingService.evaluateExclusionGates(
    { driver_id: 'd1', women_only: true, seats_available: 3 },
    { id: 'r1', gender: 'female' },
    1
  );
  assert('Gate 2: Female rider accepted for women-only ride', gate2Female.pass === true);

  // Gate 3: 2-Wheeler Helmet & Seat Guard
  const gate3TwoSeats = matchingService.evaluateExclusionGates(
    { driver_id: 'd1', vehicle_type: 'bike', seats_available: 2 },
    { id: 'r1' },
    2
  );
  assert('Gate 3: 2 seats on a bike is REJECTED', gate3TwoSeats.pass === false && gate3TwoSeats.reason === 'TWO_WHEELER_SEAT_LIMIT');

  const gate3OneSeat = matchingService.evaluateExclusionGates(
    { driver_id: 'd1', vehicle_type: 'bike', seats_available: 1 },
    { id: 'r1' },
    1
  );
  assert('Gate 3: 1 seat on a bike is ACCEPTED', gate3OneSeat.pass === true);

  // Gate 4: Available Capacity
  const gate4 = matchingService.evaluateExclusionGates(
    { driver_id: 'd1', seats_available: 1 },
    { id: 'r1' },
    2
  );
  assert('Gate 4: Overbooking request is REJECTED', gate4.pass === false && gate4.reason === 'INSUFFICIENT_SEATS');

  // Gate 5: Banned Driver Guard (Fix 1.4)
  const gate5Banned = matchingService.evaluateExclusionGates(
    { driver_id: 'd1', driver_is_banned: true, seats_available: 3 },
    { id: 'r1' },
    1
  );
  assert('Gate 5: Suspended/Banned driver is REJECTED', gate5Banned.pass === false && gate5Banned.reason === 'DRIVER_BANNED');

  // ─── 3. TRUST & PRIORITY SCORING FORMULA (SRS §6.5) ─────────
  console.log('\n--- 3. Testing Trust & Priority Scoring Formula (SRS §6.5) ---');

  // Scenario A: Same Company Colleague (+30 Pts Trust)
  const scoreColleague = matchingService.calculateMatchScore(
    { driver_company_id: 'comp-100', driver_trust_score: 90 },
    { company_id: 'comp-100' },
    50,
    50,
    0
  );
  assert('Same company colleague scores +30 corporate trust', scoreColleague.breakdown.corporate_trust === 30);
  assert('Same company colleague with 0m detour scores > 90 total', scoreColleague.total_score >= 90, `(Got ${scoreColleague.total_score})`);

  // Scenario B: Same Building / Tech Park (+25 Pts Trust)
  const scoreBuilding = matchingService.calculateMatchScore(
    { driver_company_id: 'comp-200', driver_building_id: 'bld-50', driver_trust_score: 80 },
    { company_id: 'comp-100', building_id: 'bld-50' },
    100,
    100,
    5
  );
  assert('Same tech park building scores +25 corporate trust', scoreBuilding.breakdown.corporate_trust === 25);
  assert('Building score total is between 75 and 90', scoreBuilding.total_score >= 75 && scoreBuilding.total_score <= 90, `(Got ${scoreBuilding.total_score})`);

  // Scenario C: Public Verified User (+10 Pts Trust)
  const scorePublic = matchingService.calculateMatchScore(
    { driver_role: 'public_user', driver_trust_score: 50 },
    { role: 'public_user' },
    200,
    200,
    15
  );
  assert('Public verified user scores +10 corporate trust', scorePublic.breakdown.corporate_trust === 10);

  // ─── 4. TIER 1 POSTGIS FETCH & BARRIER LANDMARK AUDIT ────────
  console.log('\n--- 4. Testing Tier 1 PostGIS Pre-Filter & Barrier Landmarks (Migration 018) ---');
  try {
    const candidates = await matchingService.fetchSpatialCandidateRides(
      '00000000-0000-0000-0000-000000000001',
      13.0358, 77.5970, // Hebbal
      13.0475, 77.6200, // Manyata
      { seatsRequested: 1, maxRadiusMeters: 1500 }
    );
    assert('Tier 1 PostGIS RPC executed without exception', Array.isArray(candidates));

    const barrierLandmark = await matchingService.fetchNearbyBarrierLandmark(13.0456, 77.5937, 500);
    assert('Barrier landmark RPC executed without exception', barrierLandmark === null || typeof barrierLandmark === 'object');
    if (barrierLandmark) {
      console.log(`     📍 Nearest Safe Pickup Landmark: ${barrierLandmark.name} (${barrierLandmark.barrier_type}) - ${barrierLandmark.suggested_pickup_note}`);
    }
  } catch (err) {
    assert('Tier 1 PostGIS RPC error', false, err.message);
  }

  console.log('\n==================================================');
  console.log(`📊 TEST RESULTS: ${passed} passed, ${failed} failed`);
  if (failed === 0) {
    console.log('🎉 100% SUCCESS! Area 1 (Matching Engine) is fully verified & all gaps resolved!');
  }
  console.log('==================================================\n');
}

runMatchingTests();
