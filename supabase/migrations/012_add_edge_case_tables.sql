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
