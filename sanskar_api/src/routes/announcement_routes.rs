use actix_web::{get, web, HttpResponse};
use sqlx::PgPool;

use crate::cache::RedisCache;
use crate::models::announcement::Announcement;

/// GET /api/announcements — active announcements
#[get("/api/announcements")]
pub async fn list_announcements(
    pool: web::Data<PgPool>,
    cache: web::Data<RedisCache>,
) -> HttpResponse {
    // Try cache
    if let Some(cached) = cache.get("announcements:active").await {
        if let Ok(items) = serde_json::from_str::<Vec<Announcement>>(&cached) {
            return HttpResponse::Ok().json(serde_json::json!({
                "success": true,
                "data": items,
                "cached": true,
            }));
        }
    }

    match sqlx::query_as::<_, Announcement>(
        "SELECT * FROM announcements WHERE is_active = TRUE ORDER BY priority DESC, created_at DESC"
    )
    .fetch_all(pool.get_ref())
    .await
    {
        Ok(items) => {
            // Cache for 1 minute
            if let Ok(json) = serde_json::to_string(&items) {
                let _ = cache.set("announcements:active", &json, std::time::Duration::from_secs(60)).await;
            }
            HttpResponse::Ok().json(serde_json::json!({
                "success": true,
                "data": items,
            }))
        }
        Err(e) => {
            tracing::error!("Failed to list announcements: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false,
                "error": "Failed to load announcements",
            }))
        }
    }
}

/// GET /api/announcements/urgent — urgent only
#[get("/api/announcements/urgent")]
pub async fn urgent_announcements(pool: web::Data<PgPool>) -> HttpResponse {
    match sqlx::query_as::<_, Announcement>(
        "SELECT * FROM announcements WHERE is_active = TRUE AND priority >= 2 ORDER BY created_at DESC"
    )
    .fetch_all(pool.get_ref())
    .await
    {
        Ok(items) => HttpResponse::Ok().json(serde_json::json!({
            "success": true,
            "data": items,
        })),
        Err(e) => {
            tracing::error!("Failed to list urgent announcements: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false,
                "error": "Failed to load announcements",
            }))
        }
    }
}
