use actix_web::{get, post, patch, delete, web, HttpRequest, HttpResponse};
use sqlx::PgPool;

use crate::auth::invite_code::generate_invite_code;
use crate::auth::middleware::extract_admin;
use crate::broker::{NatsBroker, subjects};
use crate::cache::RedisCache;
use crate::models::guest::*;
use crate::models::event::*;
use crate::models::announcement::*;
use crate::models::notification::*;
use crate::models::rsvp::*;
use crate::models::media::MediaItem;

// ═══════════════════════════════════════════════
// ADMIN — Guest Management
// ═══════════════════════════════════════════════

/// POST /api/admin/guests — add a guest (auto-generates invite code)
#[post("/api/admin/guests")]
pub async fn admin_create_guest(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    body: web::Json<AdminCreateGuestRequest>,
) -> HttpResponse {
    if let Err(_) = extract_admin(&req, &pool).await {
        return HttpResponse::Forbidden().json(serde_json::json!({
            "success": false, "error": "Admin access required"
        }));
    }

    let code = generate_invite_code(&body.name);

    match sqlx::query_as::<_, Guest>(
        "INSERT INTO guests (invite_code, name, phone, email, relation, family_side, city, is_admin) \
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *"
    )
    .bind(&code)
    .bind(&body.name)
    .bind(body.phone.as_deref().unwrap_or(""))
    .bind(body.email.as_deref().unwrap_or(""))
    .bind(body.relation.as_deref().unwrap_or(""))
    .bind(body.family_side.as_deref().unwrap_or("both"))
    .bind(body.city.as_deref().unwrap_or(""))
    .bind(body.is_admin.unwrap_or(false))
    .fetch_one(pool.get_ref())
    .await
    {
        Ok(guest) => {
            // Auto-enroll in Sanskar Utsav Family group chat
            let family_group_id: uuid::Uuid = "00000000-0000-0000-0000-000000000001"
                .parse().unwrap();
            let _ = sqlx::query(
                "INSERT INTO chat_room_members (room_id, guest_id, role) \
                 VALUES ($1, $2, 'member') ON CONFLICT (room_id, guest_id) DO NOTHING"
            )
            .bind(family_group_id)
            .bind(guest.id)
            .execute(pool.get_ref())
            .await;

            HttpResponse::Created().json(serde_json::json!({
                "success": true,
                "invite_code": code,
                "guest": guest,
            }))
        },
        Err(e) => {
            tracing::error!("Failed to create guest: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false, "error": "Failed to create guest"
            }))
        }
    }
}

/// GET /api/admin/guests — full guest list with all details
#[get("/api/admin/guests")]
pub async fn admin_list_guests(
    req: HttpRequest,
    pool: web::Data<PgPool>,
) -> HttpResponse {
    if let Err(_) = extract_admin(&req, &pool).await {
        return HttpResponse::Forbidden().json(serde_json::json!({
            "success": false, "error": "Admin access required"
        }));
    }

    match sqlx::query_as::<_, Guest>("SELECT * FROM guests ORDER BY created_at")
        .fetch_all(pool.get_ref())
        .await
    {
        Ok(guests) => HttpResponse::Ok().json(serde_json::json!({
            "success": true,
            "total": guests.len(),
            "data": guests,
        })),
        Err(e) => {
            tracing::error!("Failed to list guests: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false, "error": "Failed to load guests"
            }))
        }
    }
}

