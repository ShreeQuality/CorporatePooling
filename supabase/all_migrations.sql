-- ============================================================
-- Corporate Pooling Application — Master Database Migration
-- Run this file in Supabase SQL Editor: https://supabase.com/dashboard/project/mluleqpqufjlldrdxpuy/sql/new
-- ============================================================

-- ------------------------------------------------------------
-- 001_create_companies.sql
-- ------------------------------------------------------------

-- ============================================================
-- Migration 001: companies
-- ============================================================

CREATE TABLE IF NOT EXISTS companies (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name                TEXT NOT NULL,
  email_domain        TEXT UNIQUE,           -- e.g. 'tcs.com' (nullable for future)
  subscription_status TEXT CHECK(subscription_status IN ('trial','active','expired')) DEFAULT 'trial',
  trial_started_at    TIMESTAMPTZ DEFAULT NOW(),
  trial_ends_at       TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '90 days'),
  plan                TEXT DEFAULT 'free_trial',
  max_employees       INTEGER DEFAULT 100,
  is_active           BOOLEAN DEFAULT TRUE,
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS companies_updated_at ON companies;
CREATE TRIGGER companies_updated_at
  BEFORE UPDATE ON companies
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();


-- ------------------------------------------------------------
-- 002_create_users.sql
-- ------------------------------------------------------------

-- ============================================================
-- Migration 002: users
-- ============================================================

