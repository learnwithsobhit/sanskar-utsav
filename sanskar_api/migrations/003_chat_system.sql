-- Sanskar Utsav — Chat System
-- Text messaging + audio/video call signaling

-- ═══════════════════════════════════════════════
-- CHAT ROOMS (1-on-1 or group)
-- ═══════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS chat_rooms (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_type       VARCHAR(20) NOT NULL DEFAULT 'direct', -- direct, group, event
    name            VARCHAR(255) DEFAULT '',                -- Group name (empty for direct)
    event_id        INT REFERENCES ceremony_events(id) ON DELETE SET NULL,
    created_by      UUID REFERENCES guests(id) ON DELETE SET NULL,
    avatar_url      TEXT DEFAULT '',
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ═══════════════════════════════════════════════
-- CHAT ROOM MEMBERS
-- ═══════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS chat_room_members (
    id          SERIAL PRIMARY KEY,
    room_id     UUID NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE,
    guest_id    UUID NOT NULL REFERENCES guests(id) ON DELETE CASCADE,
    role        VARCHAR(20) DEFAULT 'member', -- admin, member
    joined_at   TIMESTAMPTZ DEFAULT NOW(),
    last_read_at TIMESTAMPTZ DEFAULT NOW(),
    is_muted    BOOLEAN DEFAULT FALSE,
    UNIQUE(room_id, guest_id)
);
CREATE INDEX idx_chat_members_guest ON chat_room_members(guest_id);
CREATE INDEX idx_chat_members_room ON chat_room_members(room_id);

-- ═══════════════════════════════════════════════
-- CHAT MESSAGES
-- ═══════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS chat_messages (
    id              SERIAL PRIMARY KEY,
    room_id         UUID NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE,
    sender_id       UUID NOT NULL REFERENCES guests(id) ON DELETE CASCADE,
    message_type    VARCHAR(20) NOT NULL DEFAULT 'text', -- text, image, video, audio, file, system, call_started, call_ended
    content         TEXT NOT NULL DEFAULT '',
    media_url       TEXT DEFAULT '',
    thumbnail_url   TEXT DEFAULT '',
    reply_to_id     INT REFERENCES chat_messages(id) ON DELETE SET NULL,
    is_edited       BOOLEAN DEFAULT FALSE,
    is_deleted       BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_chat_messages_room ON chat_messages(room_id, created_at DESC);
CREATE INDEX idx_chat_messages_sender ON chat_messages(sender_id);

-- ═══════════════════════════════════════════════
-- MESSAGE READ RECEIPTS
-- ═══════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS chat_read_receipts (
    id          SERIAL PRIMARY KEY,
    message_id  INT NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE,
    guest_id    UUID NOT NULL REFERENCES guests(id) ON DELETE CASCADE,
    read_at     TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(message_id, guest_id)
);

-- ═══════════════════════════════════════════════
-- CALL LOGS (audio/video)
-- ═══════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS call_logs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id         UUID REFERENCES chat_rooms(id) ON DELETE SET NULL,
    caller_id       UUID NOT NULL REFERENCES guests(id) ON DELETE CASCADE,
    call_type       VARCHAR(10) NOT NULL DEFAULT 'audio', -- audio, video
    status          VARCHAR(20) DEFAULT 'initiated',       -- initiated, ringing, ongoing, ended, missed, declined
    started_at      TIMESTAMPTZ DEFAULT NOW(),
    answered_at     TIMESTAMPTZ,
    ended_at        TIMESTAMPTZ,
    duration_secs   INT DEFAULT 0,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_call_logs_room ON call_logs(room_id);
CREATE INDEX idx_call_logs_caller ON call_logs(caller_id);

-- ═══════════════════════════════════════════════
-- CALL PARTICIPANTS
-- ═══════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS call_participants (
    id          SERIAL PRIMARY KEY,
    call_id     UUID NOT NULL REFERENCES call_logs(id) ON DELETE CASCADE,
    guest_id    UUID NOT NULL REFERENCES guests(id) ON DELETE CASCADE,
    status      VARCHAR(20) DEFAULT 'invited', -- invited, joined, left, declined
    joined_at   TIMESTAMPTZ,
    left_at     TIMESTAMPTZ,
    UNIQUE(call_id, guest_id)
);

-- ═══════════════════════════════════════════════
-- DEFAULT GROUP CHAT: "Sanskar Utsav Family"
-- ═══════════════════════════════════════════════

INSERT INTO chat_rooms (id, room_type, name, created_by)
VALUES (
    '00000000-0000-0000-0000-000000000001',
    'group',
    '🕉️ Sanskar Utsav Family',
    NULL
) ON CONFLICT DO NOTHING;
