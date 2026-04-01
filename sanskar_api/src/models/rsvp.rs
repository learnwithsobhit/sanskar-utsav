use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, Serialize, Deserialize, Clone, FromRow)]
pub struct RsvpResponse {
    pub id: i32,
    pub guest_id: Uuid,
    pub event_id: i32,
    pub status: String,
    pub guest_count: i32,
    pub notes: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// Joined view with event title for display.
#[derive(Debug, Serialize, Deserialize, Clone, FromRow)]
pub struct RsvpWithEvent {
    pub id: i32,
    pub guest_id: Uuid,
    pub event_id: i32,
    pub event_title: String,
    pub event_date: chrono::NaiveDate,
    pub status: String,
    pub guest_count: i32,
    pub notes: String,
    pub updated_at: DateTime<Utc>,
}

// ── Requests ──

#[derive(Debug, Deserialize)]
pub struct RsvpRequest {
    pub status: String,           // attending, not_attending, maybe
    pub guest_count: Option<i32>,
    pub notes: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct BulkRsvpRequest {
    pub responses: Vec<BulkRsvpItem>,
}

#[derive(Debug, Deserialize)]
pub struct BulkRsvpItem {
    pub event_id: i32,
    pub status: String,
    pub guest_count: Option<i32>,
}

/// Admin query for RSVP summaries.
#[derive(Debug, Serialize, Deserialize, Clone, FromRow)]
pub struct RsvpSummary {
    pub event_id: i32,
    pub event_title: String,
    pub attending: i64,
    pub not_attending: i64,
    pub maybe: i64,
    pub pending: i64,
    pub total_guests: i64,
}