/// PATCH /api/admin/guests/{id}
#[patch("/api/admin/guests/{id}")]
pub async fn admin_update_guest(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    path: web::Path<uuid::Uuid>,
    body: web::Json<AdminUpdateGuestRequest>,
) -> HttpResponse {
    if let Err(_) = extract_admin(&req, &pool).await {
        return HttpResponse::Forbidden().json(serde_json::json!({
            "success": false, "error": "Admin access required"
        }));
    }

    let guest_id = path.into_inner();

    // Fetch current
    let current = match sqlx::query_as::<_, Guest>("SELECT * FROM guests WHERE id = $1")
        .bind(guest_id)
        .fetch_optional(pool.get_ref())
        .await
    {
        Ok(Some(g)) => g,
        Ok(None) => return HttpResponse::NotFound().json(serde_json::json!({
            "success": false, "error": "Guest not found"
        })),
        Err(e) => {
            tracing::error!("DB error: {e}");
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false, "error": "Database error"
            }));
        }
    };

    match sqlx::query_as::<_, Guest>(
        "UPDATE guests SET name=$1, phone=$2, email=$3, relation=$4, family_side=$5, \
         guest_count=$6, status=$7, dietary_pref=$8, city=$9, accommodation_needed=$10, \
         is_admin=$11, updated_at=NOW() WHERE id=$12 RETURNING *"
    )
    .bind(body.name.as_deref().unwrap_or(&current.name))
    .bind(body.phone.as_deref().unwrap_or(&current.phone))
    .bind(body.email.as_deref().unwrap_or(&current.email))
    .bind(body.relation.as_deref().unwrap_or(&current.relation))
    .bind(body.family_side.as_deref().unwrap_or(&current.family_side))
    .bind(body.guest_count.unwrap_or(current.guest_count))
    .bind(body.status.as_deref().unwrap_or(&current.status))
    .bind(body.dietary_pref.as_deref().unwrap_or(&current.dietary_pref))
    .bind(body.city.as_deref().unwrap_or(&current.city))
    .bind(body.accommodation_needed.unwrap_or(current.accommodation_needed))
    .bind(body.is_admin.unwrap_or(current.is_admin))
    .bind(guest_id)
    .fetch_one(pool.get_ref())
    .await
    {
        Ok(updated) => HttpResponse::Ok().json(serde_json::json!({
            "success": true,
            "guest": updated,
        })),
        Err(e) => {
            tracing::error!("Failed to update guest: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false, "error": "Failed to update guest"
            }))
        }
    }
}

// ═══════════════════════════════════════════════
// ADMIN — Event Management
// ═══════════════════════════════════════════════

/// POST /api/admin/events
#[post("/api/admin/events")]
pub async fn admin_create_event(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    cache: web::Data<RedisCache>,
    body: web::Json<AdminCreateEventRequest>,
) -> HttpResponse {
    if let Err(_) = extract_admin(&req, &pool).await {
        return HttpResponse::Forbidden().json(serde_json::json!({
            "success": false, "error": "Admin access required"
        }));
    }

    let date = match chrono::NaiveDate::parse_from_str(&body.event_date, "%Y-%m-%d") {
        Ok(d) => d,
        Err(_) => return HttpResponse::BadRequest().json(serde_json::json!({
            "success": false, "error": "Invalid date format, use YYYY-MM-DD"
        })),
    };

    let start = body.start_time.as_deref()
        .and_then(|t| chrono::NaiveTime::parse_from_str(t, "%H:%M").ok());
    let end = body.end_time.as_deref()
        .and_then(|t| chrono::NaiveTime::parse_from_str(t, "%H:%M").ok());

    match sqlx::query_as::<_, CeremonyEvent>(
        "INSERT INTO ceremony_events (day_number, title, hindi_title, description, event_date, \
         start_time, end_time, venue, venue_map_url, dress_code, category, banner_url, \
         icon_emoji, sort_order) \
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14) RETURNING *"
    )
    .bind(body.day_number)
    .bind(&body.title)
    .bind(body.hindi_title.as_deref().unwrap_or(""))
    .bind(body.description.as_deref().unwrap_or(""))
    .bind(date)
    .bind(start)
    .bind(end)
    .bind(body.venue.as_deref().unwrap_or(""))
    .bind(body.venue_map_url.as_deref().unwrap_or(""))
    .bind(body.dress_code.as_deref().unwrap_or(""))
    .bind(body.category.as_deref().unwrap_or("ritual"))
    .bind(body.banner_url.as_deref().unwrap_or(""))
    .bind(body.icon_emoji.as_deref().unwrap_or("🕉️"))
    .bind(body.sort_order.unwrap_or(0))
    .fetch_one(pool.get_ref())
    .await
    {
        Ok(event) => {
            let _ = cache.del("events:all").await;
            HttpResponse::Created().json(serde_json::json!({
                "success": true,
                "data": event,
            }))
        }
        Err(e) => {
            tracing::error!("Failed to create event: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false, "error": "Failed to create event"
            }))
        }
    }
}

