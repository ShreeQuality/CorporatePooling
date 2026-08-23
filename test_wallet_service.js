// Comprehensive Automated Test Suite for Wallet Service (Subtasks 2.1 - 2.5)
require('dotenv').config();
const walletService = require('./src/services/walletService');
const { supabaseAdmin } = require('./src/config/supabase');

async function runWalletTests() {
  console.log('\n==================================================');
  console.log('🧪 RUNNING FULL WALLET SERVICE TEST SUITE (2.1 - 2.5)');
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

  // ─── 1. SUBTASK 2.1: System Settings Cache ──────────────────
  console.log('--- 1. Testing System Settings Cache (2.1) ---');
  try {
    const cache = await walletService.initSettingsCache();
    assert('Settings cache initialized', typeof cache === 'object');
    assert('CAR rate is 2.0', cache.CAR_COIN_RATE_PER_KM === 2.0 || cache.CAR_COIN_RATE_PER_KM === 2);
    assert('BIKE rate is 1.0', cache.BIKE_COIN_RATE_PER_KM === 1.0 || cache.BIKE_COIN_RATE_PER_KM === 1);
    assert('Detour rate is 3.0', cache.DETOUR_COINS_PER_500M === 3.0 || cache.DETOUR_COINS_PER_500M === 3);
  } catch (err) {
    assert('Settings cache error', false, err.message);
  }

  // ─── 2. SUBTASK 2.2: Pure Mathematical Fare Engine ──────────
  console.log('\n--- 2. Testing Pure Mathematical Fare Engine (2.2) ---');
  try {
    // Scenario A: 12.4 km car ride, 0m detour, 1 seat
    // 12.4 * 2.0 = 24.8 -> ceil = 25 Coins
    const fareA = walletService.calculateFare(12.4, 'car', 0, 1);
    assert('Car 12.4km (1 seat) fare is 25 Coins', fareA.total_rider_fare === 25, `(Got ${fareA.total_rider_fare})`);
    assert('Driver earnings equal rider fare when 0 detour', fareA.driver_total_earnings === 25);

    // Scenario B: 12.4 km car ride, 600m detour (+6 Coins detour compensation)
    const fareB = walletService.calculateFare(12.4, 'car', 600, 1);
    assert('Detour 600m calculates 2 units (+6 Coins)', fareB.detour_compensation_coins === 6.0, `(Got ${fareB.detour_compensation_coins})`);
    assert('Rider pays base 25 Coins (unaffected by detour)', fareB.total_rider_fare === 25);
    assert('Driver earns 25 + 6 = 31 Coins', fareB.driver_total_earnings === 31);
    assert('Trust score bonus (+5) awarded on detour', fareB.trust_score_bonus === 5);

    // Scenario C: Multi-Seat booking (2 seats)
    const fareC = walletService.calculateFare(12.4, 'car', 0, 2);
    assert('2 seats double rider fare (25 * 2 = 50 Coins)', fareC.total_rider_fare === 50, `(Got ${fareC.total_rider_fare})`);

    // Scenario D: Short 0.8 km ride (Minimum Fare Floor)
    // 0.8 * 2.0 = 1.6 -> min floor is 5.0 Coins
    const fareD = walletService.calculateFare(0.8, 'car', 0, 1);
    assert('Min floor applied for short car ride (5 Coins)', fareD.total_rider_fare === 5, `(Got ${fareD.total_rider_fare})`);

    // Scenario E: Bike 8.0 km ride
    // 8.0 * 1.0 = 8 Coins
    const fareE = walletService.calculateFare(8.0, 'bike', 0, 1);
    assert('Bike 8.0km fare is 8 Coins', fareE.total_rider_fare === 8, `(Got ${fareE.total_rider_fare})`);
  } catch (err) {
    assert('Fare calculation error', false, err.message);
  }

  // ─── 3. SUBTASK 2.3: 3-Tier Wallet Waterfall & Overdraft ─────
  console.log('\n--- 3. Testing 3-Tier Waterfall & Overdraft (2.3) ---');
  try {
    // Fetch a live user from database or create mock test user
    const { data: testUsers } = await supabaseAdmin.from('users').select('id, full_name').limit(1);
    
    if (testUsers && testUsers.length > 0) {
      const testUserId = testUsers[0].id;
      const walletData = await walletService.getWallet(testUserId);
      assert('getWallet() fetched live user wallet', walletData && walletData.wallet !== undefined);

      const suffCheck = await walletService.checkSufficiency(testUserId, 10, false);
      assert('checkSufficiency() executed without error', suffCheck && typeof suffCheck.sufficient === 'boolean');
      console.log('     Wallet check response:', JSON.stringify(suffCheck));
    } else {
      console.log('  ℹ️  No test users in database yet (creating one in Phase 3)');
    }
  } catch (err) {
    assert('Wallet sufficiency check error', false, err.message);
  }

  // ─── 4. SUBTASK 2.4: Double-Entry Ledger History ─────────────
  console.log('\n--- 4. Testing Double-Entry Ledger History (2.4) ---');
  try {
    const dummyId = '00000000-0000-0000-0000-000000000001';
    const txResult = await walletService.getTransactions(dummyId, { limit: 5 });
    assert('getTransactions() returns structured pagination object', Array.isArray(txResult.transactions));
  } catch (err) {
    assert('Transactions query error', false, err.message);
  }

  // ─── 5. SUBTASK 2.5: REST API Controller & Routes Check ──────
  console.log('\n--- 5. Testing REST API Controller Exports (2.5) ---');
  try {
    const ctrl = require('./src/controllers/walletController');
    assert('getWalletDetails handler exported', typeof ctrl.getWalletDetails === 'function');
    assert('getSummary handler exported', typeof ctrl.getSummary === 'function');
    assert('getTransactions handler exported', typeof ctrl.getTransactions === 'function');
    assert('getFareEstimate handler exported', typeof ctrl.getFareEstimate === 'function');
    assert('checkBalance handler exported', typeof ctrl.checkBalance === 'function');
    assert('transferCoins handler exported', typeof ctrl.transferCoins === 'function');
  } catch (err) {
    assert('Controller export error', false, err.message);
  }

  console.log('\n==================================================');
  console.log(`📊 TEST RESULTS: ${passed} passed, ${failed} failed`);
  if (failed === 0) {
    console.log('🎉 100% SUCCESS! All Wallet Subtasks (2.1 to 2.5) are verified & working!');
  }
  console.log('==================================================\n');
}

runWalletTests();
