// Verification script for all 27 production tables in Supabase
require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

async function verifyAllTables() {
  console.log('\n==================================================');
  console.log('🔍 LIVE SUPABASE AUDIT — 27 PRODUCTION TABLES');
  console.log('Project:', process.env.SUPABASE_URL);
  console.log('==================================================\n');

  const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY,
    { auth: { persistSession: false } }
  );

  const tables = [
    'system_settings',
    'app_remote_config',
    'companies',
    'buildings',
    'users',
    'wallets',
    'vehicles',
    'kyc_documents',
    'family_wallets',
    'family_wallet_members',
    'rides',
    'ride_requests',
    'search_alerts',
    'coin_transactions',
    'corporate_attendance',
    'corporate_invoices',
    'driver_locations',
    'chat_rooms',
    'chat_room_members',
    'chat_messages',
    'message_read_receipts',
    'ride_ratings',
    'telematics_violations',
    'emergency_sos_incidents',
    'admin_audit_logs',
    'company_domains',
    'notifications'
  ];

  let liveCount = 0;
  let missingCount = 0;

  for (const table of tables) {
    try {
      const { data, error } = await supabase.from(table).select('*').limit(1);
      if (!error || error.code === 'PGRST116') {
        liveCount++;
        console.log(`  ✅ [LIVE]     public.${table}`);
      } else {
        missingCount++;
        console.log(`  ❌ [MISSING]  public.${table}`);
      }
    } catch (err) {
      missingCount++;
      console.log(`  ❌ [ERROR]    public.${table} (${err.message})`);
    }
  }

  console.log('\n==================================================');
  console.log(`📊 AUDIT SUMMARY: ${liveCount}/27 tables live, ${missingCount}/27 missing`);
  if (liveCount === 27) {
    console.log('🎉 100% SUCCESS! All 27 production tables are deployed and active!');
  } else {
    console.log('⏳ Note: Ready for migration 014 execution in Supabase SQL Editor.');
  }
  console.log('==================================================\n');
}

verifyAllTables();
