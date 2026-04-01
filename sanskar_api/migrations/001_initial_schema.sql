-- Sanskar Utsav — Initial Schema
-- Yogyopaveet Ceremony Event Management Platform

-- ═══════════════════════════════════════════════
-- GUESTS & AUTHENTICATION
-- ═══════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS guests (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invite_code          VARCHAR(20) UNIQUE NOT NULL,
    name                 VARCHAR(255) NOT NULL,
    phone                VARCHAR(20) DEFAULT '',
    email                VARCHAR(255) DEFAULT '',
    relation             VARCHAR(100) DEFAULT '',
    family_side          VARCHAR(20) DEFAULT 'both',
    guest_count          INT DEFAULT 1,
    avatar_url           TEXT DEFAULT '',
    is_admin             BOOLEAN DEFAULT FALSE,
    status               VARCHAR(20) DEFAULT 'invited',
    rsvp_message         TEXT DEFAULT '',
    dietary_pref         VARCHAR(50) DEFAULT 'veg',
    city                 VARCHAR(100) DEFAULT '',
    accommodation_needed BOOLEAN DEFAULT FALSE,
    created_at           TIMESTAMPTZ DEFAULT NOW(),
    updated_at           TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS guest_sessions (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    guest_id    UUID NOT NULL REFERENCES guests(id) ON DELETE CASCADE,
    token       VARCHAR(128) UNIQUE NOT NULL,
    expires_at  TIMESTAMPTZ NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_guest_sessions_token ON guest_sessions(token);
CREATE INDEX idx_guest_sessions_guest ON guest_sessions(guest_id);

-- ═══════════════════════════════════════════════
-- CEREMONY EVENTS (4-5 day program schedule)
-- ═══════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS ceremony_events (
    id           SERIAL PRIMARY KEY,
    day_number   INT NOT NULL,
    title        VARCHAR(255) NOT NULL,
    hindi_title  VARCHAR(255) DEFAULT '',
    description  TEXT DEFAULT '',
    event_date   DATE NOT NULL,
    start_time   TIME,
    end_time     TIME,
    venue        VARCHAR(255) DEFAULT '',
    venue_map_url TEXT DEFAULT '',
    dress_code   VARCHAR(100) DEFAULT '',
    category     VARCHAR(50) DEFAULT 'ritual',
    banner_url   TEXT DEFAULT '',
    icon_emoji   VARCHAR(10) DEFAULT '🕉️',
    sort_order   INT DEFAULT 0,
    is_active    BOOLEAN DEFAULT TRUE,
    created_at   TIMESTAMPTZ DEFAULT NOW(),
    updated_at   TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_ceremony_events_day ON ceremony_events(day_number);
CREATE INDEX idx_ceremony_events_date ON ceremony_events(event_date);

-- ═══════════════════════════════════════════════
-- RSVP TRACKING
-- ═══════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS rsvp_responses (
    id          SERIAL PRIMARY KEY,
    guest_id    UUID NOT NULL REFERENCES guests(id) ON DELETE CASCADE,
    event_id    INT NOT NULL REFERENCES ceremony_events(id) ON DELETE CASCADE,
    status      VARCHAR(20) DEFAULT 'pending',
    guest_count INT DEFAULT 1,
    notes       TEXT DEFAULT '',
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(guest_id, event_id)
);
CREATE INDEX idx_rsvp_guest ON rsvp_responses(guest_id);
CREATE INDEX idx_rsvp_event ON rsvp_responses(event_id);

-- ═══════════════════════════════════════════════
-- MEDIA SHARING (Photos, Videos, Audio)
-- ═══════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS media_items (
    id              SERIAL PRIMARY KEY,
    uploaded_by     UUID REFERENCES guests(id) ON DELETE SET NULL,
    event_id        INT REFERENCES ceremony_events(id) ON DELETE SET NULL,
    media_type      VARCHAR(10) NOT NULL,
    title           VARCHAR(255) DEFAULT '',
    description     TEXT DEFAULT '',
    file_url        TEXT NOT NULL,
    thumbnail_url   TEXT DEFAULT '',
    file_size_bytes BIGINT DEFAULT 0,
    duration_secs   INT DEFAULT 0,
    mime_type       VARCHAR(50) DEFAULT '',
    is_approved     BOOLEAN DEFAULT TRUE,
    is_featured     BOOLEAN DEFAULT FALSE,
    like_count      INT DEFAULT 0,
    view_count      INT DEFAULT 0,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_media_event ON media_items(event_id);
CREATE INDEX idx_media_type ON media_items(media_type);
CREATE INDEX idx_media_uploader ON media_items(uploaded_by);

CREATE TABLE IF NOT EXISTS media_likes (
    id         SERIAL PRIMARY KEY,
    media_id   INT NOT NULL REFERENCES media_items(id) ON DELETE CASCADE,
    guest_id   UUID NOT NULL REFERENCES guests(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(media_id, guest_id)
);

CREATE TABLE IF NOT EXISTS media_comments (
    id         SERIAL PRIMARY KEY,
    media_id   INT NOT NULL REFERENCES media_items(id) ON DELETE CASCADE,
    guest_id   UUID REFERENCES guests(id) ON DELETE SET NULL,
    guest_name VARCHAR(255) NOT NULL,
    comment    TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_media_comments_media ON media_comments(media_id);

-- ═══════════════════════════════════════════════
-- ANNOUNCEMENTS
-- ═══════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS announcements (
    id          SERIAL PRIMARY KEY,
    title       VARCHAR(255) NOT NULL,
    message     TEXT NOT NULL,
    category    VARCHAR(30) DEFAULT 'general',
    priority    INT DEFAULT 0,
    is_active   BOOLEAN DEFAULT TRUE,
    target_day  INT,
    created_by  UUID REFERENCES guests(id),
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_announcements_active ON announcements(is_active);

-- ═══════════════════════════════════════════════
-- NOTIFICATIONS
-- ═══════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS notifications (
    id                SERIAL PRIMARY KEY,
    guest_id          UUID NOT NULL REFERENCES guests(id) ON DELETE CASCADE,
    title             VARCHAR(255) NOT NULL,
    body              TEXT NOT NULL,
    notification_type VARCHAR(30) NOT NULL,
    reference_type    VARCHAR(30) DEFAULT '',
    reference_id      INT DEFAULT 0,
    is_read           BOOLEAN DEFAULT FALSE,
    created_at        TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_notifications_guest ON notifications(guest_id);
CREATE INDEX idx_notifications_unread ON notifications(guest_id, is_read);

CREATE TABLE IF NOT EXISTS fcm_tokens (
    id          SERIAL PRIMARY KEY,
    guest_id    UUID NOT NULL REFERENCES guests(id) ON DELETE CASCADE,
    token       TEXT NOT NULL,
    device_type VARCHAR(20) DEFAULT '',
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(guest_id, token)
);

-- ═══════════════════════════════════════════════
-- BLESSINGS / WISHES WALL
-- ═══════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS blessings (
    id          SERIAL PRIMARY KEY,
    guest_id    UUID REFERENCES guests(id) ON DELETE SET NULL,
    guest_name  VARCHAR(255) NOT NULL,
    message     TEXT NOT NULL,
    audio_url   TEXT DEFAULT '',
    is_featured BOOLEAN DEFAULT FALSE,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ═══════════════════════════════════════════════
-- ADMIN OTP (reuse pattern from Gopal Mandir)
-- ═══════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS admin_otps (
    id         SERIAL PRIMARY KEY,
    phone      VARCHAR(20) NOT NULL,
    otp_hash   VARCHAR(128) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    used       BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_admin_otps_phone ON admin_otps(phone);
