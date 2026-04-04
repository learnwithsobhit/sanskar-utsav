use actix_web::{get, put, web, HttpRequest, HttpResponse};
use sqlx::PgPool;
use std::time::Duration;

use crate::auth::middleware::extract_guest;
use crate::cache::RedisCache;
use crate::models::guest::{Guest, GuestPublicView, UpdateProfileRequest};
use crate::services::cache_service;

/// GET /api/guests — public guest directory (Redis-cached)
#[get("/api/guests")]
pub async fn list_guests(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    cache: web::Data<RedisCache>,
) -> HttpResponse {
    // Must be authenticated
    if extract_guest(&req, &pool).await.is_err() {
        return HttpResponse::Unauthorized().json(serde_json::json!({
            "success": false, "error": "Not authenticated"
        }));
    }

    if let Some(cached) = cache.get(cache_service::GUESTS_DIRECTORY_KEY).await {
        if let Ok(value) = serde_json::from_str::<serde_json::Value>(&cached) {
            return HttpResponse::Ok().json(value);
        }
    }

    match sqlx::query_as::<_, Guest>(
        "SELECT * FROM guests WHERE status != 'declined' ORDER BY name"
    )
    .fetch_all(pool.get_ref())
    .await
    {
        Ok(guests) => {
            let public: Vec<GuestPublicView> = guests.into_iter().map(GuestPublicView::from).collect();
            let body = serde_json::json!({
                "success": true,
                "data": public,
            });
            if let Ok(json) = serde_json::to_string(&body) {
                let _ = cache
                    .set(cache_service::GUESTS_DIRECTORY_KEY, &json, Duration::from_secs(120))
                    .await;
            }
            HttpResponse::Ok().json(body)
        }
        Err(e) => {
            tracing::error!("Failed to list guests: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false,
                "error": "Failed to load guests",
            }))
        }
    }
}

/// GET /api/guests/{id}
#[get("/api/guests/{id}")]
pub async fn get_guest(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    path: web::Path<uuid::Uuid>,
) -> HttpResponse {
    if extract_guest(&req, &pool).await.is_err() {
        return HttpResponse::Unauthorized().json(serde_json::json!({
            "success": false, "error": "Not authenticated"
        }));
    }

    let guest_id = path.into_inner();
    match sqlx::query_as::<_, Guest>("SELECT * FROM guests WHERE id = $1")
        .bind(guest_id)
        .fetch_optional(pool.get_ref())
        .await
    {
        Ok(Some(g)) => {
            let public = GuestPublicView::from(g);
            HttpResponse::Ok().json(serde_json::json!({
                "success": true,
                "data": public,
            }))
        }
        Ok(None) => HttpResponse::NotFound().json(serde_json::json!({
            "success": false,
            "error": "Guest not found",
        })),
        Err(e) => {
            tracing::error!("Failed to fetch guest: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false,
                "error": "Failed to load guest",
            }))
        }
    }
}

/// PUT /api/guests/profile — update own profile
#[put("/api/guests/profile")]
pub async fn update_profile(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    cache: web::Data<RedisCache>,
    body: web::Json<UpdateProfileRequest>,
) -> HttpResponse {
    let guest = match extract_guest(&req, &pool).await {
        Ok(g) => g,
        Err(_) => return HttpResponse::Unauthorized().json(serde_json::json!({
            "success": false, "error": "Not authenticated"
        })),
    };

    let name = body.name.as_deref().unwrap_or(&guest.name);
    let phone = body.phone.as_deref().unwrap_or(&guest.phone);
    let email = body.email.as_deref().unwrap_or(&guest.email);
    let dietary = body.dietary_pref.as_deref().unwrap_or(&guest.dietary_pref);
    let city = body.city.as_deref().unwrap_or(&guest.city);
    let accom = body.accommodation_needed.unwrap_or(guest.accommodation_needed);
    let avatar = body.avatar_url.as_deref().unwrap_or(&guest.avatar_url);

    match sqlx::query_as::<_, Guest>(
        "UPDATE guests SET name=$1, phone=$2, email=$3, dietary_pref=$4, city=$5, \
         accommodation_needed=$6, avatar_url=$7, updated_at=NOW() \
         WHERE id=$8 RETURNING *"
    )
    .bind(name).bind(phone).bind(email).bind(dietary)
    .bind(city).bind(accom).bind(avatar).bind(guest.id)
    .fetch_one(pool.get_ref())
    .await
    {
        Ok(updated) => {
            cache_service::invalidate_guest_directory(&cache).await;
            HttpResponse::Ok().json(serde_json::json!({
                "success": true,
                "guest": updated,
            }))
        }
        Err(e) => {
            tracing::error!("Failed to update profile: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false,
                "error": "Failed to update profile",
            }))
        }
    }
}
