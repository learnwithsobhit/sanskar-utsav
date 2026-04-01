use actix_web::{get, post, web, HttpRequest, HttpResponse};
use sqlx::PgPool;

use crate::auth::middleware::extract_guest;
use crate::models::blessing::*;

/// GET /api/blessings — list all blessings
#[get("/api/blessings")]
pub async fn list_blessings(pool: web::Data<PgPool>) -> HttpResponse {
    match sqlx::query_as::<_, Blessing>(
        "SELECT * FROM blessings ORDER BY is_featured DESC, created_at DESC"
    )
    .fetch_all(pool.get_ref())
    .await
    {
        Ok(items) => HttpResponse::Ok().json(serde_json::json!({
            "success": true,
            "data": items,
        })),
        Err(e) => {
            tracing::error!("Failed to list blessings: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false,
                "error": "Failed to load blessings",
            }))
        }
    }
}

/// POST /api/blessings — post a blessing
#[post("/api/blessings")]
pub async fn create_blessing(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    body: web::Json<CreateBlessingRequest>,
) -> HttpResponse {
    let guest = match extract_guest(&req, &pool).await {
        Ok(g) => g,
        Err(_) => return HttpResponse::Unauthorized().json(serde_json::json!({
            "success": false, "error": "Not authenticated"
        })),
    };

    match sqlx::query_as::<_, Blessing>(
        "INSERT INTO blessings (guest_id, guest_name, message, audio_url) \
         VALUES ($1, $2, $3, $4) RETURNING *"
    )
    .bind(guest.id)
    .bind(&guest.name)
    .bind(&body.message)
    .bind(body.audio_url.as_deref().unwrap_or(""))
    .fetch_one(pool.get_ref())
    .await
    {
        Ok(blessing) => HttpResponse::Created().json(serde_json::json!({
            "success": true,
            "data": blessing,
        })),
        Err(e) => {
            tracing::error!("Failed to create blessing: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false,
                "error": "Failed to post blessing",
            }))
        }
    }
}
