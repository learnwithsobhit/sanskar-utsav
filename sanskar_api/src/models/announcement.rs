use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, Serialize, Deserialize, Clone, FromRow)]
pub struct Announcement {
    pub id: i32,
    pub title: String,
    pub message: String,
    pub category: String,
    pub priority: i32,
    pub is_active: bool,
    pub target_day: Option<i32>,
    pub created_by: Option<Uuid>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct AdminCreateAnnouncementRequest {
    pub title: String,
    pub message: String,
    pub category: Option<String>,
    pub priority: Option<i32>,
    pub target_day: Option<i32>,
}

#[derive(Debug, Deserialize)]
pub struct AdminPatchAnnouncementRequest {
    pub title: Option<String>,
    pub message: Option<String>,
    pub category: Option<String>,
    pub priority: Option<i32>,
    pub is_active: Option<bool>,
    pub target_day: Option<i32>,
}
