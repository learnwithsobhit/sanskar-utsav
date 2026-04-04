use actix_web::{get, post, web, HttpRequest, HttpResponse};
use sqlx::PgPool;
use std::time::Duration;

use crate::auth::invite_code;
use crate::auth::middleware::extract_guest;
use crate::cache::RedisCache;
use crate::models::guest::LoginRequest;

/// Sliding window for login attempts per client IP (behind proxy: uses `X-Forwarded-For` when set).
const LOGIN_RATE_WINDOW: Duration = Duration::from_secs(900);
const LOGIN_RATE_MAX: i64 = 40;

fn login_rate_key(req: &HttpRequest) -> String {
    let info = req.connection_info();
    let ip = info
        .realip_remote_addr()
        .or(info.peer_addr())
        .unwrap_or("unknown");
    format!("ratelimit:login:{ip}")
}

/// POST /api/auth/login — authenticate with invite code
#[post("/api/auth/login")]
pub async fn login(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    cache: web::Data<RedisCache>,
    body: web::Json<LoginRequest>,
) -> HttpResponse {
    let rl_key = login_rate_key(&req);
    match cache.incr_with_ttl(&rl_key, LOGIN_RATE_WINDOW).await {
        Ok(n) if n > LOGIN_RATE_MAX => {
            return HttpResponse::TooManyRequests().json(serde_json::json!({
                "success": false,
                "error": "Too many login attempts. Try again in a few minutes.",
            }));
        }
        Err(e) => tracing::warn!("login rate-limit redis: {e}"),
        _ => {}
    }

    match invite_code::login_with_invite_code(&pool, &body.invite_code).await {
        Ok((guest, token)) => HttpResponse::Ok().json(serde_json::json!({
            "success": true,
            "token": token,
            "guest": guest,
        })),
        Err(invite_code::AuthError::InvalidCode) => {
            HttpResponse::Unauthorized().json(serde_json::json!({
                "success": false,
                "error": "Invalid invite code. Please check and try again.",
            }))
        }
        Err(e) => {
            tracing::error!("Login error: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false,
                "error": "Something went wrong. Please try again.",
            }))
        }
    }
}

/// GET /api/auth/me — get current authenticated guest
#[get("/api/auth/me")]
pub async fn me(req: HttpRequest, pool: web::Data<PgPool>) -> HttpResponse {
    match extract_guest(&req, &pool).await {
        Ok(guest) => HttpResponse::Ok().json(serde_json::json!({
            "success": true,
            "guest": guest,
        })),
        Err(_) => HttpResponse::Unauthorized().json(serde_json::json!({
            "success": false,
            "error": "Not authenticated",
        })),
    }
}

/// POST /api/auth/logout — end session
#[post("/api/auth/logout")]
pub async fn logout(req: HttpRequest, pool: web::Data<PgPool>) -> HttpResponse {
    let token = req
        .headers()
        .get("Authorization")
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.strip_prefix("Bearer "));

    if let Some(t) = token {
        let _ = invite_code::logout(&pool, t).await;
    }

    HttpResponse::Ok().json(serde_json::json!({
        "success": true,
    }))
}
