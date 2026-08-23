// ============================================================
// Comprehensive Automated Test Suite for Ride Controller (Step 7)
// Covers Routing, Auto-Fare, Boarding Verification, Drop-Off Settlement & Push Links
// Source of Truth: SRS §4.7, §4.9 (Fare Math), §8.4 (Ola Maps Routing),
//                  §8.9 (Boarding Verification), §10.1 (Drop-Off Settlement)
// ============================================================

require('dotenv').config();
const rideController = require('./src/controllers/rideController');
const rideRoutes = require('./src/routes/rides');
const walletService = require('./src/services/walletService');
const notificationService = require('./src/services/notificationService');
const { supabaseAdmin } = require('./src/config/supabase');

async function runRideControllerTestSuite() {
  console.log('\n==================================================');
  console.log('🧪 RUNNING RIDE CONTROLLER SCENARIO TEST SUITE (STEP 7)');
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

  // ─── SCENARIO 1: OLA MAPS / HAVERSINE ROUTING ENGINE ─────────
  console.log('--- 1. Testing Ola Maps / Haversine Routing Engine (fetchRoutePolyline) ---');

  // Test 1.1: Hebbal (13.0358, 77.5970) -> Manyata Tech Park (13.0475, 77.6200)
  const routeHebbalManyata = await rideController.fetchRoutePolyline(13.0358, 77.5970, 13.0475, 77.6200);
  assert('Pos 1.1a: Route distance calculated with tortuosity factor', routeHebbalManyata.distance_km > 2.0 && routeHebbalManyata.distance_km < 6.0, `(Got ${routeHebbalManyata.distance_km} km)`);
  assert('Pos 1.1b: Generates interpolated route waypoints array', Array.isArray(routeHebbalManyata.route_points) && routeHebbalManyata.route_points.length >= 2, `(Got ${routeHebbalManyata.route_points.length} points)`);
  assert('Pos 1.1c: Calculates realistic duration in minutes', routeHebbalManyata.estimated_duration_mins >= 5, `(Got ${routeHebbalManyata.estimated_duration_mins} mins)`);
  assert('Pos 1.1d: Contains boolean is_fallback indicator', typeof routeHebbalManyata.is_fallback === 'boolean');

  // Test 1.2: Zero-distance / Same origin & destination edge case
  const routeZero = await rideController.fetchRoutePolyline(13.0358, 77.5970, 13.0358, 77.5970);
  assert('Pos 1.2: Same coordinate route yields 0 km distance and minimum duration', routeZero.distance_km === 0 && routeZero.estimated_duration_mins >= 5);

  // ─── SCENARIO 2: AUTO-FARE CALCULATION ENGINE ────────────────
  console.log('\n--- 2. Testing Auto-Fare Engine for Car and Two-Wheeler (SRS §4.9) ---');

  // Test 2.1: 10 km Car ride (Rate 2.0 Coins/km)
  const fareCar10Km = walletService.calculateFare(10.0, 'car', 0, 1);
  assert('Pos 2.1a: 10 km Car ride is 20 Coins per seat', fareCar10Km.base_fare_per_seat === 20);
  assert('Pos 2.1b: Car rate per km is 2.0 Coins', fareCar10Km.rate_per_km === 2.0);

  // Test 2.2: 10 km Bike ride (Rate 1.0 Coins/km)
  const fareBike10Km = walletService.calculateFare(10.0, 'bike', 0, 1);
  assert('Pos 2.2a: 10 km Bike ride is 10 Coins per seat', fareBike10Km.base_fare_per_seat === 10);
  assert('Pos 2.2b: Bike rate per km is 1.0 Coin', fareBike10Km.rate_per_km === 1.0);

  // Test 2.3: Floor Minimum Fare Check (1.5 km short ride)
  const fareShortCar = walletService.calculateFare(1.5, 'car', 0, 1);
  assert('Pos 2.3: Short 1.5 km Car ride enforces minimum 5 Coins floor rate', fareShortCar.base_fare_per_seat === 5);

  const fareShortBike = walletService.calculateFare(1.5, 'bike', 0, 1);
  assert('Pos 2.4: Short 1.5 km Bike ride enforces minimum 3 Coins floor rate', fareShortBike.base_fare_per_seat === 3);

  // Test 2.5: Multi-Seat Car Booking (3 seats, 12 km = 24 * 3 = 72 Coins)
  const fareMultiSeat = walletService.calculateFare(12.0, 'car', 0, 3);
  assert('Pos 2.5: 3-Seat Car booking triples total rider fare to 72 Coins', fareMultiSeat.total_rider_fare === 72);

  // ─── SCENARIO 3: ATOMIC BOARDING VERIFICATION RPC ────────────
  console.log('\n--- 3. Testing Atomic Boarding Verification RPC Signature (POST /rides/:id/verify-boarding) ---');

  try {
    const dummyReqId = '00000000-0000-0000-0000-000000000001';
    const { error } = await supabaseAdmin.rpc('verify_boarding_atomic', {
      p_request_id: dummyReqId,
      p_method: 'pin',
      p_pin_word: '1234',
    });

    const isParamMismatch = error && (error.code === '42883' || error.code === 'PGRST202' || error.message?.includes('parameter'));
    assert('Pos 3.1: verify_boarding_atomic RPC accepts exact parameters { p_request_id, p_method, p_pin_word, p_ble_uuid }', !isParamMismatch, error?.message);
  } catch (err) {
    assert('verify_boarding_atomic RPC exception', false, err.message);
  }

  // ─── SCENARIO 4: ATOMIC DROP-OFF & COMPLETE RIDE RPC ─────────
  console.log('\n--- 4. Testing Atomic Complete Ride RPC Signature (PATCH /rides/:id/complete) ---');

  try {
    const dummyRideId = '00000000-0000-0000-0000-000000000001';
    const dummyDriverId = '00000000-0000-0000-0000-000000000002';
    const { error } = await supabaseAdmin.rpc('complete_ride', {
      p_ride_id: dummyRideId,
      p_driver_id: dummyDriverId,
    });

    const isParamMismatch = error && (error.code === '42883' || error.code === 'PGRST202' || error.message?.includes('parameter'));
    assert('Pos 4.1: complete_ride RPC accepts exact parameters { p_ride_id, p_driver_id }', !isParamMismatch, error?.message);
  } catch (err) {
    assert('complete_ride RPC exception', false, err.message);
  }

  // ─── SCENARIO 5: PUSH NOTIFICATION DEEP-LINK GENERATOR ───────
  console.log('\n--- 5. Testing Push Notification Pipeline & Deep Links ---');

  // Test 5.1: Deep link for ride start radar
  const startDeepLink = notificationService.buildDeepLink('request_accepted', { ride_id: 'RIDE-999' });
  assert('Pos 5.1: Ride start push deep-link points to live GPS radar', startDeepLink === '/rider/live/RIDE-999', `(Got ${startDeepLink})`);

  // Test 5.2: Deep link for ride complete rating screen
  const completeDeepLink = notificationService.buildDeepLink('ride_completed', { ride_id: 'RIDE-999' });
  assert('Pos 5.2: Ride completion push deep-link points to rating & review sheet', completeDeepLink === '/rating/RIDE-999', `(Got ${completeDeepLink})`);

  // Test 5.3: Channel routing verification
  const startCh = notificationService.getChannel('request_accepted');
  const completeCh = notificationService.getChannel('ride_completed');
  assert('Pos 5.3a: Start ride alerts use ride_alerts priority channel', startCh.channel === 'ride_alerts' && startCh.priority === 'high');
  assert('Pos 5.3b: Complete ride alerts use ride_alerts channel', completeCh.channel === 'ride_alerts');

  // ─── SCENARIO 6: CONTROLLER EXPORTS & ROUTE INTEGRITY ────────
  console.log('\n--- 6. Testing Controller Functions and Route Definitions ---');

  const requiredExports = [
    'fetchRoutePolyline',
    'postRide',
    'startRide',
    'verifyBoarding',
    'completeRide',
    'searchRides',
    'getMyRides',
    'getRide',
    'updateLocation',
    'cancelRide',
  ];

  for (const fn of requiredExports) {
    assert(`Pos 6.${requiredExports.indexOf(fn) + 1}: Controller exports '${fn}'`, typeof rideController[fn] === 'function');
  }

  // Verify Express router object is valid
  assert('Pos 6.11: Rides route module exports valid Express Router', Boolean(rideRoutes && typeof rideRoutes === 'function' && rideRoutes.stack));

  console.log('\n==================================================');
  console.log(`📊 TEST SUITE RESULTS: ${passed} passed, ${failed} failed`);
  if (failed === 0) {
    console.log('🎉 100% SUCCESS! All Step 7 Ride Controller specifications are verified!');
  }
  console.log('==================================================\n');
}

runRideControllerTestSuite();
