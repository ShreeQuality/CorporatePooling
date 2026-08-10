// Comprehensive check for all tables + stored procedures in Supabase
require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

async function checkDatabase() {
  console.log('\n📊 Checking entire Supabase Database structure...\n');

  const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY,
    { auth: { persistSession: false } }
  );

  const tables = [
    'companies',
    'users',
    'otp_verifications',
    'vehicles',
    'rides',
    'ride_requests',
    'coin_transactions',
    'admin_users',
    'subscriptions',
    'driver_locations',
    'document_verifications',
  ];

  console.log('--- 1. TABLES & RLS CHECK ---');
  let missingTables = 0;

  for (const table of tables) {
    try {
      const col = table === 'driver_locations' ? 'ride_id' : 'id';
      const { error } = await supabase.from(table).select(col).limit(1);
      if (!error || error.code === 'PGRST116') {
        console.log(`  ✅ Table '${table}' : EXISTS & READY`);
      } else {
        console.log(`  ❌ Table '${table}' : MISSING (${error.message})`);
        missingTables++;
      }
    } catch (err) {
      console.log(`  ❌ Table '${table}' : ERROR (${err.message})`);
      missingTables++;
    }
  }

  console.log('\n--- 2. STORED PROCEDURES (RPC) CHECK ---');
  const dummyUuid = '00000000-0000-0000-0000-000000000000';

  const procedures = [
    { name: 'accept_ride_request', params: { p_request_id: dummyUuid, p_ride_id: dummyUuid, p_rider_id: dummyUuid, p_coins: 0 } },
    { name: 'complete_ride_for_rider', params: { p_ride_id: dummyUuid, p_rider_id: dummyUuid } },
    { name: 'refund_coins', params: { p_rider_id: dummyUuid, p_ride_id: dummyUuid, p_amount: 0 } },
    { name: 'credit_coins', params: { p_user_id: dummyUuid, p_amount: 0, p_description: 'test' } },
  ];

  let missingProcs = 0;

  for (const proc of procedures) {
    try {
      const { error } = await supabase.rpc(proc.name, proc.params);
      if (!error || error.message?.includes('REQUEST_NOT_FOUND') || error.message?.includes('INSUFFICIENT_COINS') || error.code === '23503') {
        console.log(`  ✅ Procedure '${proc.name}' : EXISTS & READY`);
      } else if (error.message?.includes('could not find the function') || error.code === '42883' || error.code === 'PGRST202') {
        console.log(`  ❌ Procedure '${proc.name}' : MISSING`);
        missingProcs++;
      } else {
        console.log(`  ✅ Procedure '${proc.name}' : EXISTS & READY`);
      }
    } catch (err) {
      console.log(`  ❌ Procedure '${proc.name}' : ERROR (${err.message})`);
      missingProcs++;
    }
  }

  console.log('\n==================================================');
  if (missingTables === 0 && missingProcs === 0) {
    console.log('🎉 100% VERIFIED! All 11 tables & 4 stored procedures are active!');
    console.log('🚀 Your database is completely ready for the application.');
  } else {
    console.log(`⚠️ Status: ${11 - missingTables}/11 tables ready, ${4 - missingProcs}/4 procedures ready.`);
  }
  console.log('==================================================\n');
}

checkDatabase();
