use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, Serialize, Deserialize, Clone, FromRow)]
pub struct MediaItem {
    pub id: i32,
    pub uploaded_by: Option<Uuid>,
    pub event_id: Option<i32>,
    pub media_type: String,
    pub title: String,
    pub description: String,
    pub file_url: String,
    pub thumbnail_url: String,
    pub file_size_bytes: i64,
    pub duration_secs: i32,
    pub mime_type: String,
    pub is_approved: bool,
    pub is_featured: bool,
    pub like_count: i32,
    pub view_count: i32,
    pub created_at: DateTime<Utc>,
}

/// Extended view with uploader name (JOIN).
#[derive(Debug, Serialize, Deserialize, Clone, FromRow)]
pub struct MediaItemView {
    pub id: i32,
    pub uploaded_by: Option<Uuid>,
    pub uploader_name: Option<String>,
    pub event_id: Option<i32>,
    pub event_title: Option<String>,
    pub media_type: String,
    pub title: String,
    pub description: String,
    pub file_url: String,
    pub thumbnail_url: String,
    pub file_size_bytes: i64,
    pub duration_secs: i32,
    pub mime_type: String,
    pub is_approved: bool,
    pub is_featured: bool,
    pub like_count: i32,
    pub view_count: i32,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, Deserialize, Clone, FromRow)]
pub struct MediaComment {
    pub id: i32,
    pub media_id: i32,
    pub guest_id: Option<Uuid>,
    pub guest_name: String,
    pub comment: String,
    pub created_at: DateTime<Utc>,
}

// ── Requests ──

#[derive(Debug, Deserialize)]
pub struct CreateMediaRequest {
    pub event_id: Option<i32>,
    pub media_type: String,
    pub title: Option<String>,
    pub description: Option<String>,
    pub file_url: String,
    pub thumbnail_url: Option<String>,
    pub file_size_bytes: Option<i64>,
    pub duration_secs: Option<i32>,
    pub mime_type: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct PresignUploadRequest {
    pub content_type: Option<String>,
    pub file_ext: String,
    pub prefix: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct PresignUploadResponse {
    pub success: bool,
    pub upload_url: String,
    pub public_url: String,
    pub key: String,
    pub expires_in_sec: i64,
}

#[derive(Debug, Deserialize)]
pub struct MediaQuery {
    pub event_id: Option<i32>,
    pub media_type: Option<String>,       // photo, video, audio
    pub page: Option<u32>,
    pub per_page: Option<u32>,
    pub featured_only: Option<bool>,
}

#[derive(Debug, Deserialize)]
pub struct NewMediaCommentRequest {
    pub comment: String,
}