CREATE TABLE IF NOT EXISTS users (
  id                    UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name             TEXT NOT NULL,
  email                 TEXT UNIQUE NOT NULL,
  phone                 TEXT,
  photo_url             TEXT,
  user_type             TEXT CHECK(user_type IN ('corporate','public')) NOT NULL DEFAULT 'public',
  company_id            UUID REFERENCES companies(id) ON DELETE SET NULL,
  is_email_verified     BOOLEAN DEFAULT FALSE,
  is_document_verified  BOOLEAN DEFAULT FALSE,  -- Aadhaar + photo approved (public users)
  is_driver_verified    BOOLEAN DEFAULT FALSE,  -- Driving licence approved
  aadhaar_url           TEXT,
  driving_licence_url   TEXT,
  coin_balance          INTEGER DEFAULT 0 CHECK(coin_balance >= 0),
  total_coins_earned    INTEGER DEFAULT 0,
  total_rides_given     INTEGER DEFAULT 0,
  total_rides_taken     INTEGER DEFAULT 0,
  karma_score           NUMERIC(3,2) DEFAULT 5.00 CHECK(karma_score BETWEEN 0 AND 5),
  is_active             BOOLEAN DEFAULT TRUE,
  created_at            TIMESTAMPTZ DEFAULT NOW(),
  updated_at            TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_company_id ON users(company_id);
CREATE INDEX IF NOT EXISTS idx_users_user_type ON users(user_type);

DROP TRIGGER IF EXISTS users_updated_at ON users;
CREATE TRIGGER users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ─── OTP Verifications ───────────────────────────────────────

CREATE TABLE IF NOT EXISTS otp_verifications (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email       TEXT NOT NULL,
  otp         TEXT NOT NULL,
  purpose     TEXT NOT NULL,   -- 'registration', 'login', 'reset'
  expires_at  TIMESTAMPTZ NOT NULL,
  used        BOOLEAN DEFAULT FALSE,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(email, purpose)
);


-- ------------------------------------------------------------
-- 003_create_vehicles.sql
-- ------------------------------------------------------------

-- ============================================================
-- Migration 003: vehicles
-- ============================================================

CREATE TABLE IF NOT EXISTS vehicles (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type                TEXT NOT NULL,    -- 'Bike','Scooter','Auto','Car','Sedan','SUV'
  registration_number TEXT NOT NULL,
  model               TEXT,
  color               TEXT,
  capacity            INTEGER NOT NULL DEFAULT 2,
  is_verified         BOOLEAN DEFAULT FALSE,
  created_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vehicles_user_id ON vehicles(user_id);


-- ------------------------------------------------------------
-- 004_create_rides.sql
-- ------------------------------------------------------------

-- ============================================================
-- Migration 004: rides
-- ============================================================

CREATE TABLE IF NOT EXISTS rides (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id               UUID NOT NULL REFERENCES users(id),
  vehicle_id              UUID REFERENCES vehicles(id),
  from_address            TEXT NOT NULL,
  from_lat                NUMERIC(10,7) NOT NULL,
  from_lng                NUMERIC(10,7) NOT NULL,
  to_address              TEXT NOT NULL,
  to_lat                  NUMERIC(10,7) NOT NULL,
  to_lng                  NUMERIC(10,7) NOT NULL,
  route_points            JSONB NOT NULL DEFAULT '[]',    -- [{lat, lng}, ...] from Google Directions
  total_seats             INTEGER NOT NULL CHECK(total_seats > 0),
  available_seats         INTEGER NOT NULL CHECK(available_seats >= 0),
  coin_per_seat           INTEGER NOT NULL CHECK(coin_per_seat >= 0),
  time_type               TEXT CHECK(time_type IN ('now','scheduled','recurring')) NOT NULL DEFAULT 'now',
  depart_time             TEXT,            -- '8:00 AM' string (for display)
  depart_timestamp        TIMESTAMPTZ,     -- exact departure datetime
  recurring_days          TEXT[],          -- ['mon','tue','wed','thu','fri']
  valid_until             TIMESTAMPTZ,     -- for recurring rides
  ride_status             TEXT CHECK(ride_status IN (
                            'posted','started','in_progress','waiting_otp',
                            'awaiting_rider_confirm','awaiting_driver_confirm',
                            'completed','cancelled'
                          )) DEFAULT 'posted',
  -- Live GPS (updated every 5s when ride is active)
  current_lat             NUMERIC(10,7),
  current_lng             NUMERIC(10,7),
  current_route_index     INTEGER DEFAULT 0,
  -- Stats
  distance_km             NUMERIC(8,2),
  estimated_duration_mins INTEGER,
  actual_duration_mins    INTEGER,
  -- Timestamps
  started_at              TIMESTAMPTZ,
  completed_at            TIMESTAMPTZ,
  is_open_to_public       BOOLEAN DEFAULT TRUE,
  created_at              TIMESTAMPTZ DEFAULT NOW(),
  updated_at              TIMESTAMPTZ DEFAULT NOW(),

  CONSTRAINT seats_valid CHECK(available_seats <= total_seats)
);

CREATE INDEX IF NOT EXISTS idx_rides_driver_id ON rides(driver_id);
CREATE INDEX IF NOT EXISTS idx_rides_status ON rides(ride_status);
CREATE INDEX IF NOT EXISTS idx_rides_depart_timestamp ON rides(depart_timestamp);
CREATE INDEX IF NOT EXISTS idx_rides_from_location ON rides(from_lat, from_lng);

DROP TRIGGER IF EXISTS rides_updated_at ON rides;
CREATE TRIGGER rides_updated_at
  BEFORE UPDATE ON rides
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();


-- ------------------------------------------------------------
-- 005_create_ride_requests.sql
-- ------------------------------------------------------------

-- ============================================================
-- Migration 005: ride_requests
-- ============================================================

CREATE TABLE IF NOT EXISTS ride_requests (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id                 UUID NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
  rider_id                UUID NOT NULL REFERENCES users(id),
  pickup_address          TEXT NOT NULL,
  pickup_lat              NUMERIC(10,7) NOT NULL,
  pickup_lng              NUMERIC(10,7) NOT NULL,
  drop_address            TEXT NOT NULL,
  drop_lat                NUMERIC(10,7) NOT NULL,
  drop_lng                NUMERIC(10,7) NOT NULL,
  pickup_route_index      INTEGER,         -- index in ride.route_points where pickup falls
  drop_route_index        INTEGER,
  pickup_distance_m       INTEGER,         -- meters from pickup to nearest route point
  status                  TEXT CHECK(status IN (
                            'pending','accepted','rejected','cancelled','completed'
                          )) DEFAULT 'pending',
  coins_locked            INTEGER DEFAULT 0 CHECK(coins_locked >= 0),
  otp                     TEXT NOT NULL,   -- 4-digit pickup OTP
  otp_verified            BOOLEAN DEFAULT FALSE,
  -- Mutual arrival confirmation (mirrors KarmaRide pattern)
  awaiting_confirm        BOOLEAN DEFAULT FALSE,   -- driver signaled arrival
  rider_marked_arrival    BOOLEAN DEFAULT FALSE,   -- rider signaled arrival
  driver_marked_arrival_at TIMESTAMPTZ,
  rider_marked_arrival_at  TIMESTAMPTZ,
  completed_at            TIMESTAMPTZ,
  created_at              TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(ride_id, rider_id)
);

CREATE INDEX IF NOT EXISTS idx_ride_requests_ride_id ON ride_requests(ride_id);
CREATE INDEX IF NOT EXISTS idx_ride_requests_rider_id ON ride_requests(rider_id);
CREATE INDEX IF NOT EXISTS idx_ride_requests_status ON ride_requests(status);


-- ------------------------------------------------------------
-- 006_create_coin_transactions.sql
-- ------------------------------------------------------------

-- ============================================================
-- Migration 006: coin_transactions + admin_users
-- ============================================================

CREATE TABLE IF NOT EXISTS coin_transactions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id),
  ride_id         UUID REFERENCES rides(id),
  type            TEXT CHECK(type IN ('earn','spend','refund','credit','debit')) NOT NULL,
  amount          INTEGER NOT NULL CHECK(amount > 0),
  balance_after   INTEGER NOT NULL,
  description     TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_coin_txn_user_id ON coin_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_coin_txn_ride_id ON coin_transactions(ride_id);
CREATE INDEX IF NOT EXISTS idx_coin_txn_created_at ON coin_transactions(created_at DESC);

-- ─── Admin Users ─────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS admin_users (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email       TEXT UNIQUE NOT NULL,
  role        TEXT CHECK(role IN ('super_admin','admin','support')) DEFAULT 'admin',
  created_at  TIMESTAMPTZ DEFAULT NOW()
);


-- ------------------------------------------------------------
-- 007_create_subscriptions.sql
-- ------------------------------------------------------------

-- ============================================================
-- Migration 007: subscriptions
-- ============================================================

CREATE TABLE IF NOT EXISTS subscriptions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id      UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE UNIQUE,
  plan            TEXT NOT NULL DEFAULT 'free_trial',
  status          TEXT CHECK(status IN ('active','expired','cancelled')) DEFAULT 'active',
  started_at      TIMESTAMPTZ DEFAULT NOW(),
  expires_at      TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '90 days'),
  max_users       INTEGER DEFAULT 100,
  payment_ref     TEXT,         -- Razorpay/Stripe payment reference
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_subscriptions_company_id ON subscriptions(company_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_expires_at ON subscriptions(expires_at);


-- ------------------------------------------------------------
-- 008_create_driver_locations.sql
-- ------------------------------------------------------------

-- ============================================================
-- Migration 008: driver_locations (Supabase Realtime)
-- Same pattern as KarmaRide Firebase RTDB /ride_locations/{rideId}
-- Flutter app subscribes via WebSocket — updates every 5 seconds
-- ============================================================

CREATE TABLE IF NOT EXISTS driver_locations (
  ride_id             UUID PRIMARY KEY REFERENCES rides(id) ON DELETE CASCADE,
  driver_id           UUID REFERENCES users(id),
  lat                 NUMERIC(10,7) NOT NULL,
  lng                 NUMERIC(10,7) NOT NULL,
  current_route_index INTEGER DEFAULT 0,
  route_distance_m    INTEGER DEFAULT 0,
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Supabase Realtime on this table
-- Run this in Supabase SQL Editor after creating the table:
ALTER PUBLICATION supabase_realtime ADD TABLE driver_locations;

-- Flutter SDK usage:
-- supabase.channel('driver-$rideId')
--   .onPostgresChanges(event: PostgresChangeEvent.update, table: 'driver_locations',
--     filter: PostgresChangeFilter(type: FilterType.eq, column: 'ride_id', value: rideId),
--     callback: (payload) { ... update map marker ... })
--   .subscribe();


-- ------------------------------------------------------------
-- 009_create_document_verifications.sql
-- ------------------------------------------------------------

-- ============================================================
-- Migration 009: document_verifications
-- ============================================================

CREATE TABLE IF NOT EXISTS document_verifications (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  doc_type          TEXT CHECK(doc_type IN ('aadhaar','driving_licence','photo')) NOT NULL,
  doc_url           TEXT NOT NULL,
  status            TEXT CHECK(status IN ('pending','approved','rejected')) DEFAULT 'pending',
  reviewed_by       UUID REFERENCES admin_users(id),
  reviewed_at       TIMESTAMPTZ,
  rejection_reason  TEXT,
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, doc_type)
);

CREATE INDEX IF NOT EXISTS idx_doc_verif_status ON document_verifications(status);
CREATE INDEX IF NOT EXISTS idx_doc_verif_user_id ON document_verifications(user_id);


-- ------------------------------------------------------------
-- 010_rls_policies.sql
-- ------------------------------------------------------------

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


-- ------------------------------------------------------------
-- 011_stored_procedures.sql
-- ------------------------------------------------------------

-- ============================================================
-- Migration 011: Stored Procedures (RPCs)
-- All atomic operations — no race conditions, no double-spend
-- ============================================================

-- ─── accept_ride_request ─────────────────────────────────────
-- Atomically: lock coins from rider + update request status + decrement seat

CREATE OR REPLACE FUNCTION accept_ride_request(
  p_request_id UUID,
  p_ride_id    UUID,
  p_rider_id   UUID,
  p_coins      INTEGER
) RETURNS JSON AS $$
DECLARE
  v_rider_balance INTEGER;
BEGIN
  -- Lock coins from rider
  UPDATE users
  SET coin_balance = coin_balance - p_coins
  WHERE id = p_rider_id AND coin_balance >= p_coins
  RETURNING coin_balance INTO v_rider_balance;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'INSUFFICIENT_COINS');
  END IF;

  -- Update request to accepted with locked coins
  UPDATE ride_requests
  SET status = 'accepted', coins_locked = p_coins
  WHERE id = p_request_id AND status = 'pending';

  IF NOT FOUND THEN
    -- Rollback coin deduction
    UPDATE users SET coin_balance = coin_balance + p_coins WHERE id = p_rider_id;
    RETURN json_build_object('success', false, 'error', 'REQUEST_NOT_PENDING');
  END IF;

  -- Decrement available_seats on ride
  UPDATE rides
  SET available_seats = available_seats - 1
  WHERE id = p_ride_id AND available_seats > 0;

  -- Log the lock as a 'debit' transaction
  INSERT INTO coin_transactions(user_id, ride_id, type, amount, balance_after, description)
  VALUES (p_rider_id, p_ride_id, 'debit', p_coins, v_rider_balance, 'Coins locked for ride');

  RETURN json_build_object('success', true, 'coins_locked', p_coins);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ─── complete_ride_for_rider ──────────────────────────────────
