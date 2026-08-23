// Inspect pg_trigger table to see if triggers exist
require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

async function checkPgTriggers() {
  const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY,
    { auth: { persistSession: false } }
  );

  // We can query using RPC if a custom query function exists, or test trigger execution on a table
  // Let's test updated_at trigger on system_settings table!
  try {
    const { data: beforeData } = await supabase
      .from('system_settings')
      .select('updated_at')
      .eq('key', 'CAR_COIN_RATE_PER_KM')
      .single();

    console.log('Before update timestamp:', beforeData?.updated_at);

    // Wait 1 second
    await new Promise(r => setTimeout(r, 1100));

    // Update value to same value
    await supabase
      .from('system_settings')
      .update({ description: 'Karma Coins per km for Car/SUV rides' })
      .eq('key', 'CAR_COIN_RATE_PER_KM');

    const { data: afterData } = await supabase
      .from('system_settings')
      .select('updated_at')
      .eq('key', 'CAR_COIN_RATE_PER_KM')
      .single();

    console.log('After update timestamp:', afterData?.updated_at);

    if (new Date(afterData?.updated_at).getTime() > new Date(beforeData?.updated_at).getTime()) {
      console.log('✅ [LIVE & ACTIVE] updated_at TRIGGER IS WORKING on system_settings!');
    } else {
      console.log('❌ [NOT RUN YET] 016_database_triggers.sql has NOT been executed in SQL Editor yet.');
    }
  } catch (err) {
    console.log('Error testing trigger:', err.message);
  }
}

checkPgTriggers();
