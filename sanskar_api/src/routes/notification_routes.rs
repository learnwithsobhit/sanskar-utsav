use actix_web::{get, put, post, web, HttpRequest, HttpResponse};
use sqlx::PgPool;

use crate::auth::middleware::extract_guest;
use crate::models::notification::*;

/// GET /api/notifications — my notifications
#[get("/api/notifications")]
pub async fn list_notifications(
    req: HttpRequest,
    pool: web::Data<PgPool>,
) -> HttpResponse {
    let guest = match extract_guest(&req, &pool).await {
        Ok(g) => g,
        Err(_) => return HttpResponse::Unauthorized().json(serde_json::json!({
            "success": false, "error": "Not authenticated"
        })),
    };

    match sqlx::query_as::<_, Notification>(
        "SELECT * FROM notifications WHERE guest_id = $1 ORDER BY created_at DESC LIMIT 50"
    )
    .bind(guest.id)
    .fetch_all(pool.get_ref())
    .await
    {
        Ok(items) => {
            let unread = items.iter().filter(|n| !n.is_read).count();
            HttpResponse::Ok().json(serde_json::json!({
                "success": true,
                "unread_count": unread,
                "data": items,
            }))
        }
        Err(e) => {
            tracing::error!("Failed to list notifications: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false,
                "error": "Failed to load notifications",
            }))
        }
    }
}

/// PUT /api/notifications/{id}/read — mark single as read
#[put("/api/notifications/{id}/read")]
pub async fn mark_read(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    path: web::Path<i32>,
) -> HttpResponse {
    let guest = match extract_guest(&req, &pool).await {
        Ok(g) => g,
        Err(_) => return HttpResponse::Unauthorized().json(serde_json::json!({
            "success": false, "error": "Not authenticated"
        })),
    };

    let notif_id = path.into_inner();

    let _ = sqlx::query(
        "UPDATE notifications SET is_read = TRUE WHERE id = $1 AND guest_id = $2"
    )
    .bind(notif_id)
    .bind(guest.id)
    .execute(pool.get_ref())
    .await;

    HttpResponse::Ok().json(serde_json::json!({ "success": true }))
}

/// PUT /api/notifications/read-all
#[put("/api/notifications/read-all")]
pub async fn mark_all_read(
    req: HttpRequest,
    pool: web::Data<PgPool>,
) -> HttpResponse {
    let guest = match extract_guest(&req, &pool).await {
        Ok(g) => g,
        Err(_) => return HttpResponse::Unauthorized().json(serde_json::json!({
            "success": false, "error": "Not authenticated"
        })),
    };

    let _ = sqlx::query(
        "UPDATE notifications SET is_read = TRUE WHERE guest_id = $1 AND is_read = FALSE"
    )
    .bind(guest.id)
    .execute(pool.get_ref())
    .await;

    HttpResponse::Ok().json(serde_json::json!({ "success": true }))
}

/// POST /api/notifications/fcm-token — register FCM token
#[post("/api/notifications/fcm-token")]
pub async fn register_fcm_token(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    body: web::Json<RegisterFcmTokenRequest>,
) -> HttpResponse {
    let guest = match extract_guest(&req, &pool).await {
        Ok(g) => g,
        Err(_) => return HttpResponse::Unauthorized().json(serde_json::json!({
            "success": false, "error": "Not authenticated"
        })),
    };

    let device = body.device_type.as_deref().unwrap_or("android");

    let _ = sqlx::query(
        "INSERT INTO fcm_tokens (guest_id, token, device_type) VALUES ($1, $2, $3) \
         ON CONFLICT (guest_id, token) DO NOTHING"
    )
    .bind(guest.id)
    .bind(&body.token)
    .bind(device)
    .execute(pool.get_ref())
    .await;

    HttpResponse::Ok().json(serde_json::json!({ "success": true }))
}