-- Atomically: deduct locked coins from rider → credit driver → log both

CREATE OR REPLACE FUNCTION complete_ride_for_rider(
  p_ride_id  UUID,
  p_rider_id UUID
) RETURNS JSON AS $$
DECLARE
  v_request        ride_requests%ROWTYPE;
  v_driver_id      UUID;
  v_driver_balance INTEGER;
  v_rider_balance  INTEGER;
BEGIN
  -- Get and lock the request row
  SELECT * INTO v_request
  FROM ride_requests
  WHERE ride_id = p_ride_id AND rider_id = p_rider_id AND status = 'accepted'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'REQUEST_NOT_FOUND');
  END IF;

  -- Idempotency: already completed?
  IF v_request.status = 'completed' THEN
    RETURN json_build_object('success', false, 'error', 'ALREADY_COMPLETED');
  END IF;

  -- Get driver
  SELECT driver_id INTO v_driver_id FROM rides WHERE id = p_ride_id;

  -- Credit driver (coins earned)
  UPDATE users
  SET coin_balance       = coin_balance + v_request.coins_locked,
      total_coins_earned = total_coins_earned + v_request.coins_locked,
      total_rides_given  = total_rides_given + 1
  WHERE id = v_driver_id
  RETURNING coin_balance INTO v_driver_balance;

  -- Update rider stats (coins already deducted at accept time)
  UPDATE users
  SET total_rides_taken = total_rides_taken + 1
  WHERE id = p_rider_id
  RETURNING coin_balance INTO v_rider_balance;

  -- Mark request completed
  UPDATE ride_requests
  SET status = 'completed', completed_at = NOW(), coins_locked = 0
  WHERE id = v_request.id;

  -- Restore available seat (in case another rider can join — not needed for completed but clean)
  -- UPDATE rides SET available_seats = available_seats + 1 WHERE id = p_ride_id;

  -- Log transactions
  INSERT INTO coin_transactions(user_id, ride_id, type, amount, balance_after, description)
  VALUES
    (p_rider_id,   p_ride_id, 'spend', v_request.coins_locked, v_rider_balance,  'Ride payment to driver'),
    (v_driver_id,  p_ride_id, 'earn',  v_request.coins_locked, v_driver_balance, 'Ride earnings from rider');

  RETURN json_build_object('success', true, 'coins_transferred', v_request.coins_locked);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ─── refund_coins ─────────────────────────────────────────────
