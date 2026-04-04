use chrono::{Duration, Utc};
use rand::Rng;
use sha2::{Digest, Sha256};
use sqlx::PgPool;

use crate::models::guest::{Guest, GuestSession};

/// Generate a cryptographically random session token.
pub fn generate_token() -> String {
    let mut rng = rand::thread_rng();
    let bytes: Vec<u8> = (0..64).map(|_| rng.gen::<u8>()).collect();
    hex::encode(bytes)
}

/// 32-byte random invite secret (64 hex chars) for links/QR.
pub fn generate_invite_raw_token() -> String {
    let mut rng = rand::thread_rng();
    let bytes: Vec<u8> = (0..32).map(|_| rng.gen::<u8>()).collect();
    hex::encode(bytes)
}

/// Hash a token for storage (we store the hash, compare on lookup).
pub fn hash_token(token: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(token.as_bytes());
    hex::encode(hasher.finalize())
}

/// Revoked/suspended guests cannot authenticate or use sessions.
pub fn guest_may_authenticate(status: &str) -> bool {
    !matches!(status, "revoked" | "suspended")
}

/// Create session, confirm invited guests, enroll in family chat. Caller must verify [Guest::guest_may_authenticate].
pub async fn finalize_login(pool: &PgPool, guest: Guest) -> Result<(Guest, String), AuthError> {
    if !guest_may_authenticate(&guest.status) {
        return Err(AuthError::AccountDisabled);
    }

    let raw_token = generate_token();
    let token_hash = hash_token(&raw_token);
    let expires_at = Utc::now() + Duration::days(30);

    sqlx::query(
        "INSERT INTO guest_sessions (guest_id, token, expires_at) VALUES ($1, $2, $3)",
    )
    .bind(guest.id)
    .bind(&token_hash)
    .bind(expires_at)
    .execute(pool)
    .await
    .map_err(AuthError::Db)?;

    if guest.status == "invited" {
        sqlx::query("UPDATE guests SET status = 'confirmed', updated_at = NOW() WHERE id = $1")
            .bind(guest.id)
            .execute(pool)
            .await
            .map_err(AuthError::Db)?;
    }

    let family_group_id = uuid::Uuid::parse_str("00000000-0000-0000-0000-000000000001").unwrap();
    let _ = sqlx::query(
        "INSERT INTO chat_room_members (room_id, guest_id, role) \
         VALUES ($1, $2, 'member') ON CONFLICT (room_id, guest_id) DO NOTHING",
    )
    .bind(family_group_id)
    .bind(guest.id)
    .execute(pool)
    .await;

    let guest = sqlx::query_as::<_, Guest>("SELECT * FROM guests WHERE id = $1")
        .bind(guest.id)
        .fetch_one(pool)
        .await
        .map_err(AuthError::Db)?;

    Ok((guest, raw_token))
}

/// Lookup guest by short invite code (legacy).
pub async fn find_guest_by_invite_code(pool: &PgPool, invite_code: &str) -> Result<Guest, AuthError> {
    let code_upper = invite_code.trim().to_uppercase();
    sqlx::query_as::<_, Guest>("SELECT * FROM guests WHERE UPPER(invite_code) = $1")
        .bind(&code_upper)
        .fetch_optional(pool)
        .await
        .map_err(AuthError::Db)?
        .ok_or(AuthError::InvalidCode)
}

/// Lookup guest by opaque invite token (hash match).
pub async fn find_guest_by_invite_token(pool: &PgPool, raw_token: &str) -> Result<Guest, AuthError> {
    let th = hash_token(raw_token.trim());
    sqlx::query_as::<_, Guest>("SELECT * FROM guests WHERE invite_token_hash = $1")
        .bind(&th)
        .fetch_optional(pool)
        .await
        .map_err(AuthError::Db)?
        .ok_or(AuthError::InvalidCode)
}

/// Authenticate a guest by invite code. Returns the guest + a new session token.
pub async fn login_with_invite_code(
    pool: &PgPool,
    invite_code: &str,
) -> Result<(Guest, String), AuthError> {
    let guest = find_guest_by_invite_code(pool, invite_code).await?;
    if !guest_may_authenticate(&guest.status) {
        return Err(AuthError::AccountDisabled);
    }
    finalize_login(pool, guest).await
}

/// Authenticate using opaque invite token from link/QR.
pub async fn login_with_invite_token(
    pool: &PgPool,
    raw_token: &str,
) -> Result<(Guest, String), AuthError> {
    let guest = find_guest_by_invite_token(pool, raw_token).await?;
    if !guest_may_authenticate(&guest.status) {
        return Err(AuthError::AccountDisabled);
    }
    finalize_login(pool, guest).await
}

/// Validate a session token and return the associated guest.
pub async fn validate_session(pool: &PgPool, raw_token: &str) -> Result<Guest, AuthError> {
    let token_hash = hash_token(raw_token);

    let session: GuestSession = sqlx::query_as::<_, GuestSession>(
        "SELECT * FROM guest_sessions WHERE token = $1 AND expires_at > NOW()",
    )
    .bind(&token_hash)
    .fetch_optional(pool)
    .await
    .map_err(AuthError::Db)?
    .ok_or(AuthError::InvalidToken)?;

    let guest: Guest = sqlx::query_as::<_, Guest>("SELECT * FROM guests WHERE id = $1")
        .bind(session.guest_id)
        .fetch_optional(pool)
        .await
        .map_err(AuthError::Db)?
        .ok_or(AuthError::InvalidToken)?;

    if !guest_may_authenticate(&guest.status) {
        return Err(AuthError::InvalidToken);
    }

    Ok(guest)
}

/// Delete all sessions for a guest (revoke access immediately).
pub async fn invalidate_sessions_for_guest(pool: &PgPool, guest_id: uuid::Uuid) -> Result<(), AuthError> {
    sqlx::query("DELETE FROM guest_sessions WHERE guest_id = $1")
        .bind(guest_id)
        .execute(pool)
        .await
        .map_err(AuthError::Db)?;
    Ok(())
}

/// Logout — delete the session.
pub async fn logout(pool: &PgPool, raw_token: &str) -> Result<(), AuthError> {
    let token_hash = hash_token(raw_token);
    sqlx::query("DELETE FROM guest_sessions WHERE token = $1")
        .bind(&token_hash)
        .execute(pool)
        .await
        .map_err(AuthError::Db)?;
    Ok(())
}

/// Generate a unique invite code for a new guest.
pub fn generate_invite_code(name: &str) -> String {
    let prefix: String = name
        .chars()
        .filter(|c| c.is_alphanumeric())
        .take(4)
        .collect::<String>()
        .to_uppercase();

    let mut rng = rand::thread_rng();
    let suffix: u32 = rng.gen_range(1000..9999);

    format!("{prefix}{suffix}")
}

#[derive(Debug, thiserror::Error)]
pub enum AuthError {
    #[error("invalid invite code")]
    InvalidCode,
    #[error("invalid or expired token")]
    InvalidToken,
    #[error("account disabled")]
    AccountDisabled,
    #[error("not authorized (admin required)")]
    NotAdmin,
    #[error("database error: {0}")]
    Db(sqlx::Error),
}
