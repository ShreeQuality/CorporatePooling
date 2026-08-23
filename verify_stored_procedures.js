// Verification script for all Stored Procedures (RPCs) in Supabase
require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

async function verifyAllProcedures() {
  console.log('\n==================================================');
  console.log('🔍 LIVE SUPABASE AUDIT — STORED PROCEDURES (RPCs)');
  console.log('Project:', process.env.SUPABASE_URL);
  console.log('==================================================\n');

  const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY,
    { auth: { persistSession: false } }
  );

  const dummyUuid1 = '00000000-0000-0000-0000-000000000001';
  const dummyUuid2 = '00000000-0000-0000-0000-000000000002';

  const procedures = [
    { name: 'accept_ride_request_atomic', params: { p_request_id: dummyUuid1, p_driver_id: dummyUuid2 } },
    { name: 'cancel_ride_request_atomic', params: { p_request_id: dummyUuid1, p_cancelled_by: dummyUuid2 } },
    { name: 'verify_boarding_atomic', params: { p_request_id: dummyUuid1, p_method: 'pin', p_pin_word: 'TEST' } },
    { name: 'complete_single_dropoff', params: { p_request_id: dummyUuid1, p_driver_id: dummyUuid2 } },
    { name: 'complete_ride', params: { p_ride_id: dummyUuid1, p_driver_id: dummyUuid2 } },
    { name: 'process_nightly_recurring_rides', params: {} },
    { name: 'distribute_monthly_corporate_grants', params: {} },
    { name: 'toggle_recurring_skip_date', params: { p_ride_id: dummyUuid1, p_user_id: dummyUuid2, p_date: '2026-08-19' } },
    { name: 'submit_ride_rating_and_trust_score', params: { p_ride_id: dummyUuid1, p_rater_id: dummyUuid1, p_ratee_id: dummyUuid2, p_stars: 5 } },
    { name: 'recharge_company_coin_pool', params: { p_company_id: dummyUuid1, p_admin_id: dummyUuid2, p_amount: 100 } },
    { name: 'reconcile_stuck_escrow', params: {} },
    { name: 'lock_wallets_for_ride', params: { p_driver_id: dummyUuid1, p_rider_id: dummyUuid2 } }
  ];

  let liveCount = 0;
  let missingCount = 0;

  for (const proc of procedures) {
    try {
      const { data, error } = await supabase.rpc(proc.name, proc.params);
      
      // If error is code 42883 or PGRST202, the function does NOT exist
      if (error && (error.code === '42883' || error.code === 'PGRST202' || error.message?.includes('could not find the function'))) {
        missingCount++;
        console.log(`  ❌ [MISSING]  public.${proc.name}()`);
      } else {
        liveCount++;
        console.log(`  ✅ [LIVE]     public.${proc.name}()`);
      }
    } catch (err) {
      missingCount++;
      console.log(`  ❌ [ERROR]    public.${proc.name}() (${err.message})`);
    }
  }

  console.log('\n==================================================');
  console.log(`📊 RPC AUDIT SUMMARY: ${liveCount}/${procedures.length} procedures live, ${missingCount}/${procedures.length} missing`);
  if (liveCount === procedures.length) {
    console.log('🎉 100% SUCCESS! All stored procedures are deployed and active!');
  } else {
    console.log('⏳ Note: Run 015_stored_procedures.sql in Supabase SQL Editor to deploy missing procedures.');
  }
  console.log('==================================================\n');
}

verifyAllProcedures();