-- Refund locked coins when driver cancels or ride is cancelled

CREATE OR REPLACE FUNCTION refund_coins(
  p_rider_id  UUID,
  p_ride_id   UUID,
  p_amount    INTEGER
) RETURNS VOID AS $$
DECLARE
  v_new_balance INTEGER;
BEGIN
  UPDATE users
  SET coin_balance = coin_balance + p_amount
  WHERE id = p_rider_id
  RETURNING coin_balance INTO v_new_balance;

  INSERT INTO coin_transactions(user_id, ride_id, type, amount, balance_after, description)
  VALUES (p_rider_id, p_ride_id, 'refund', p_amount, v_new_balance, 'Ride cancelled — coins refunded');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ─── credit_coins ─────────────────────────────────────────────
-- Admin credit coins to a user (bonus, compensation, etc.)

CREATE OR REPLACE FUNCTION credit_coins(
  p_user_id     UUID,
  p_amount      INTEGER,
  p_description TEXT DEFAULT 'Admin credit'
) RETURNS VOID AS $$
DECLARE
  v_new_balance INTEGER;
BEGIN
  UPDATE users
  SET coin_balance = coin_balance + p_amount,
      total_coins_earned = total_coins_earned + p_amount
  WHERE id = p_user_id
  RETURNING coin_balance INTO v_new_balance;

  INSERT INTO coin_transactions(user_id, type, amount, balance_after, description)
  VALUES (p_user_id, 'credit', p_amount, v_new_balance, p_description);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ------------------------------------------------------------
