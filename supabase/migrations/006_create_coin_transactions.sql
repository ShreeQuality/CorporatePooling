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
