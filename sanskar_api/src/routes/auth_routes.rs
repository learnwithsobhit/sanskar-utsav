use actix_web::{get, post, web, HttpRequest, HttpResponse};
use rand::Rng;
use serde::Deserialize;
use sqlx::PgPool;
use std::env;
use std::time::Duration;

use crate::auth::invite_code::{self, hash_token};
use crate::auth::middleware::extract_guest;
use crate::cache::RedisCache;
use crate::config::AppConfig;
use crate::models::guest::{
    LoginRequest, OtpRequestBody, OtpVerifyBody, RedeemInviteRequest,
};
use crate::services::otp_delivery;
use crate::services::phone::normalize_e164_phone;

/// Sliding window for login attempts per client IP (behind proxy: uses `X-Forwarded-For` when set).
const LOGIN_RATE_WINDOW: Duration = Duration::from_secs(900);
const LOGIN_RATE_MAX: i64 = 40;
const OTP_RATE_WINDOW: Duration = Duration::from_secs(900);
const OTP_RATE_MAX_PHONE: i64 = 8;
const OTP_TTL_SECS: u64 = 600;

fn login_rate_key(req: &HttpRequest) -> String {
    let info = req.connection_info();
    let ip = info
        .realip_remote_addr()
        .or(info.peer_addr())
        .unwrap_or("unknown");
    format!("ratelimit:login:{ip}")
}

fn otp_phone_rate_key(phone: &str) -> String {
    format!("ratelimit:otp:phone:{phone}")
}

fn log_otp_plaintext_on_delivery_failure() -> bool {
    env::var("LOG_OTP_PLAINTEXT_ON_FAILURE")
        .map(|v| matches!(v.to_lowercase().as_str(), "1" | "true" | "yes"))
        .unwrap_or(false)
}

#[derive(Debug, Deserialize)]
pub struct InviteInfoQuery {
    pub t: String,
}

/// GET /api/auth/invite-info — minimal preview for invite link (no PII).
#[get("/api/auth/invite-info")]
pub async fn invite_info(
    cfg: web::Data<AppConfig>,
    pool: web::Data<PgPool>,
    q: web::Query<InviteInfoQuery>,
) -> HttpResponse {
    let th = hash_token(q.t.trim());
    let row: Option<(String,)> =
        sqlx::query_as("SELECT name FROM guests WHERE invite_token_hash = $1")
            .bind(&th)
            .fetch_optional(pool.get_ref())
            .await
            .unwrap_or(None);

    let Some((name,)) = row else {
        return HttpResponse::NotFound().json(serde_json::json!({
            "success": false,
            "error": "Invalid or expired invite",
        }));
    };

    let hint = name
        .split_whitespace()
        .next()
        .and_then(|w| w.chars().next())
        .map(|c| format!("{c}**"))
        .unwrap_or_else(|| "**".into());

    HttpResponse::Ok().json(serde_json::json!({
        "success": true,
        "event_name": cfg.event_display_name,
        "name_hint": hint,
    }))
}

/// POST /api/auth/redeem-invite — session from opaque invite token (skipped when OTP_LOGIN_REQUIRED).
#[post("/api/auth/redeem-invite")]
pub async fn redeem_invite(
    req: HttpRequest,
    cfg: web::Data<AppConfig>,
    pool: web::Data<PgPool>,
    cache: web::Data<RedisCache>,
    body: web::Json<RedeemInviteRequest>,
) -> HttpResponse {
    if cfg.otp_login_required {
        return HttpResponse::BadRequest().json(serde_json::json!({
            "success": false,
            "error": "OTP verification required. Use /api/auth/otp/request and /api/auth/otp/verify.",
            "otp_required": true,
        }));
    }

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

    match invite_code::login_with_invite_token(&pool, body.invite_token.trim()).await {
        Ok((guest, token)) => HttpResponse::Ok().json(serde_json::json!({
            "success": true,
            "token": token,
            "guest": guest,
        })),
        Err(invite_code::AuthError::InvalidCode) => HttpResponse::Unauthorized().json(serde_json::json!({
            "success": false,
            "error": "Invalid or unknown invite link.",
        })),
        Err(invite_code::AuthError::AccountDisabled) => HttpResponse::Forbidden().json(serde_json::json!({
            "success": false,
            "error": "This invite is no longer valid.",
        })),
        Err(e) => {
            tracing::error!("Redeem invite error: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false,
                "error": "Something went wrong. Please try again.",
            }))
        }
    }
}

