use sqlx::PgPool;
use uuid::Uuid;

/// Insert a notification for a specific guest.
pub async fn create_notification(
    pool: &PgPool,
    guest_id: Uuid,
    title: &str,
    body: &str,
    notification_type: &str,
    reference_type: &str,
    reference_id: i32,
) -> Result<(), sqlx::Error> {
    sqlx::query(
        "INSERT INTO notifications (guest_id, title, body, notification_type, reference_type, reference_id) \
         VALUES ($1, $2, $3, $4, $5, $6)"
    )
    .bind(guest_id)
    .bind(title)
    .bind(body)
    .bind(notification_type)
    .bind(reference_type)
    .bind(reference_id)
    .execute(pool)
    .await?;
    Ok(())
}

/// Broadcast a notification to all active guests.
pub async fn broadcast_notification(
    pool: &PgPool,
    title: &str,
    body: &str,
    notification_type: &str,
) -> Result<usize, sqlx::Error> {
    let guest_ids: Vec<Uuid> = sqlx::query_scalar(
        "SELECT id FROM guests WHERE status != 'declined'"
    )
    .fetch_all(pool)
    .await?;

    let mut count = 0;
    for gid in guest_ids {
        if create_notification(pool, gid, title, body, notification_type, "", 0).await.is_ok() {
            count += 1;
        }
    }
    Ok(count)
}
