use actix_web::{get, web, HttpResponse};
use sqlx::PgPool;

use crate::cache::RedisCache;
use crate::models::event::{CeremonyEvent, EventQuery};

/// GET /api/events — list all ceremony events (with optional filters)
#[get("/api/events")]
pub async fn list_events(
    pool: web::Data<PgPool>,
    cache: web::Data<RedisCache>,
    query: web::Query<EventQuery>,
) -> HttpResponse {
    // Try cache first (only for unfiltered full list)
    if query.day.is_none() && query.category.is_none() && query.date.is_none() {
        if let Some(cached) = cache.get("events:all").await {
            if let Ok(events) = serde_json::from_str::<Vec<CeremonyEvent>>(&cached) {
                return HttpResponse::Ok().json(serde_json::json!({
                    "success": true,
                    "data": events,
                    "cached": true,
                }));
            }
        }
    }

    let mut sql = String::from(
        "SELECT * FROM ceremony_events WHERE is_active = TRUE"
    );
    let mut conditions = Vec::new();

    if let Some(day) = query.day {
        conditions.push(format!(" AND day_number = {}", day));
    }
    if let Some(ref cat) = query.category {
        conditions.push(format!(" AND category = '{}'", cat.replace('\'', "''")));
    }
    if let Some(ref date) = query.date {
        conditions.push(format!(" AND event_date = '{}'", date.replace('\'', "''")));
    }

    for c in &conditions {
        sql.push_str(c);
    }
    sql.push_str(" ORDER BY day_number, sort_order, start_time");

    let events = sqlx::query_as::<_, CeremonyEvent>(&sql)
        .fetch_all(pool.get_ref())
        .await;

    match events {
        Ok(events) => {
            // Cache the full list
            if conditions.is_empty() {
                if let Ok(json) = serde_json::to_string(&events) {
                    let _ = cache.set("events:all", &json, std::time::Duration::from_secs(300)).await;
                }
            }
            HttpResponse::Ok().json(serde_json::json!({
                "success": true,
                "data": events,
            }))
        }
        Err(e) => {
            tracing::error!("Failed to fetch events: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false,
                "error": "Failed to load events",
            }))
        }
    }
}

/// GET /api/events/{id} — get single event detail
#[get("/api/events/{id}")]
pub async fn get_event(
    pool: web::Data<PgPool>,
    path: web::Path<i32>,
) -> HttpResponse {
    let event_id = path.into_inner();

    match sqlx::query_as::<_, CeremonyEvent>(
        "SELECT * FROM ceremony_events WHERE id = $1 AND is_active = TRUE"
    )
    .bind(event_id)
    .fetch_optional(pool.get_ref())
    .await
    {
        Ok(Some(event)) => HttpResponse::Ok().json(serde_json::json!({
            "success": true,
            "data": event,
        })),
        Ok(None) => HttpResponse::NotFound().json(serde_json::json!({
            "success": false,
            "error": "Event not found",
        })),
        Err(e) => {
            tracing::error!("Failed to fetch event {event_id}: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false,
                "error": "Failed to load event",
            }))
        }
    }
}

/// GET /api/events/day/{day_number} — events for a specific day
#[get("/api/events/day/{day_number}")]
pub async fn events_by_day(
    pool: web::Data<PgPool>,
    path: web::Path<i32>,
) -> HttpResponse {
    let day = path.into_inner();

    match sqlx::query_as::<_, CeremonyEvent>(
        "SELECT * FROM ceremony_events WHERE day_number = $1 AND is_active = TRUE ORDER BY sort_order, start_time"
    )
    .bind(day)
    .fetch_all(pool.get_ref())
    .await
    {
        Ok(events) => HttpResponse::Ok().json(serde_json::json!({
            "success": true,
            "day": day,
            "data": events,
        })),
        Err(e) => {
            tracing::error!("Failed to fetch events for day {day}: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false,
                "error": "Failed to load events",
            }))
        }
    }
}

/// GET /api/events/today — today's events
#[get("/api/events/today")]
pub async fn events_today(pool: web::Data<PgPool>) -> HttpResponse {
    let today = chrono::Utc::now().date_naive();

    match sqlx::query_as::<_, CeremonyEvent>(
        "SELECT * FROM ceremony_events WHERE event_date = $1 AND is_active = TRUE ORDER BY sort_order, start_time"
    )
    .bind(today)
    .fetch_all(pool.get_ref())
    .await
    {
        Ok(events) => HttpResponse::Ok().json(serde_json::json!({
            "success": true,
            "date": today.to_string(),
            "data": events,
        })),
        Err(e) => {
            tracing::error!("Failed to fetch today's events: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false,
                "error": "Failed to load events",
            }))
        }
    }
}