/// POST /api/auth/login — invite code or invite_token (blocked when OTP_LOGIN_REQUIRED).
#[post("/api/auth/login")]
pub async fn login(
    req: HttpRequest,
    cfg: web::Data<AppConfig>,
    pool: web::Data<PgPool>,
    cache: web::Data<RedisCache>,
    body: web::Json<LoginRequest>,
) -> HttpResponse {
    if cfg.otp_login_required {
        return HttpResponse::BadRequest().json(serde_json::json!({
            "success": false,
            "error": "OTP verification required. Use /api/auth/otp/request and /api/auth/otp/verify.",
            "otp_required": true,
        }));
    }

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

    let result = if let Some(ref tok) = body.invite_token {
        if !tok.trim().is_empty() {
            invite_code::login_with_invite_token(&pool, tok).await
        } else if let Some(ref code) = body.invite_code {
            if !code.trim().is_empty() {
                invite_code::login_with_invite_code(&pool, code).await
            } else {
                Err(invite_code::AuthError::InvalidCode)
            }
        } else {
            Err(invite_code::AuthError::InvalidCode)
        }
    } else if let Some(ref code) = body.invite_code {
        if !code.trim().is_empty() {
            invite_code::login_with_invite_code(&pool, code).await
        } else {
            Err(invite_code::AuthError::InvalidCode)
        }
    } else {
        Err(invite_code::AuthError::InvalidCode)
    };

    match result {
        Ok((guest, token)) => HttpResponse::Ok().json(serde_json::json!({
            "success": true,
            "token": token,
            "guest": guest,
        })),
        Err(invite_code::AuthError::InvalidCode) => HttpResponse::Unauthorized().json(serde_json::json!({
            "success": false,
            "error": "Invalid invite code. Please check and try again.",
        })),
        Err(invite_code::AuthError::AccountDisabled) => HttpResponse::Forbidden().json(serde_json::json!({
            "success": false,
            "error": "This account is no longer active.",
        })),
        Err(e) => {
            tracing::error!("Login error: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false,
                "error": "Something went wrong. Please try again.",
            }))
        }
    }
}

/// POST /api/auth/otp/request — send OTP to registered phone (Twilio SMS / WhatsApp per `OTP_DELIVERY`).
#[post("/api/auth/otp/request")]
pub async fn otp_request(
    req: HttpRequest,
    cfg: web::Data<AppConfig>,
    pool: web::Data<PgPool>,
    cache: web::Data<RedisCache>,
    body: web::Json<OtpRequestBody>,
) -> HttpResponse {
    let rl_key = login_rate_key(&req);
    match cache.incr_with_ttl(&rl_key, LOGIN_RATE_WINDOW).await {
        Ok(n) if n > LOGIN_RATE_MAX => {
            return HttpResponse::TooManyRequests().json(serde_json::json!({
                "success": false,
                "error": "Too many attempts. Try again later.",
            }));
        }
        Err(e) => tracing::warn!("otp request rate-limit redis: {e}"),
        _ => {}
    }

    let phone = match normalize_e164_phone(&body.phone) {
        Some(p) => p,
        None => {
            return HttpResponse::BadRequest().json(serde_json::json!({
                "success": false,
                "error": "Invalid phone format. Use E.164 (e.g. +9198xxxxxxx).",
            }));
        }
    };

    let rl_phone = otp_phone_rate_key(&phone);
    match cache.incr_with_ttl(&rl_phone, OTP_RATE_WINDOW).await {
        Ok(n) if n > OTP_RATE_MAX_PHONE => {
            return HttpResponse::TooManyRequests().json(serde_json::json!({
                "success": false,
                "error": "Too many OTP requests for this number.",
            }));
        }
        Err(e) => tracing::warn!("otp phone rate-limit: {e}"),
        _ => {}
    }

    let guest = resolve_guest_for_otp(&pool, body.invite_token.as_deref(), body.invite_code.as_deref()).await;
    let guest = match guest {
        Ok(g) => g,
        Err(_) => {
            // Same response whether wrong code or wrong phone (enumeration hardening)
            return HttpResponse::Ok().json(serde_json::json!({
                "success": true,
                "message": "If this invite matches your phone, you will receive a code.",
            }));
        }
    };

    if !invite_code::guest_may_authenticate(&guest.status) {
        return HttpResponse::Ok().json(serde_json::json!({
            "success": true,
            "message": "If this invite matches your phone, you will receive a code.",
        }));
    }

    let guest_phone = normalize_e164_phone(&guest.phone).unwrap_or_default();
    if guest_phone != phone {
        return HttpResponse::Ok().json(serde_json::json!({
            "success": true,
            "message": "If this invite matches your phone, you will receive a code.",
        }));
    }

    let mut rng = rand::thread_rng();
    let otp: u32 = rng.gen_range(100_000..999_999);
    let otp_str = format!("{otp:06}");
    let otp_hash = hash_token(&otp_str);
    let redis_key = format!("otp:{}", guest.id);

    if let Err(e) = cache
        .set(
            &redis_key,
            &otp_hash,
            std::time::Duration::from_secs(OTP_TTL_SECS),
        )
        .await
    {
        tracing::error!("redis set otp: {e}");
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "success": false,
            "error": "Could not start verification. Try again.",
        }));
    }

    let msg = format!("Your Sanskar Utsav login code is {otp_str}. Valid for 10 minutes.");
    let delivery_channel = otp_delivery::send_login_otp(cfg.get_ref(), &phone, &msg).await;
    if delivery_channel == "none" {
        if log_otp_plaintext_on_delivery_failure() {
            tracing::warn!(
                target: "otp",
                "OTP delivery failed; plaintext for {} (guest {}): {}",
                phone,
                guest.id,
                otp_str
            );
        } else {
            tracing::warn!(
                target: "otp",
                "OTP delivery failed for {} (guest {}); set LOG_OTP_PLAINTEXT_ON_FAILURE=1 to log code",
                phone,
                guest.id
            );
        }
    }

    HttpResponse::Ok().json(serde_json::json!({
        "success": true,
        "message": "If this invite matches your phone and delivery is configured, you should receive a verification code shortly.",
        "delivery_channel": delivery_channel,
    }))
}

