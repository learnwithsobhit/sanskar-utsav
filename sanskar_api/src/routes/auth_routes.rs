use actix_web::{get, post, web, HttpRequest, HttpResponse};
use sqlx::PgPool;

use crate::auth::invite_code;
use crate::auth::middleware::extract_guest;
use crate::models::guest::LoginRequest;

/// POST /api/auth/login — authenticate with invite code
#[post("/api/auth/login")]
pub async fn login(
    pool: web::Data<PgPool>,
    body: web::Json<LoginRequest>,
) -> HttpResponse {
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