/// PATCH /api/admin/events/{id}
#[patch("/api/admin/events/{id}")]
pub async fn admin_patch_event(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    cache: web::Data<RedisCache>,
    path: web::Path<i32>,
    body: web::Json<AdminPatchEventRequest>,
) -> HttpResponse {
    if let Err(_) = extract_admin(&req, &pool).await {
        return HttpResponse::Forbidden().json(serde_json::json!({
            "success": false, "error": "Admin access required"
        }));
    }

    let event_id = path.into_inner();
    let current = match sqlx::query_as::<_, CeremonyEvent>(
        "SELECT * FROM ceremony_events WHERE id = $1"
    ).bind(event_id).fetch_optional(pool.get_ref()).await {
        Ok(Some(e)) => e,
        Ok(None) => return HttpResponse::NotFound().json(serde_json::json!({
            "success": false, "error": "Event not found"
        })),
        Err(e) => {
            tracing::error!("DB error: {e}");
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false, "error": "Database error"
            }));
        }
    };

    let new_date = body.event_date.as_deref()
        .and_then(|d| chrono::NaiveDate::parse_from_str(d, "%Y-%m-%d").ok())
        .unwrap_or(current.event_date);

    let new_start = body.start_time.as_deref()
        .and_then(|t| chrono::NaiveTime::parse_from_str(t, "%H:%M").ok())
        .or(current.start_time);

    let new_end = body.end_time.as_deref()
        .and_then(|t| chrono::NaiveTime::parse_from_str(t, "%H:%M").ok())
        .or(current.end_time);

    match sqlx::query_as::<_, CeremonyEvent>(
        "UPDATE ceremony_events SET day_number=$1, title=$2, hindi_title=$3, description=$4, \
         event_date=$5, start_time=$6, end_time=$7, venue=$8, venue_map_url=$9, \
         dress_code=$10, category=$11, banner_url=$12, icon_emoji=$13, sort_order=$14, \
         is_active=$15, updated_at=NOW() WHERE id=$16 RETURNING *"
    )
    .bind(body.day_number.unwrap_or(current.day_number))
    .bind(body.title.as_deref().unwrap_or(&current.title))
    .bind(body.hindi_title.as_deref().unwrap_or(&current.hindi_title))
    .bind(body.description.as_deref().unwrap_or(&current.description))
    .bind(new_date)
    .bind(new_start)
    .bind(new_end)
    .bind(body.venue.as_deref().unwrap_or(&current.venue))
    .bind(body.venue_map_url.as_deref().unwrap_or(&current.venue_map_url))
    .bind(body.dress_code.as_deref().unwrap_or(&current.dress_code))
    .bind(body.category.as_deref().unwrap_or(&current.category))
    .bind(body.banner_url.as_deref().unwrap_or(&current.banner_url))
    .bind(body.icon_emoji.as_deref().unwrap_or(&current.icon_emoji))
    .bind(body.sort_order.unwrap_or(current.sort_order))
    .bind(body.is_active.unwrap_or(current.is_active))
    .bind(event_id)
    .fetch_one(pool.get_ref())
    .await
    {
        Ok(updated) => {
            let _ = cache.del("events:all").await;
            HttpResponse::Ok().json(serde_json::json!({
                "success": true,
                "data": updated,
            }))
        }
        Err(e) => {
            tracing::error!("Failed to patch event: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false, "error": "Failed to update event"
            }))
        }
    }
}

/// DELETE /api/admin/events/{id}
#[delete("/api/admin/events/{id}")]
pub async fn admin_delete_event(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    cache: web::Data<RedisCache>,
    path: web::Path<i32>,
) -> HttpResponse {
    if let Err(_) = extract_admin(&req, &pool).await {
        return HttpResponse::Forbidden().json(serde_json::json!({
            "success": false, "error": "Admin access required"
        }));
    }

    let event_id = path.into_inner();
    let _ = sqlx::query("DELETE FROM ceremony_events WHERE id = $1")
        .bind(event_id)
        .execute(pool.get_ref())
        .await;

    let _ = cache.del("events:all").await;

    HttpResponse::Ok().json(serde_json::json!({ "success": true }))
}

