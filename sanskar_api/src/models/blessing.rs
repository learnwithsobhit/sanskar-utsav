use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, Serialize, Deserialize, Clone, FromRow)]
pub struct Blessing {
    pub id: i32,
    pub guest_id: Option<Uuid>,
    pub guest_name: String,
    pub message: String,
    pub audio_url: String,
    pub is_featured: bool,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct CreateBlessingRequest {
    pub message: String,
    pub audio_url: Option<String>,
}
