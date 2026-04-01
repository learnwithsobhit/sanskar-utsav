use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

// ──────────────────────────────────────────────
// Database row types
// ──────────────────────────────────────────────

#[derive(Debug, Serialize, Deserialize, Clone, FromRow)]
pub struct Guest {
    pub id: Uuid,
    pub invite_code: String,
    pub name: String,
    pub phone: String,
    pub email: String,
    pub relation: String,
    pub family_side: String,
    pub guest_count: i32,
    pub avatar_url: String,
    pub is_admin: bool,
    pub status: String,
    pub rsvp_message: String,
    pub dietary_pref: String,
    pub city: String,
    pub accommodation_needed: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// Public-facing guest view (hides sensitive fields).
#[derive(Debug, Serialize, Clone)]
pub struct GuestPublicView {
    pub id: Uuid,
    pub name: String,
    pub relation: String,
    pub family_side: String,
    pub avatar_url: String,
    pub city: String,
    pub status: String,
}

impl From<Guest> for GuestPublicView {
    fn from(g: Guest) -> Self {
        Self {
            id: g.id,
            name: g.name,
            relation: g.relation,
            family_side: g.family_side,
            avatar_url: g.avatar_url,
            city: g.city,
            status: g.status,
        }
    }
}

#[derive(Debug, Serialize, Deserialize, Clone, FromRow)]
pub struct GuestSession {
    pub id: Uuid,
    pub guest_id: Uuid,
    pub token: String,
    pub expires_at: DateTime<Utc>,
    pub created_at: DateTime<Utc>,
}

// ──────────────────────────────────────────────
// Request / Response types
// ──────────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct LoginRequest {
    pub invite_code: String,
}

#[derive(Debug, Serialize)]
pub struct LoginResponse {
    pub success: bool,
    pub token: String,
    pub guest: Guest,
}

#[derive(Debug, Deserialize)]
pub struct UpdateProfileRequest {
    pub name: Option<String>,
    pub phone: Option<String>,
    pub email: Option<String>,
    pub dietary_pref: Option<String>,
    pub city: Option<String>,
    pub accommodation_needed: Option<bool>,
    pub avatar_url: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct AdminCreateGuestRequest {
    pub name: String,
    pub phone: Option<String>,
    pub email: Option<String>,
    pub relation: Option<String>,
    pub family_side: Option<String>,
    pub city: Option<String>,
    pub is_admin: Option<bool>,
}

#[derive(Debug, Deserialize)]
pub struct AdminUpdateGuestRequest {
    pub name: Option<String>,
    pub phone: Option<String>,
    pub email: Option<String>,
    pub relation: Option<String>,
    pub family_side: Option<String>,
    pub guest_count: Option<i32>,
    pub status: Option<String>,
    pub dietary_pref: Option<String>,
    pub city: Option<String>,
    pub accommodation_needed: Option<bool>,
    pub is_admin: Option<bool>,
}

#[derive(Debug, Deserialize)]
pub struct AdminBroadcastRequest {
    pub message: String,
    pub message_type: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct AdminEventGroupRequest {
    pub event_id: i32,
}
