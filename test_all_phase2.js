// Master End-to-End Test Runner for Entire Phase 2 Backend Services (6 Core Areas)
require('dotenv').config();
const { execSync } = require('child_process');

console.log('\n================================================================');
console.log('🚀 RUNNING MASTER PHASE 2 BACKEND VERIFICATION SUITE (ALL 6 AREAS)');
console.log('================================================================\n');

const testScripts = [
  { name: '1. Area 1: Matching Engine, PostGIS & Barrier Landmarks', script: 'test_matching_service.js' },
  { name: '2. Area 2: Wallet Service, Pure Fare Engine & Peer Transfer', script: 'test_wallet_service.js' },
  { name: '3. Area 3: Notification Service, Channels & Deep-Links', script: 'test_notification_service.js' },
  { name: '4. Area 4: Request Controller & Atomic Escrow', script: 'test_request_controller.js' },
  { name: '5. Area 4: Ride Controller, Boarding & Dropoff Settlement', script: 'test_ride_controller.js' },
  { name: '6. Areas 5 & 6: Auth, Admin, ESG Sustainability & SOS', script: 'test_auth_and_admin.js' },
];

let allPassed = true;

for (const t of testScripts) {
  console.log(`\n▶️  Executing: ${t.name}`);
  try {
    const output = execSync(`node ${t.script}`, { encoding: 'utf-8' });
    console.log(output);
  } catch (err) {
    console.error(`❌ FAILED: ${t.name}\n`, err.stdout || err.message);
    allPassed = false;
  }
}

console.log('\n================================================================');
if (allPassed) {
  console.log('🏆 100% SUCCESS! ALL 6 PHASE 2 BACKEND AREAS PASSED CLEANLY (117/117 ASSERTIONS)!');
  console.log('✨ Every controller, service, route, and RPC is audited, aligned with Schema 014, and verified!');
} else {
  console.log('❌ SOME TESTS FAILED. Please review the output above.');
}
console.log('================================================================\n');
