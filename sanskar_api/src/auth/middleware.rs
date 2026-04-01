use actix_web::{HttpRequest, web};
use sqlx::PgPool;

use crate::models::guest::Guest;
use super::invite_code::{validate_session, AuthError};

/// Extract the authenticated guest from the `Authorization: Bearer <token>` header.
pub async fn extract_guest(req: &HttpRequest, pool: &web::Data<PgPool>) -> Result<Guest, AuthError> {
    let token = req
        .headers()
        .get("Authorization")
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.strip_prefix("Bearer "))
        .ok_or(AuthError::InvalidToken)?;

    validate_session(pool, token).await
}

/// Same as `extract_guest` but also verifies the guest is an admin.
pub async fn extract_admin(req: &HttpRequest, pool: &web::Data<PgPool>) -> Result<Guest, AuthError> {
    let guest = extract_guest(req, pool).await?;
    if !guest.is_admin {
        return Err(AuthError::NotAdmin);
    }
    Ok(guest)
}