// ═══════════════════════════════════════════════
// ADMIN — Announcements
// ═══════════════════════════════════════════════

/// POST /api/admin/announcements
#[post("/api/admin/announcements")]
pub async fn admin_create_announcement(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    cache: web::Data<RedisCache>,
    nats: web::Data<Option<NatsBroker>>,
    body: web::Json<AdminCreateAnnouncementRequest>,
) -> HttpResponse {
    let admin = match extract_admin(&req, &pool).await {
        Ok(a) => a,
        Err(_) => return HttpResponse::Forbidden().json(serde_json::json!({
            "success": false, "error": "Admin access required"
        })),
    };

    match sqlx::query_as::<_, Announcement>(
        "INSERT INTO announcements (title, message, category, priority, target_day, created_by) \
         VALUES ($1, $2, $3, $4, $5, $6) RETURNING *"
    )
    .bind(&body.title)
    .bind(&body.message)
    .bind(body.category.as_deref().unwrap_or("general"))
    .bind(body.priority.unwrap_or(0))
    .bind(body.target_day)
    .bind(admin.id)
    .fetch_one(pool.get_ref())
    .await
    {
        Ok(ann) => {
            let _ = cache.del("announcements:active").await;

            // Publish to NATS for real-time delivery
            if let Some(n) = nats.as_ref() { let _ = n.publish(subjects::ANNOUNCEMENT_NEW, &serde_json::json!({
                "id": ann.id,
                "title": ann.title,
                "priority": ann.priority,
            })).await; }

            HttpResponse::Created().json(serde_json::json!({
                "success": true,
                "data": ann,
            }))
        }
        Err(e) => {
            tracing::error!("Failed to create announcement: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false, "error": "Failed to create announcement"
            }))
        }
    }
}

/// PATCH /api/admin/announcements/{id}
#[patch("/api/admin/announcements/{id}")]
pub async fn admin_patch_announcement(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    cache: web::Data<RedisCache>,
    path: web::Path<i32>,
    body: web::Json<AdminPatchAnnouncementRequest>,
) -> HttpResponse {
    if let Err(_) = extract_admin(&req, &pool).await {
        return HttpResponse::Forbidden().json(serde_json::json!({
            "success": false, "error": "Admin access required"
        }));
    }

    let ann_id = path.into_inner();
    let current = match sqlx::query_as::<_, Announcement>(
        "SELECT * FROM announcements WHERE id = $1"
    ).bind(ann_id).fetch_optional(pool.get_ref()).await {
        Ok(Some(a)) => a,
        Ok(None) => return HttpResponse::NotFound().json(serde_json::json!({
            "success": false, "error": "Announcement not found"
        })),
        Err(_) => return HttpResponse::InternalServerError().json(serde_json::json!({
            "success": false, "error": "Database error"
        })),
    };

    match sqlx::query_as::<_, Announcement>(
        "UPDATE announcements SET title=$1, message=$2, category=$3, priority=$4, \
         is_active=$5, target_day=$6, updated_at=NOW() WHERE id=$7 RETURNING *"
    )
    .bind(body.title.as_deref().unwrap_or(&current.title))
    .bind(body.message.as_deref().unwrap_or(&current.message))
    .bind(body.category.as_deref().unwrap_or(&current.category))
    .bind(body.priority.unwrap_or(current.priority))
    .bind(body.is_active.unwrap_or(current.is_active))
    .bind(body.target_day.or(current.target_day))
    .bind(ann_id)
    .fetch_one(pool.get_ref())
    .await
    {
        Ok(updated) => {
            let _ = cache.del("announcements:active").await;
            HttpResponse::Ok().json(serde_json::json!({
                "success": true,
                "data": updated,
            }))
        }
        Err(e) => {
            tracing::error!("Failed to patch announcement: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false, "error": "Failed to update announcement"
            }))
        }
    }
}

