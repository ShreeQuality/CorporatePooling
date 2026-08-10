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
