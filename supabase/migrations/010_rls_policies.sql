-- ============================================================
-- Migration 010: Row-Level Security (RLS) Policies
-- Run AFTER creating all tables
-- ============================================================

-- ─── Enable RLS on all user-facing tables ───────────────────
ALTER TABLE users                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles               ENABLE ROW LEVEL SECURITY;
ALTER TABLE rides                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE ride_requests          ENABLE ROW LEVEL SECURITY;
ALTER TABLE coin_transactions      ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_locations       ENABLE ROW LEVEL SECURITY;
ALTER TABLE document_verifications ENABLE ROW LEVEL SECURITY;

-- ─── users: own profile only ────────────────────────────────
DROP POLICY IF EXISTS "users_own" ON users;
CREATE POLICY "users_own"
  ON users FOR ALL
  USING (id = auth.uid());

-- ─── vehicles: own vehicles only ────────────────────────────
DROP POLICY IF EXISTS "vehicles_own" ON vehicles;
CREATE POLICY "vehicles_own"
  ON vehicles FOR ALL
  USING (user_id = auth.uid());

-- ─── rides: anyone can READ posted/started rides (open marketplace) ──
DROP POLICY IF EXISTS "rides_read_open" ON rides;
CREATE POLICY "rides_read_open"
  ON rides FOR SELECT
  USING (ride_status IN ('posted', 'started') AND is_open_to_public = TRUE);

-- ─── rides: driver can manage own rides ─────────────────────
DROP POLICY IF EXISTS "rides_driver_own" ON rides;
CREATE POLICY "rides_driver_own"
  ON rides FOR ALL
  USING (driver_id = auth.uid());

-- ─── ride_requests: rider sees own, driver sees on their ride ──
DROP POLICY IF EXISTS "ride_requests_rider" ON ride_requests;
CREATE POLICY "ride_requests_rider"
  ON ride_requests FOR ALL
  USING (
    rider_id = auth.uid() OR
    ride_id IN (SELECT id FROM rides WHERE driver_id = auth.uid())
  );

-- ─── coin_transactions: own only ────────────────────────────
DROP POLICY IF EXISTS "coin_txn_own" ON coin_transactions;
CREATE POLICY "coin_txn_own"
  ON coin_transactions FOR SELECT
  USING (user_id = auth.uid());

-- ─── driver_locations: rider can read if they have accepted request ──
DROP POLICY IF EXISTS "driver_locations_read" ON driver_locations;
CREATE POLICY "driver_locations_read"
  ON driver_locations FOR SELECT
  USING (
    -- Driver can see own
    driver_id = auth.uid() OR
    -- Rider with accepted request for this ride
    ride_id IN (
      SELECT ride_id FROM ride_requests
      WHERE rider_id = auth.uid() AND status = 'accepted'
    )
  );

-- Driver can write own location
DROP POLICY IF EXISTS "driver_locations_write" ON driver_locations;
CREATE POLICY "driver_locations_write"
  ON driver_locations FOR ALL
  USING (driver_id = auth.uid());

-- ─── document_verifications: own only ───────────────────────
DROP POLICY IF EXISTS "doc_verif_own" ON document_verifications;
CREATE POLICY "doc_verif_own"
  ON document_verifications FOR SELECT
  USING (user_id = auth.uid());
