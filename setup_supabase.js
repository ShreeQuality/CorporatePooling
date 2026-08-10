// Setup storage bucket and combine SQL migrations
require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');

async function setup() {
  console.log('\n⚙️  Running Supabase setup...\n');

  const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY,
    { auth: { persistSession: false } }
  );

  // 1. Create Storage Bucket
  const bucketName = process.env.STORAGE_BUCKET || 'documents';
  try {
    const { data: buckets } = await supabase.storage.listBuckets();
    const exists = buckets?.some(b => b.name === bucketName);

    if (!exists) {
      const { data, error } = await supabase.storage.createBucket(bucketName, {
        public: true,
        fileSizeLimit: 5242880, // 5MB
      });
      if (error) {
        console.log(`⚠️ Could not create storage bucket '${bucketName}':`, error.message);
      } else {
        console.log(`✅ Storage bucket '${bucketName}' created successfully!`);
      }
    } else {
      console.log(`✅ Storage bucket '${bucketName}' already exists.`);
    }
  } catch (err) {
    console.log('⚠️ Storage bucket setup error:', err.message);
  }

  // 2. Combine all SQL migrations into a single file
  const migrationsDir = path.join(__dirname, 'supabase', 'migrations');
  const outputFile = path.join(__dirname, 'supabase', 'all_migrations.sql');

  const files = [
    '001_create_companies.sql',
    '002_create_users.sql',
    '003_create_vehicles.sql',
    '004_create_rides.sql',
    '005_create_ride_requests.sql',
    '006_create_coin_transactions.sql',
    '007_create_subscriptions.sql',
    '008_create_driver_locations.sql',
    '009_create_document_verifications.sql',
    '010_rls_policies.sql',
    '011_stored_procedures.sql',
    '012_add_edge_case_tables.sql',
  ];

  let combinedSql = `-- ============================================================\n`;
  combinedSql += `-- Corporate Pooling Application — Master Database Migration\n`;
  combinedSql += `-- Run this file in Supabase SQL Editor: https://supabase.com/dashboard/project/mluleqpqufjlldrdxpuy/sql/new\n`;
  combinedSql += `-- ============================================================\n\n`;

  for (const file of files) {
    const filePath = path.join(migrationsDir, file);
    if (fs.existsSync(filePath)) {
      const content = fs.readFileSync(filePath, 'utf8');
      combinedSql += `-- ------------------------------------------------------------\n`;
      combinedSql += `-- ${file}\n`;
      combinedSql += `-- ------------------------------------------------------------\n\n`;
      combinedSql += content + '\n\n';
    }
  }

  fs.writeFileSync(outputFile, combinedSql, 'utf8');
  console.log(`\n📄 Combined master migration file generated:`);
  console.log(`   ${outputFile}\n`);
}

setup();
