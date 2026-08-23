// Comprehensive Automated Test Suite for Notification Service (Step 5)
require('dotenv').config();
const notificationService = require('./src/services/notificationService');

async function runNotificationTests() {
  console.log('\n==================================================');
  console.log('🧪 RUNNING NOTIFICATION SERVICE TEST SUITE (STEP 5)');
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

  // ─── 1. SUBTASK 5.1: Zero-Crash Initialization Check ────────
  console.log('--- 1. Testing Zero-Crash Firebase Initialization ---');
  try {
    const isMock = notificationService.isMockMode();
    assert('Notification service initialized without crashing', typeof isMock === 'boolean');
    console.log(`     Active Mode: ${isMock ? 'Zero-Crash Development Mock Mode 🛡️' : 'Live Google FCM v1 Network Mode 🌐'}`);
  } catch (err) {
    assert('Init crash error', false, err.message);
  }

  // ─── 2. SUBTASK 5.2: Priority Channel Map Routing ───────────
  console.log('\n--- 2. Testing Priority Channel Routing (SRS §16.2) ---');
  try {
    const sosCh = notificationService.getChannel('sos_emergency');
    assert('SOS routes to sos_emergency channel', sosCh.channel === 'sos_emergency');
    assert('SOS has MAX priority and siren sound', sosCh.androidPriority === 'max' && sosCh.sound === 'siren.mp3');

    const rideCh = notificationService.getChannel('ride_request');
    assert('Ride request routes to ride_alerts channel', rideCh.channel === 'ride_alerts');
    assert('Ride request has HIGH priority and chime sound', rideCh.priority === 'high' && rideCh.sound === 'chime_high.mp3');

    const coinCh = notificationService.getChannel('coins_received');
    assert('Coins received routes to coin_alerts channel', coinCh.channel === 'coin_alerts');
    assert('Coins received has NORMAL priority and coin drop sound', coinCh.priority === 'normal' && coinCh.sound === 'coin_drop.mp3');
  } catch (err) {
    assert('Channel routing error', false, err.message);
  }

  // ─── 3. SUBTASK 5.3: Deep-Link Payload Generator ────────────
  console.log('\n--- 3. Testing Deep-Link Payload Generator (SRS §16.3) ---');
  try {
    const linkReq = notificationService.buildDeepLink('ride_request', { request_id: 'REQ-101' });
    assert('ride_request deep-link', linkReq === '/driver/requests/REQ-101', `(Got ${linkReq})`);

    const linkLive = notificationService.buildDeepLink('request_accepted', { ride_id: 'RIDE-202' });
    assert('request_accepted deep-link', linkLive === '/rider/live/RIDE-202', `(Got ${linkLive})`);

    const linkBoarding = notificationService.buildDeepLink('driver_arrived', { ride_id: 'RIDE-202' });
    assert('driver_arrived deep-link', linkBoarding === '/rider/boarding/RIDE-202', `(Got ${linkBoarding})`);

    const linkRating = notificationService.buildDeepLink('ride_completed', { ride_id: 'RIDE-202' });
    assert('ride_completed deep-link', linkRating === '/rating/RIDE-202', `(Got ${linkRating})`);

    const linkWallet = notificationService.buildDeepLink('coins_received');
    assert('coins_received deep-link', linkWallet === '/wallet', `(Got ${linkWallet})`);

    const linkSOS = notificationService.buildDeepLink('sos_emergency', { incident_id: 'INC-999' });
    assert('sos_emergency deep-link', linkSOS === '/admin/sos/INC-999', `(Got ${linkSOS})`);
  } catch (err) {
    assert('Deep-link generator error', false, err.message);
  }

  // ─── 4. SUBTASK 5.4: Single & Bulk Push Dispatch Tests ──────
  console.log('\n--- 4. Testing Push Dispatch Flow ---');
  try {
    const dummyUserId = '00000000-0000-0000-0000-000000000001';
    const singleResult = await notificationService.sendPushNotification(
      dummyUserId,
      'Test Ride Alert 🚗',
      'Rahul is arriving at Manyata Gate 2',
      'driver_arrived',
      { ride_id: 'RIDE-TEST-123' }
    );
    assert('sendPushNotification executed successfully', singleResult && singleResult.success === true);

    const bulkResult = await notificationService.sendBulkPushNotifications(
      [dummyUserId],
      'Monthly Grant Credited 🎁',
      '400 Karma Coins added to your wallet',
      'grant_airdrop'
    );
    assert('sendBulkPushNotifications executed successfully', bulkResult && bulkResult.total === 1);
  } catch (err) {
    assert('Push dispatch error', false, err.message);
  }

  console.log('\n==================================================');
  console.log(`📊 TEST RESULTS: ${passed} passed, ${failed} failed`);
  if (failed === 0) {
    console.log('🎉 100% SUCCESS! Notification Service (Step 5) is fully verified & working!');
  }
  console.log('==================================================\n');
}

runNotificationTests();
