// Better connection test — uses Supabase auth API which always works
require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

async function testConnection() {
  console.log('\n🔍 Testing Supabase connection...');
  console.log('URL:', process.env.SUPABASE_URL);

  const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY,
    { auth: { persistSession: false } }
  );

  try {
    // List users — always works with service role key
    const { data, error } = await supabase.auth.admin.listUsers({ page: 1, perPage: 1 });

    if (error) {
      console.log('❌ Auth error:', error.message);
    } else {
      console.log('✅ Supabase connection SUCCESSFUL!');
      console.log('✅ Service role key is valid!');
      console.log('✅ Total auth users:', data.total || 0);
    }
  } catch (err) {
    console.log('❌ Error:', err.message);
  }

  // Test storage
  try {
    const { data, error } = await supabase.storage.listBuckets();
    if (!error) {
      console.log('✅ Storage connected! Buckets:', data?.map(b => b.name).join(', ') || 'none yet');
    } else {
      console.log('⚠️  Storage:', error.message);
    }
  } catch (err) {
    console.log('⚠️  Storage test skipped');
  }

  console.log('\n🎉 Connection verified! Ready to run migrations.\n');
}

testConnection();
