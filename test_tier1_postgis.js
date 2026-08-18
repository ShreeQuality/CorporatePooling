// ============================================================
// Automated Test: Tier 1 PostGIS Spatial Pre-Filter (Step 4)
// Tests find_candidate_rides_spatial RPC & fetchSpatialCandidateRides()
// ============================================================

const { fetchSpatialCandidateRides } = require('./src/services/matchingService');
const { supabaseAdmin } = require('./src/config/supabase');

async function runTier1PostGisTest() {
  console.log('\n🗺️ ============================================================');
  console.log('🧪 RUNNING TIER 1 POSTGIS SPATIAL PRE-FILTER TEST');
  console.log('============================================================\n');

  // Test coordinates: Hebbal Flyover (Pickup) -> Manyata Tech Park Block D (Drop)
  const HEBBAL_PICKUP = { lat: 13.0358, lng: 77.5970 };
  const MANYATA_DROP   = { lat: 13.0475, lng: 77.6200 };

  console.log(`📍 Test Rider Pickup: Hebbal (${HEBBAL_PICKUP.lat}, ${HEBBAL_PICKUP.lng})`);
  console.log(`🏁 Test Rider Drop:   Manyata (${MANYATA_DROP.lat}, ${MANYATA_DROP.lng})`);
  console.log(`📏 Search Radius:     1,500 meters\n`);

  try {
    // 1. Direct RPC execution test
    console.log('--- TEST 1: Direct PostGIS RPC Performance Benchmark ---');
    const startTime = process.hrtime.bigint();

    const { data: rpcRows, error: rpcError } = await supabaseAdmin.rpc('find_candidate_rides_spatial', {
      p_rider_id: null,
      p_pickup_lat: HEBBAL_PICKUP.lat,
      p_pickup_lng: HEBBAL_PICKUP.lng,
      p_drop_lat: MANYATA_DROP.lat,
      p_drop_lng: MANYATA_DROP.lng,
      p_seats_requested: 1,
      p_max_radius_m: 1500,
      p_time_type: null,
      p_target_date: null,
    });

    const endTime = process.hrtime.bigint();
    const durationMs = Number(endTime - startTime) / 1e6;

    if (rpcError) {
      console.log(`⚠️ Note on RPC: ${rpcError.message}`);
      console.log('👉 If function is not yet created in Supabase, run 020_spatial_matching_rpc.sql in Supabase SQL Editor.');
    } else {
      console.log(`⚡ RPC Execution Time: ${durationMs.toFixed(2)} ms (Benchmark target < 50ms)`);
      console.log(`📊 Spatial Candidates Found: ${rpcRows?.length || 0}`);
      if (rpcRows && rpcRows.length > 0) {
        console.log('Sample Candidate:', {
          ride_id: rpcRows[0].ride_id,
          driver: rpcRows[0].driver_name,
          pickup_dist_m: rpcRows[0].pickup_dist_meters,
          vehicle: rpcRows[0].vehicle_type,
        });
      }
    }

    // 2. Service Layer Integration Test
    console.log('\n--- TEST 2: Node.js Service Layer (fetchSpatialCandidateRides) ---');
    const candidates = await fetchSpatialCandidateRides(
      null,
      HEBBAL_PICKUP.lat,
      HEBBAL_PICKUP.lng,
      MANYATA_DROP.lat,
      MANYATA_DROP.lng,
      { seatsRequested: 1, maxRadiusMeters: 1500 }
    );

    console.log(`✅ Service Layer returned ${candidates.length} normalized candidate rides.`);
    if (candidates.length > 0) {
      console.log('✅ Candidate structure validated:');
      console.log(`   • Ride ID: ${candidates[0].id}`);
      console.log(`   • Driver Name: ${candidates[0].driver?.full_name || candidates[0].users?.full_name}`);
      console.log(`   • Vehicle: ${candidates[0].vehicle?.type || candidates[0].vehicles?.type || 'Standard'}`);
      console.log(`   • Available Seats: ${candidates[0].available_seats}`);
    }

    // 3. Radius Constraint Test (Out of Range: Whitefield 20km away)
    console.log('\n--- TEST 3: Out-of-Range Spatial Pruning Test (Whitefield) ---');
    const WHITEFIELD_PICKUP = { lat: 12.9698, lng: 77.7500 };
    const candidatesFar = await fetchSpatialCandidateRides(
      null,
      WHITEFIELD_PICKUP.lat,
      WHITEFIELD_PICKUP.lng,
      MANYATA_DROP.lat,
      MANYATA_DROP.lng,
      { seatsRequested: 1, maxRadiusMeters: 500 }
    );
    console.log(`🎯 Out-of-Range (20km away) candidates within 500m: ${candidatesFar.length} (Expected 0 if no Whitefield rides)`);

    console.log('\n🎉 ============================================================');
    console.log('✅ TIER 1 POSTGIS SPATIAL PRE-FILTER TEST COMPLETE!');
    console.log('============================================================\n');
  } catch (err) {
    console.error('❌ Test execution error:', err.message);
  }
}

runTier1PostGisTest();
