-- Invite tokens, active phone uniqueness, admin audit log

ALTER TABLE guests ADD COLUMN IF NOT EXISTS invite_token_hash VARCHAR(128) NOT NULL DEFAULT '';

COMMENT ON COLUMN guests.invite_token_hash IS 'SHA-256 hex of opaque invite token; empty = legacy guest (code-only login).';

-- One non-revoked/suspended guest per phone (E.164) when phone is set
CREATE UNIQUE INDEX IF NOT EXISTS idx_guests_phone_unique_active
ON guests (phone)
WHERE btrim(phone) <> '' AND status NOT IN ('revoked', 'suspended');

CREATE TABLE IF NOT EXISTS admin_audit_log (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_guest_id     UUID REFERENCES guests(id) ON DELETE SET NULL,
    action             VARCHAR(64) NOT NULL,
    target_guest_id    UUID REFERENCES guests(id) ON DELETE SET NULL,
    meta               JSONB NOT NULL DEFAULT '{}',
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_audit_target ON admin_audit_log (target_guest_id);
CREATE INDEX IF NOT EXISTS idx_admin_audit_created ON admin_audit_log (created_at DESC);