/// POST /api/auth/otp/verify — verify OTP and return session.
#[post("/api/auth/otp/verify")]
pub async fn otp_verify(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    cache: web::Data<RedisCache>,
    body: web::Json<OtpVerifyBody>,
) -> HttpResponse {
    let rl_key = login_rate_key(&req);
    match cache.incr_with_ttl(&rl_key, LOGIN_RATE_WINDOW).await {
        Ok(n) if n > LOGIN_RATE_MAX => {
            return HttpResponse::TooManyRequests().json(serde_json::json!({
                "success": false,
                "error": "Too many attempts. Try again later.",
            }));
        }
        Err(e) => tracing::warn!("otp verify rate-limit redis: {e}"),
        _ => {}
    }

    let phone = match normalize_e164_phone(&body.phone) {
        Some(p) => p,
        None => {
            return HttpResponse::BadRequest().json(serde_json::json!({
                "success": false,
                "error": "Invalid phone format.",
            }));
        }
    };

    let guest = match resolve_guest_for_otp(&pool, body.invite_token.as_deref(), body.invite_code.as_deref()).await {
        Ok(g) => g,
        Err(_) => {
            return HttpResponse::Unauthorized().json(serde_json::json!({
                "success": false,
                "error": "Invalid code or OTP.",
            }));
        }
    };

    if !invite_code::guest_may_authenticate(&guest.status) {
        return HttpResponse::Forbidden().json(serde_json::json!({
            "success": false,
            "error": "This invite is no longer valid.",
        }));
    }

    let guest_phone = normalize_e164_phone(&guest.phone).unwrap_or_default();
    if guest_phone != phone {
        return HttpResponse::Unauthorized().json(serde_json::json!({
            "success": false,
            "error": "Invalid code or OTP.",
        }));
    }

    let redis_key = format!("otp:{}", guest.id);
    let stored = match cache.get(&redis_key).await {
        Some(h) => h,
        None => {
            return HttpResponse::Unauthorized().json(serde_json::json!({
                "success": false,
                "error": "Code expired or not requested. Request a new code.",
            }));
        }
    };

    let entered_hash = hash_token(body.otp.trim());
    if entered_hash != stored {
        return HttpResponse::Unauthorized().json(serde_json::json!({
            "success": false,
            "error": "Invalid OTP.",
        }));
    }

    let _ = cache.del(&redis_key).await;

    match invite_code::finalize_login(&pool, guest).await {
        Ok((guest, token)) => HttpResponse::Ok().json(serde_json::json!({
            "success": true,
            "token": token,
            "guest": guest,
        })),
        Err(invite_code::AuthError::AccountDisabled) => HttpResponse::Forbidden().json(serde_json::json!({
            "success": false,
            "error": "This invite is no longer valid.",
        })),
        Err(e) => {
            tracing::error!("otp verify finalize: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false,
                "error": "Something went wrong.",
            }))
        }
    }
}

async fn resolve_guest_for_otp(
    pool: &PgPool,
    invite_token: Option<&str>,
    invite_code: Option<&str>,
) -> Result<crate::models::guest::Guest, ()> {
    if let Some(tok) = invite_token {
        if !tok.trim().is_empty() {
            return invite_code::find_guest_by_invite_token(pool, tok).await.map_err(|_| ());
        }
    }
    if let Some(code) = invite_code {
        if !code.trim().is_empty() {
            return invite_code::find_guest_by_invite_code(pool, code).await.map_err(|_| ());
        }
    }
    Err(())
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
