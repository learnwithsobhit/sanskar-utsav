use chrono::{DateTime, NaiveDate, NaiveTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;

#[derive(Debug, Serialize, Deserialize, Clone, FromRow)]
pub struct CeremonyEvent {
    pub id: i32,
    pub day_number: i32,
    pub title: String,
    pub hindi_title: String,
    pub description: String,
    pub event_date: NaiveDate,
    pub start_time: Option<NaiveTime>,
    pub end_time: Option<NaiveTime>,
    pub venue: String,
    pub venue_map_url: String,
    pub dress_code: String,
    pub category: String,
    pub banner_url: String,
    pub icon_emoji: String,
    pub sort_order: i32,
    pub is_active: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct AdminCreateEventRequest {
    pub day_number: i32,
    pub title: String,
    pub hindi_title: Option<String>,
    pub description: Option<String>,
    pub event_date: String, // "YYYY-MM-DD"
    pub start_time: Option<String>, // "HH:MM"
    pub end_time: Option<String>,
    pub venue: Option<String>,
    pub venue_map_url: Option<String>,
    pub dress_code: Option<String>,
    pub category: Option<String>,
    pub banner_url: Option<String>,
    pub icon_emoji: Option<String>,
    pub sort_order: Option<i32>,
}

#[derive(Debug, Deserialize)]
pub struct AdminPatchEventRequest {
    pub day_number: Option<i32>,
    pub title: Option<String>,
    pub hindi_title: Option<String>,
    pub description: Option<String>,
    pub event_date: Option<String>,
    pub start_time: Option<String>,
    pub end_time: Option<String>,
    pub venue: Option<String>,
    pub venue_map_url: Option<String>,
    pub dress_code: Option<String>,
    pub category: Option<String>,
    pub banner_url: Option<String>,
    pub icon_emoji: Option<String>,
    pub sort_order: Option<i32>,
    pub is_active: Option<bool>,
}

/// Query params for filtering events.
#[derive(Debug, Deserialize)]
pub struct EventQuery {
    pub day: Option<i32>,
    pub category: Option<String>,
    pub date: Option<String>,
}
