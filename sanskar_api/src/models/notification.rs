use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, Serialize, Deserialize, Clone, FromRow)]
pub struct Notification {
    pub id: i32,
    pub guest_id: Uuid,
    pub title: String,
    pub body: String,
    pub notification_type: String,
    pub reference_type: String,
    pub reference_id: i32,
    pub is_read: bool,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, Deserialize, Clone, FromRow)]
pub struct FcmToken {
    pub id: i32,
    pub guest_id: Uuid,
    pub token: String,
    pub device_type: String,
    pub created_at: DateTime<Utc>,
}

// ── Requests ──

#[derive(Debug, Deserialize)]
pub struct RegisterFcmTokenRequest {
    pub token: String,
    pub device_type: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct AdminSendNotificationRequest {
    pub title: String,
    pub body: String,
    pub notification_type: Option<String>,
    /// If empty / null → send to all guests.
    pub guest_ids: Option<Vec<Uuid>>,
}