-- 012_add_edge_case_tables.sql
-- ------------------------------------------------------------

-- ============================================================
-- Migration 012: Edge Case & Supplemental Tables
-- Multi-domain companies, ratings/reviews, notifications, SOS alerts, coin packages
-- ============================================================

-- ─── 1. Company Domains (Multi-domain per company) ───────────
CREATE TABLE IF NOT EXISTS company_domains (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id  UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  domain      TEXT UNIQUE NOT NULL,    -- e.g. 'tcs.com', 'tcs.co.in'
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_company_domains_domain ON company_domains(domain);
CREATE INDEX IF NOT EXISTS idx_company_domains_company ON company_domains(company_id);

-- ─── 2. Ratings & Reviews ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS ratings_reviews (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id     UUID NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
  reviewer_id UUID NOT NULL REFERENCES users(id),
  reviewee_id UUID NOT NULL REFERENCES users(id),
  rating      INTEGER NOT NULL CHECK(rating BETWEEN 1 AND 5),
  comment     TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(ride_id, reviewer_id, reviewee_id)
);

CREATE INDEX IF NOT EXISTS idx_ratings_reviewee ON ratings_reviews(reviewee_id);

-- ─── 3. In-App Notifications ──────────────────────────────────
CREATE TABLE IF NOT EXISTS notifications (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title       TEXT NOT NULL,
  body        TEXT NOT NULL,
  type        TEXT NOT NULL,   -- 'ride_request', 'request_accepted', 'driver_arriving', 'coins_received', 'system'
  data        JSONB DEFAULT '{}',
  is_read     BOOLEAN DEFAULT FALSE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, is_read);

-- ─── 4. SOS Emergency Alerts ─────────────────────────────────
CREATE TABLE IF NOT EXISTS sos_alerts (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id     UUID REFERENCES rides(id),
  user_id     UUID NOT NULL REFERENCES users(id),
  lat         NUMERIC(10,7) NOT NULL,
  lng         NUMERIC(10,7) NOT NULL,
  status      TEXT CHECK(status IN ('active','resolved','false_alarm')) DEFAULT 'active',
  resolved_by UUID REFERENCES admin_users(id),
  resolved_at TIMESTAMPTZ,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sos_alerts_status ON sos_alerts(status);

-- ─── 5. Coin Packages (Purchase options) ─────────────────────
CREATE TABLE IF NOT EXISTS coin_packages (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title       TEXT NOT NULL,
  coins       INTEGER NOT NULL CHECK(coins > 0),
  price_inr   NUMERIC(10,2) NOT NULL CHECK(price_inr >= 0),
  is_active   BOOLEAN DEFAULT TRUE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Seed initial coin packages
INSERT INTO coin_packages (title, coins, price_inr) VALUES
  ('Starter Pack',  50,   100.00),
  ('Commuter Pack', 150,  250.00),
  ('Pro Pack',      350,  500.00),
  ('Ultra Pack',    800, 1000.00)
ON CONFLICT DO NOTHING;

-- ─── Enable RLS on new tables ─────────────────────────────────
ALTER TABLE company_domains    ENABLE ROW LEVEL SECURITY;
ALTER TABLE ratings_reviews    ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications      ENABLE ROW LEVEL SECURITY;
ALTER TABLE sos_alerts         ENABLE ROW LEVEL SECURITY;
ALTER TABLE coin_packages      ENABLE ROW LEVEL SECURITY;

-- ─── RLS Policies ─────────────────────────────────────────────
DROP POLICY IF EXISTS "company_domains_read" ON company_domains;
CREATE POLICY "company_domains_read" ON company_domains FOR SELECT USING (true);

DROP POLICY IF EXISTS "ratings_reviews_read" ON ratings_reviews;
CREATE POLICY "ratings_reviews_read" ON ratings_reviews FOR SELECT USING (true);

DROP POLICY IF EXISTS "ratings_reviews_insert" ON ratings_reviews;
CREATE POLICY "ratings_reviews_insert" ON ratings_reviews FOR INSERT WITH CHECK (reviewer_id = auth.uid());

DROP POLICY IF EXISTS "notifications_own" ON notifications;
CREATE POLICY "notifications_own" ON notifications FOR ALL USING (user_id = auth.uid());

DROP POLICY IF EXISTS "sos_alerts_own" ON sos_alerts;
CREATE POLICY "sos_alerts_own" ON sos_alerts FOR ALL USING (user_id = auth.uid());

DROP POLICY IF EXISTS "coin_packages_read" ON coin_packages;
CREATE POLICY "coin_packages_read" ON coin_packages FOR SELECT USING (is_active = true);


-- ─── Stored Procedure: Submit Rating & Update User Karma Score ──
CREATE OR REPLACE FUNCTION submit_rating(
  p_ride_id     UUID,
  p_reviewer_id UUID,
  p_reviewee_id UUID,
  p_rating      INTEGER,
  p_comment     TEXT DEFAULT NULL
) RETURNS JSON AS $$
DECLARE
  v_avg_rating NUMERIC(3,2);
BEGIN
  -- Insert rating
  INSERT INTO ratings_reviews(ride_id, reviewer_id, reviewee_id, rating, comment)
  VALUES (p_ride_id, p_reviewer_id, p_reviewee_id, p_rating, p_comment);

  -- Recompute reviewee karma_score
  SELECT ROUND(AVG(rating)::numeric, 2) INTO v_avg_rating
  FROM ratings_reviews
  WHERE reviewee_id = p_reviewee_id;

  UPDATE users
  SET karma_score = v_avg_rating
  WHERE id = p_reviewee_id;

  RETURN json_build_object('success', true, 'new_karma_score', v_avg_rating);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