/// DELETE /api/admin/announcements/{id}
#[delete("/api/admin/announcements/{id}")]
pub async fn admin_delete_announcement(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    cache: web::Data<RedisCache>,
    path: web::Path<i32>,
) -> HttpResponse {
    if let Err(_) = extract_admin(&req, &pool).await {
        return HttpResponse::Forbidden().json(serde_json::json!({
            "success": false, "error": "Admin access required"
        }));
    }

    let _ = sqlx::query("DELETE FROM announcements WHERE id = $1")
        .bind(path.into_inner())
        .execute(pool.get_ref())
        .await;

    let _ = cache.del("announcements:active").await;
    HttpResponse::Ok().json(serde_json::json!({ "success": true }))
}

// ═══════════════════════════════════════════════
// ADMIN — RSVP Summary
// ═══════════════════════════════════════════════

/// GET /api/admin/rsvp-summary
#[get("/api/admin/rsvp-summary")]
pub async fn admin_rsvp_summary(
    req: HttpRequest,
    pool: web::Data<PgPool>,
) -> HttpResponse {
    if let Err(_) = extract_admin(&req, &pool).await {
        return HttpResponse::Forbidden().json(serde_json::json!({
            "success": false, "error": "Admin access required"
        }));
    }

    match sqlx::query_as::<_, RsvpSummary>(
        "SELECT e.id as event_id, e.title as event_title, \
         COALESCE(SUM(CASE WHEN r.status='attending' THEN r.guest_count ELSE 0 END), 0) as attending, \
         COALESCE(SUM(CASE WHEN r.status='not_attending' THEN 1 ELSE 0 END), 0) as not_attending, \
         COALESCE(SUM(CASE WHEN r.status='maybe' THEN 1 ELSE 0 END), 0) as maybe, \
         COALESCE(SUM(CASE WHEN r.status='pending' THEN 1 ELSE 0 END), 0) as pending, \
         COALESCE(SUM(r.guest_count), 0) as total_guests \
         FROM ceremony_events e \
         LEFT JOIN rsvp_responses r ON r.event_id = e.id \
         WHERE e.is_active = TRUE \
         GROUP BY e.id, e.title \
         ORDER BY e.day_number, e.sort_order"
    )
    .fetch_all(pool.get_ref())
    .await
    {
        Ok(summary) => HttpResponse::Ok().json(serde_json::json!({
            "success": true,
            "data": summary,
        })),
        Err(e) => {
            tracing::error!("Failed to get RSVP summary: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false, "error": "Failed to load RSVP summary"
            }))
        }
    }
}

// ═══════════════════════════════════════════════
// ADMIN — Send Notification
// ═══════════════════════════════════════════════

/// POST /api/admin/notify — send notification to all or specific guests
#[post("/api/admin/notify")]
pub async fn admin_send_notification(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    nats: web::Data<Option<NatsBroker>>,
    body: web::Json<AdminSendNotificationRequest>,
) -> HttpResponse {
    if let Err(_) = extract_admin(&req, &pool).await {
        return HttpResponse::Forbidden().json(serde_json::json!({
            "success": false, "error": "Admin access required"
        }));
    }

    let ntype = body.notification_type.as_deref().unwrap_or("announcement");

    // Determine target guests
    let guest_ids: Vec<uuid::Uuid> = if let Some(ref ids) = body.guest_ids {
        ids.clone()
    } else {
        // All guests
        sqlx::query_scalar::<_, uuid::Uuid>("SELECT id FROM guests WHERE status != 'declined'")
            .fetch_all(pool.get_ref())
            .await
            .unwrap_or_default()
    };

    let mut count = 0;
    for gid in &guest_ids {
        let result = sqlx::query(
            "INSERT INTO notifications (guest_id, title, body, notification_type) VALUES ($1, $2, $3, $4)"
        )
        .bind(gid)
        .bind(&body.title)
        .bind(&body.body)
        .bind(ntype)
        .execute(pool.get_ref())
        .await;

        if result.is_ok() {
            count += 1;
        }
    }

    // Publish to NATS for push notification delivery
    if let Some(n) = nats.as_ref() { let _ = n.publish(subjects::NOTIFICATION_PUSH, &serde_json::json!({
        "title": body.title,
        "body": body.body,
        "guest_count": count,
    })).await; }

    HttpResponse::Ok().json(serde_json::json!({
        "success": true,
        "notifications_sent": count,
    }))
}

// ═══════════════════════════════════════════════
// ADMIN — Media Moderation
// ═══════════════════════════════════════════════

