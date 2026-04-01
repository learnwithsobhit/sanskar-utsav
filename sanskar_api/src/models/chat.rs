use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

// ─── Chat Room ───

#[derive(Debug, Serialize, Deserialize, Clone, FromRow)]
pub struct ChatRoom {
    pub id: Uuid,
    pub room_type: String,     // direct, group, event
    pub name: String,
    pub event_id: Option<i32>,
    pub created_by: Option<Uuid>,
    pub avatar_url: String,
    pub is_active: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, Deserialize, Clone, FromRow)]
pub struct ChatRoomMember {
    pub id: i32,
    pub room_id: Uuid,
    pub guest_id: Uuid,
    pub role: String,
    pub joined_at: DateTime<Utc>,
    pub last_read_at: DateTime<Utc>,
    pub is_muted: bool,
}

/// Room with last message preview for the chat list.
#[derive(Debug, Serialize, Clone)]
pub struct ChatRoomPreview {
    pub id: Uuid,
    pub room_type: String,
    pub name: String,
    pub avatar_url: String,
    pub last_message: Option<String>,
    pub last_message_at: Option<DateTime<Utc>>,
    pub last_sender_name: Option<String>,
    pub unread_count: i64,
}

// ─── Chat Message ───

#[derive(Debug, Serialize, Deserialize, Clone, FromRow)]
pub struct ChatMessage {
    pub id: i32,
    pub room_id: Uuid,
    pub sender_id: Uuid,
    pub message_type: String,  // text, image, video, audio, file, system
    pub content: String,
    pub media_url: String,
    pub thumbnail_url: String,
    pub reply_to_id: Option<i32>,
    pub is_edited: bool,
    pub is_deleted: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// Message with sender info (JOIN result).
#[derive(Debug, Serialize, Deserialize, Clone, FromRow)]
pub struct ChatMessageView {
    pub id: i32,
    pub room_id: Uuid,
    pub sender_id: Uuid,
    pub sender_name: String,
    pub sender_avatar: String,
    pub message_type: String,
    pub content: String,
    pub media_url: String,
    pub thumbnail_url: String,
    pub reply_to_id: Option<i32>,
    pub is_edited: bool,
    pub is_deleted: bool,
    pub created_at: DateTime<Utc>,
}

// ─── Call Log ───

#[derive(Debug, Serialize, Deserialize, Clone, FromRow)]
pub struct CallLog {
    pub id: Uuid,
    pub room_id: Option<Uuid>,
    pub caller_id: Uuid,
    pub call_type: String,     // audio, video
    pub status: String,        // initiated, ringing, ongoing, ended, missed, declined
    pub started_at: DateTime<Utc>,
    pub answered_at: Option<DateTime<Utc>>,
    pub ended_at: Option<DateTime<Utc>>,
    pub duration_secs: i32,
    pub created_at: DateTime<Utc>,
}

// ─── Request / Response types ───

#[derive(Debug, Deserialize)]
pub struct CreateDirectChatRequest {
    pub guest_id: Uuid,  // The other party
}

#[derive(Debug, Deserialize)]
pub struct CreateGroupChatRequest {
    pub name: String,
    pub member_ids: Vec<Uuid>,
}

#[derive(Debug, Deserialize)]
pub struct SendMessageRequest {
    pub message_type: Option<String>,  // defaults to "text"
    pub content: String,
    pub media_url: Option<String>,
    pub thumbnail_url: Option<String>,
    pub reply_to_id: Option<i32>,
}

#[derive(Debug, Deserialize)]
pub struct ChatMessagesQuery {
    pub before_id: Option<i32>,
    pub limit: Option<u32>,
}

#[derive(Debug, Deserialize)]
pub struct InitiateCallRequest {
    pub call_type: String,  // audio, video
    pub participant_ids: Vec<Uuid>,
}
