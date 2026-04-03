use actix_web::{get, post, put, web, HttpRequest, HttpResponse};
use sqlx::PgPool;

use crate::auth::middleware::extract_guest;
use crate::broker::{NatsBroker, subjects};
use crate::models::rsvp::*;

/// POST /api/rsvp/{event_id} — submit RSVP
#[post("/api/rsvp/{event_id}")]
pub async fn submit_rsvp(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    nats: web::Data<Option<NatsBroker>>,
    path: web::Path<i32>,
    body: web::Json<RsvpRequest>,
) -> HttpResponse {
    let guest = match extract_guest(&req, &pool).await {
        Ok(g) => g,
        Err(_) => return HttpResponse::Unauthorized().json(serde_json::json!({
            "success": false, "error": "Not authenticated"
        })),
    };

    let event_id = path.into_inner();
    let count = body.guest_count.unwrap_or(1);
    let notes = body.notes.as_deref().unwrap_or("");

    match sqlx::query_as::<_, RsvpResponse>(
        "INSERT INTO rsvp_responses (guest_id, event_id, status, guest_count, notes) \
         VALUES ($1, $2, $3, $4, $5) \
         ON CONFLICT (guest_id, event_id) DO UPDATE SET \
           status = EXCLUDED.status, guest_count = EXCLUDED.guest_count, \
           notes = EXCLUDED.notes, updated_at = NOW() \
         RETURNING *"
    )
    .bind(guest.id)
    .bind(event_id)
    .bind(&body.status)
    .bind(count)
    .bind(notes)
    .fetch_one(pool.get_ref())
    .await
    {
        Ok(rsvp) => {
            // Publish RSVP update
            if let Some(n) = nats.as_ref() { let _ = n.publish(subjects::RSVP_UPDATED, &serde_json::json!({
                "guest_id": guest.id,
                "event_id": event_id,
                "status": rsvp.status,
            })).await; }

            HttpResponse::Ok().json(serde_json::json!({
                "success": true,
                "data": rsvp,
            }))
        }
        Err(e) => {
            tracing::error!("Failed to submit RSVP: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false,
                "error": "Failed to submit RSVP",
            }))
        }
    }
}

/// GET /api/rsvp/my — get my RSVP responses
#[get("/api/rsvp/my")]
pub async fn my_rsvps(
    req: HttpRequest,
    pool: web::Data<PgPool>,
) -> HttpResponse {
    let guest = match extract_guest(&req, &pool).await {
        Ok(g) => g,
        Err(_) => return HttpResponse::Unauthorized().json(serde_json::json!({
            "success": false, "error": "Not authenticated"
        })),
    };

    match sqlx::query_as::<_, RsvpWithEvent>(
        "SELECT r.id, r.guest_id, r.event_id, e.title as event_title, e.event_date, \
         r.status, r.guest_count, r.notes, r.updated_at \
         FROM rsvp_responses r \
         JOIN ceremony_events e ON e.id = r.event_id \
         WHERE r.guest_id = $1 \
         ORDER BY e.event_date, e.sort_order"
    )
    .bind(guest.id)
    .fetch_all(pool.get_ref())
    .await
    {
        Ok(items) => HttpResponse::Ok().json(serde_json::json!({
            "success": true,
            "data": items,
        })),
        Err(e) => {
            tracing::error!("Failed to fetch RSVPs: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false,
                "error": "Failed to load RSVPs",
            }))
        }
    }
}

/// PUT /api/rsvp/{event_id} — update RSVP
#[put("/api/rsvp/{event_id}")]
pub async fn update_rsvp(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    path: web::Path<i32>,
    body: web::Json<RsvpRequest>,
) -> HttpResponse {
    let guest = match extract_guest(&req, &pool).await {
        Ok(g) => g,
        Err(_) => return HttpResponse::Unauthorized().json(serde_json::json!({
            "success": false, "error": "Not authenticated"
        })),
    };

    let event_id = path.into_inner();

    match sqlx::query_as::<_, RsvpResponse>(
        "UPDATE rsvp_responses SET status = $1, guest_count = $2, notes = $3, updated_at = NOW() \
         WHERE guest_id = $4 AND event_id = $5 RETURNING *"
    )
    .bind(&body.status)
    .bind(body.guest_count.unwrap_or(1))
    .bind(body.notes.as_deref().unwrap_or(""))
    .bind(guest.id)
    .bind(event_id)
    .fetch_optional(pool.get_ref())
    .await
    {
        Ok(Some(rsvp)) => HttpResponse::Ok().json(serde_json::json!({
            "success": true,
            "data": rsvp,
        })),
        Ok(None) => HttpResponse::NotFound().json(serde_json::json!({
            "success": false,
            "error": "RSVP not found — submit first",
        })),
        Err(e) => {
            tracing::error!("Failed to update RSVP: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false,
                "error": "Failed to update RSVP",
            }))
        }
    }
}

/// POST /api/rsvp/bulk — RSVP for multiple events at once
#[post("/api/rsvp/bulk")]
pub async fn bulk_rsvp(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    body: web::Json<BulkRsvpRequest>,
) -> HttpResponse {
    let guest = match extract_guest(&req, &pool).await {
        Ok(g) => g,
        Err(_) => return HttpResponse::Unauthorized().json(serde_json::json!({
            "success": false, "error": "Not authenticated"
        })),
    };

    let mut results = Vec::new();

    for item in &body.responses {
        let count = item.guest_count.unwrap_or(1);
        let result = sqlx::query_as::<_, RsvpResponse>(
            "INSERT INTO rsvp_responses (guest_id, event_id, status, guest_count) \
             VALUES ($1, $2, $3, $4) \
             ON CONFLICT (guest_id, event_id) DO UPDATE SET \
               status = EXCLUDED.status, guest_count = EXCLUDED.guest_count, updated_at = NOW() \
             RETURNING *"
        )
        .bind(guest.id)
        .bind(item.event_id)
        .bind(&item.status)
        .bind(count)
        .fetch_one(pool.get_ref())
        .await;

        match result {
            Ok(rsvp) => results.push(serde_json::json!({"event_id": item.event_id, "status": rsvp.status, "ok": true})),
            Err(e) => results.push(serde_json::json!({"event_id": item.event_id, "ok": false, "error": e.to_string()})),
        }
    }

    HttpResponse::Ok().json(serde_json::json!({
        "success": true,
        "results": results,
    }))
}
