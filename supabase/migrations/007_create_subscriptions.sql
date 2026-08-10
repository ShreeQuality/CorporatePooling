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