/// GET /api/admin/media/pending — media awaiting approval
#[get("/api/admin/media/pending")]
pub async fn admin_pending_media(
    req: HttpRequest,
    pool: web::Data<PgPool>,
) -> HttpResponse {
    if let Err(_) = extract_admin(&req, &pool).await {
        return HttpResponse::Forbidden().json(serde_json::json!({
            "success": false, "error": "Admin access required"
        }));
    }

    match sqlx::query_as::<_, MediaItem>(
        "SELECT * FROM media_items WHERE is_approved = FALSE ORDER BY created_at"
    )
    .fetch_all(pool.get_ref())
    .await
    {
        Ok(items) => HttpResponse::Ok().json(serde_json::json!({
            "success": true,
            "data": items,
        })),
        Err(e) => {
            tracing::error!("Failed to list pending media: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false, "error": "Failed to load media"
            }))
        }
    }
}

/// PATCH /api/admin/media/{id} — approve/reject/feature media
#[patch("/api/admin/media/{id}")]
pub async fn admin_patch_media(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    path: web::Path<i32>,
    body: web::Json<serde_json::Value>,
) -> HttpResponse {
    if let Err(_) = extract_admin(&req, &pool).await {
        return HttpResponse::Forbidden().json(serde_json::json!({
            "success": false, "error": "Admin access required"
        }));
    }

    let media_id = path.into_inner();

    if let Some(approved) = body.get("is_approved").and_then(|v| v.as_bool()) {
        let _ = sqlx::query("UPDATE media_items SET is_approved = $1 WHERE id = $2")
            .bind(approved).bind(media_id).execute(pool.get_ref()).await;
    }

    if let Some(featured) = body.get("is_featured").and_then(|v| v.as_bool()) {
        let _ = sqlx::query("UPDATE media_items SET is_featured = $1 WHERE id = $2")
            .bind(featured).bind(media_id).execute(pool.get_ref()).await;
    }

    HttpResponse::Ok().json(serde_json::json!({ "success": true }))
}

// ═══════════════════════════════════════════════
// ADMIN — Group Chat Management
// ═══════════════════════════════════════════════

/// POST /api/admin/chat/broadcast — send a message in the family group from admin
#[post("/api/admin/chat/broadcast")]
pub async fn admin_broadcast_message(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    nats: web::Data<Option<NatsBroker>>,
    body: web::Json<AdminBroadcastRequest>,
) -> HttpResponse {
    let admin = match extract_admin(&req, &pool).await {
        Ok(a) => a,
        Err(_) => return HttpResponse::Forbidden().json(serde_json::json!({
            "success": false, "error": "Admin access required"
        })),
    };

    let family_group_id: uuid::Uuid = "00000000-0000-0000-0000-000000000001"
        .parse().unwrap();

    // Insert broadcast message as a chat message from admin
    match sqlx::query_scalar::<_, i32>(
        "INSERT INTO chat_messages (room_id, sender_id, message_type, content) \
         VALUES ($1, $2, $3, $4) RETURNING id"
    )
    .bind(family_group_id)
    .bind(admin.id)
    .bind(body.message_type.as_deref().unwrap_or("text"))
    .bind(&body.message)
    .fetch_one(pool.get_ref())
    .await
    {
        Ok(msg_id) => {
            // Update room timestamp
            let _ = sqlx::query("UPDATE chat_rooms SET updated_at = NOW() WHERE id = $1")
                .bind(family_group_id).execute(pool.get_ref()).await;

            // Notify via NATS for real-time delivery
            if let Some(n) = nats.as_ref() { let _ = n.publish("sanskar.chat.broadcast", &serde_json::json!({
                "room_id": family_group_id,
                "message_id": msg_id,
                "sender_name": admin.name,
                "content": body.message,
            })).await; }

            HttpResponse::Ok().json(serde_json::json!({
                "success": true,
                "message_id": msg_id,
            }))
        }
        Err(e) => {
            tracing::error!("Failed to broadcast: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false, "error": "Failed to broadcast message"
            }))
        }
    }
}

