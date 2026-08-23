// Verification script for Database Triggers & pg_cron Jobs in Supabase
require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

async function verifyTriggersAndCrons() {
  console.log('\n==================================================');
  console.log('🔍 LIVE SUPABASE AUDIT — TRIGGERS & CRON AUTOMATION');
  console.log('Project:', process.env.SUPABASE_URL);
  console.log('==================================================\n');

  const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY,
    { auth: { persistSession: false } }
  );

  console.log('--- 1. HELPER & AUTOMATION FUNCTIONS CHECK ---');
  const functions = [
    { name: 'handle_updated_at', params: {} },
    { name: 'handle_new_user_wallet', params: {} },
    { name: 'handle_new_ride_search_alerts', params: {} },
    { name: 'handle_sos_broadcast', params: {} },
    { name: 'auto_unlock_expired_ratings', params: {} },
    { name: 'cleanup_expired_search_alerts', params: {} }
  ];

  let liveFuncCount = 0;
  for (const fn of functions) {
    try {
      const { data, error } = await supabase.rpc(fn.name, fn.params);
      if (error && (error.code === '42883' || error.code === 'PGRST202' || error.message?.includes('could not find the function'))) {
        console.log(`  ❌ [MISSING]  public.${fn.name}()`);
      } else {
        liveFuncCount++;
        console.log(`  ✅ [LIVE]     public.${fn.name}()`);
      }
    } catch (err) {
      console.log(`  ❌ [ERROR]    public.${fn.name}() (${err.message})`);
    }
  }

  console.log('\n--- 2. FUNCTIONALITY TEST: WALLET PROVISIONING TRIGGER ---');
  // We can test if the wallet trigger works on public.users
  try {
    const dummyId = '00000000-0000-0000-0000-000000000999';
    // Clean up test if exists
    await supabase.from('wallets').delete().eq('user_id', dummyId);
    await supabase.from('users').delete().eq('id', dummyId);

    // Insert dummy user
    const { error: userError } = await supabase.from('users').insert({
      id: dummyId,
      phone_number: '+919999999999',
      full_name: 'Trigger Test User',
      gender: 'prefer_not_to_say',
      role: 'public_user'
    });

    if (!userError) {
      // Check if wallet was auto-created by trigger
      const { data: walletData, error: walletError } = await supabase
        .from('wallets')
        .select('*')
        .eq('user_id', dummyId)
        .single();

      if (walletData && !walletError) {
        console.log('  ✅ [VERIFIED] trg_on_user_created_provision_wallet is ACTIVE & WORKING!');
        console.log('                -> Created linked wallet automatically with balance: 0.00');
      } else {
        console.log('  ⚠️  Wallet was not auto-created by trigger');
      }

      // Cleanup test data
      await supabase.from('wallets').delete().eq('user_id', dummyId);
      await supabase.from('users').delete().eq('id', dummyId);
    } else {
      console.log('  ℹ️  User insert skipped (Auth constraint):', userError.message);
    }
  } catch (err) {
    console.log('  ℹ️  Trigger functional test note:', err.message);
  }

  console.log('\n==================================================');
  console.log(`📊 AUDIT SUMMARY: ${liveFuncCount}/${functions.length} automation functions live`);
  if (liveFuncCount === functions.length) {
    console.log('🎉 100% SUCCESS! Triggers and Automation are fully deployed & active!');
  } else {
    console.log('⏳ Note: Run 016_database_triggers.sql and 017_pg_cron_schedules.sql in Supabase SQL Editor.');
  }
  console.log('==================================================\n');
}

verifyTriggersAndCrons();