/// POST /api/admin/chat/event-group — create a group chat for a ceremony event with all guests
#[post("/api/admin/chat/event-group")]
pub async fn admin_create_event_group(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    body: web::Json<AdminEventGroupRequest>,
) -> HttpResponse {
    let admin = match extract_admin(&req, &pool).await {
        Ok(a) => a,
        Err(_) => return HttpResponse::Forbidden().json(serde_json::json!({
            "success": false, "error": "Admin access required"
        })),
    };

    // Get the event
    let event = match sqlx::query_as::<_, CeremonyEvent>(
        "SELECT * FROM ceremony_events WHERE id = $1"
    ).bind(body.event_id).fetch_optional(pool.get_ref()).await {
        Ok(Some(e)) => e,
        Ok(None) => return HttpResponse::NotFound().json(serde_json::json!({
            "success": false, "error": "Event not found"
        })),
        Err(_) => return HttpResponse::InternalServerError().json(serde_json::json!({
            "success": false, "error": "Database error"
        })),
    };

    // Create group chat for this event
    let room_id = uuid::Uuid::new_v4();
    let room_name = format!("{} {}", event.icon_emoji, event.title);

    let _ = sqlx::query(
        "INSERT INTO chat_rooms (id, room_type, name, event_id, created_by) VALUES ($1, 'event', $2, $3, $4)"
    )
    .bind(room_id)
    .bind(&room_name)
    .bind(body.event_id)
    .bind(admin.id)
    .execute(pool.get_ref())
    .await;

    // Add admin
    let _ = sqlx::query(
        "INSERT INTO chat_room_members (room_id, guest_id, role) VALUES ($1, $2, 'admin')"
    ).bind(room_id).bind(admin.id).execute(pool.get_ref()).await;

    // Add all active guests
    let guest_ids: Vec<uuid::Uuid> = sqlx::query_scalar(
        "SELECT id FROM guests WHERE status != 'declined'"
    ).fetch_all(pool.get_ref()).await.unwrap_or_default();

    let mut enrolled = 0;
    for gid in &guest_ids {
        let r = sqlx::query(
            "INSERT INTO chat_room_members (room_id, guest_id) VALUES ($1, $2) ON CONFLICT DO NOTHING"
        ).bind(room_id).bind(gid).execute(pool.get_ref()).await;
        if r.is_ok() { enrolled += 1; }
    }

    // Post a system message
    let _ = sqlx::query(
        "INSERT INTO chat_messages (room_id, sender_id, message_type, content) \
         VALUES ($1, $2, 'system', $3)"
    )
    .bind(room_id)
    .bind(admin.id)
    .bind(format!("🕉️ Group created for '{}'. {} guests enrolled.", event.title, enrolled))
    .execute(pool.get_ref())
    .await;

    HttpResponse::Created().json(serde_json::json!({
        "success": true,
        "room_id": room_id,
        "room_name": room_name,
        "members_enrolled": enrolled,
    }))
}

/// POST /api/admin/chat/enroll-all — enroll all guests into the family group
#[post("/api/admin/chat/enroll-all")]
pub async fn admin_enroll_all_to_family(
    req: HttpRequest,
    pool: web::Data<PgPool>,
) -> HttpResponse {
    if let Err(_) = extract_admin(&req, &pool).await {
        return HttpResponse::Forbidden().json(serde_json::json!({
            "success": false, "error": "Admin access required"
        }));
    }

    let family_group_id: uuid::Uuid = "00000000-0000-0000-0000-000000000001"
        .parse().unwrap();

    let guest_ids: Vec<uuid::Uuid> = sqlx::query_scalar(
        "SELECT id FROM guests WHERE status != 'declined'"
    ).fetch_all(pool.get_ref()).await.unwrap_or_default();

    let mut enrolled = 0;
    for gid in &guest_ids {
        let r = sqlx::query(
            "INSERT INTO chat_room_members (room_id, guest_id, role) \
             VALUES ($1, $2, 'member') ON CONFLICT (room_id, guest_id) DO NOTHING"
        ).bind(family_group_id).bind(gid).execute(pool.get_ref()).await;
        if r.is_ok() { enrolled += 1; }
    }

    HttpResponse::Ok().json(serde_json::json!({
        "success": true,
        "enrolled": enrolled,
        "total_guests": guest_ids.len(),
    }))
}
