use actix_web::{get, post, put, web, HttpRequest, HttpResponse};
use sqlx::PgPool;
use uuid::Uuid;

use crate::auth::middleware::extract_guest;
use crate::broker::{NatsBroker, subjects};
use crate::models::chat::*;

/// GET /api/chat/rooms — list my chat rooms with previews
#[get("/api/chat/rooms")]
pub async fn list_rooms(
    req: HttpRequest,
    pool: web::Data<PgPool>,
) -> HttpResponse {
    let guest = match extract_guest(&req, &pool).await {
        Ok(g) => g,
        Err(_) => return HttpResponse::Unauthorized().json(serde_json::json!({
            "success": false, "error": "Not authenticated"
        })),
    };

    // Get rooms the guest is a member of, with last message preview
    match sqlx::query_as::<_, ChatRoom>(
        "SELECT cr.* FROM chat_rooms cr \
         INNER JOIN chat_room_members crm ON crm.room_id = cr.id \
         WHERE crm.guest_id = $1 AND cr.is_active = TRUE \
         ORDER BY cr.updated_at DESC"
    )
    .bind(guest.id)
    .fetch_all(pool.get_ref())
    .await
    {
        Ok(rooms) => {
            // Build previews with unread counts
            let mut previews = Vec::new();
            for room in rooms {
                // Get last message
                let last_msg = sqlx::query_as::<_, ChatMessageView>(
                    "SELECT cm.id, cm.room_id, cm.sender_id, g.name as sender_name, \
                     g.avatar_url as sender_avatar, cm.message_type, cm.content, \
                     cm.media_url, cm.thumbnail_url, cm.reply_to_id, \
                     cm.is_edited, cm.is_deleted, cm.created_at \
                     FROM chat_messages cm \
                     JOIN guests g ON g.id = cm.sender_id \
                     WHERE cm.room_id = $1 AND cm.is_deleted = FALSE \
                     ORDER BY cm.created_at DESC LIMIT 1"
                )
                .bind(room.id)
                .fetch_optional(pool.get_ref())
                .await
                .ok()
                .flatten();

                // Get unread count
                let unread: i64 = sqlx::query_scalar(
                    "SELECT COUNT(*) FROM chat_messages cm \
                     WHERE cm.room_id = $1 \
                     AND cm.created_at > (
                       SELECT COALESCE(last_read_at, '1970-01-01'::timestamptz) \
                       FROM chat_room_members WHERE room_id = $1 AND guest_id = $2
                     ) \
                     AND cm.sender_id != $2 \
                     AND cm.is_deleted = FALSE"
                )
                .bind(room.id)
                .bind(guest.id)
                .fetch_one(pool.get_ref())
                .await
                .unwrap_or(0);

                // For direct chats, show other person's name
                let display_name = if room.room_type == "direct" {
                    sqlx::query_scalar::<_, String>(
                        "SELECT g.name FROM chat_room_members crm \
                         JOIN guests g ON g.id = crm.guest_id \
                         WHERE crm.room_id = $1 AND crm.guest_id != $2 LIMIT 1"
                    )
                    .bind(room.id)
                    .bind(guest.id)
                    .fetch_optional(pool.get_ref())
                    .await
                    .ok()
                    .flatten()
                    .unwrap_or(room.name.clone())
                } else {
                    room.name.clone()
                };

                previews.push(ChatRoomPreview {
                    id: room.id,
                    room_type: room.room_type,
                    name: display_name,
                    avatar_url: room.avatar_url,
                    last_message: last_msg.as_ref().map(|m| {
                        if m.is_deleted { "Message deleted".to_string() }
                        else if m.message_type == "text" { m.content.clone() }
                        else { format!("📎 {}", m.message_type) }
                    }),
                    last_message_at: last_msg.as_ref().map(|m| m.created_at),
                    last_sender_name: last_msg.as_ref().map(|m| m.sender_name.clone()),
                    unread_count: unread,
                });
            }

            HttpResponse::Ok().json(serde_json::json!({
                "success": true,
                "data": previews,
            }))
        }
        Err(e) => {
            tracing::error!("Failed to list chat rooms: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false, "error": "Failed to load chats"
            }))
        }
    }
}

/// POST /api/chat/rooms/direct — create or get a 1-on-1 chat
#[post("/api/chat/rooms/direct")]
pub async fn create_direct_chat(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    body: web::Json<CreateDirectChatRequest>,
) -> HttpResponse {
    let guest = match extract_guest(&req, &pool).await {
        Ok(g) => g,
        Err(_) => return HttpResponse::Unauthorized().json(serde_json::json!({
            "success": false, "error": "Not authenticated"
        })),
    };

    // Check if direct chat already exists between these two
    let existing: Option<(Uuid,)> = sqlx::query_as(
        "SELECT cr.id FROM chat_rooms cr \
         WHERE cr.room_type = 'direct' AND cr.is_active = TRUE \
         AND EXISTS (SELECT 1 FROM chat_room_members WHERE room_id = cr.id AND guest_id = $1) \
         AND EXISTS (SELECT 1 FROM chat_room_members WHERE room_id = cr.id AND guest_id = $2)"
    )
    .bind(guest.id)
    .bind(body.guest_id)
    .fetch_optional(pool.get_ref())
    .await
    .ok()
    .flatten();

    if let Some((room_id,)) = existing {
        return HttpResponse::Ok().json(serde_json::json!({
            "success": true,
            "room_id": room_id,
            "existing": true,
        }));
    }

    // Create new direct chat
    let room_id = Uuid::new_v4();
    let _ = sqlx::query("INSERT INTO chat_rooms (id, room_type, created_by) VALUES ($1, 'direct', $2)")
        .bind(room_id).bind(guest.id).execute(pool.get_ref()).await;

    let _ = sqlx::query("INSERT INTO chat_room_members (room_id, guest_id, role) VALUES ($1, $2, 'admin')")
        .bind(room_id).bind(guest.id).execute(pool.get_ref()).await;
    let _ = sqlx::query("INSERT INTO chat_room_members (room_id, guest_id, role) VALUES ($1, $2, 'member')")
        .bind(room_id).bind(body.guest_id).execute(pool.get_ref()).await;

    HttpResponse::Created().json(serde_json::json!({
        "success": true,
        "room_id": room_id,
        "existing": false,
    }))
}

/// POST /api/chat/rooms/group — create a group chat
#[post("/api/chat/rooms/group")]
pub async fn create_group_chat(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    body: web::Json<CreateGroupChatRequest>,
) -> HttpResponse {
    let guest = match extract_guest(&req, &pool).await {
        Ok(g) => g,
        Err(_) => return HttpResponse::Unauthorized().json(serde_json::json!({
            "success": false, "error": "Not authenticated"
        })),
    };

    let room_id = Uuid::new_v4();
    let _ = sqlx::query(
        "INSERT INTO chat_rooms (id, room_type, name, created_by) VALUES ($1, 'group', $2, $3)"
    )
    .bind(room_id).bind(&body.name).bind(guest.id)
    .execute(pool.get_ref()).await;

    // Add creator as admin
    let _ = sqlx::query("INSERT INTO chat_room_members (room_id, guest_id, role) VALUES ($1, $2, 'admin')")
        .bind(room_id).bind(guest.id).execute(pool.get_ref()).await;

    // Add other members
    for mid in &body.member_ids {
        let _ = sqlx::query("INSERT INTO chat_room_members (room_id, guest_id) VALUES ($1, $2) ON CONFLICT DO NOTHING")
            .bind(room_id).bind(mid).execute(pool.get_ref()).await;
    }

    HttpResponse::Created().json(serde_json::json!({
        "success": true,
        "room_id": room_id,
    }))
}

/// GET /api/chat/rooms/{room_id}/messages — get messages (paginated)
#[get("/api/chat/rooms/{room_id}/messages")]
pub async fn get_messages(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    path: web::Path<Uuid>,
    query: web::Query<ChatMessagesQuery>,
) -> HttpResponse {
    let guest = match extract_guest(&req, &pool).await {
        Ok(g) => g,
        Err(_) => return HttpResponse::Unauthorized().json(serde_json::json!({
            "success": false, "error": "Not authenticated"
        })),
    };

    let room_id = path.into_inner();
    let limit = query.limit.unwrap_or(50).min(100) as i64;

    // Verify membership
    let is_member: Option<(i32,)> = sqlx::query_as(
        "SELECT id FROM chat_room_members WHERE room_id = $1 AND guest_id = $2"
    )
    .bind(room_id).bind(guest.id)
    .fetch_optional(pool.get_ref()).await.ok().flatten();

    if is_member.is_none() {
        return HttpResponse::Forbidden().json(serde_json::json!({
            "success": false, "error": "Not a member of this chat"
        }));
    }

    let mut sql = String::from(
        "SELECT cm.id, cm.room_id, cm.sender_id, g.name as sender_name, \
         g.avatar_url as sender_avatar, cm.message_type, cm.content, \
         cm.media_url, cm.thumbnail_url, cm.reply_to_id, \
         cm.is_edited, cm.is_deleted, cm.created_at \
         FROM chat_messages cm \
         JOIN guests g ON g.id = cm.sender_id \
         WHERE cm.room_id = $1"
    );

    if let Some(before) = query.before_id {
        sql.push_str(&format!(" AND cm.id < {}", before));
    }
    sql.push_str(&format!(" ORDER BY cm.created_at DESC LIMIT {}", limit));

    match sqlx::query_as::<_, ChatMessageView>(&sql)
        .bind(room_id)
        .fetch_all(pool.get_ref())
        .await
    {
        Ok(messages) => {
            // Update last_read_at
            let _ = sqlx::query(
                "UPDATE chat_room_members SET last_read_at = NOW() WHERE room_id = $1 AND guest_id = $2"
            )
            .bind(room_id).bind(guest.id)
            .execute(pool.get_ref()).await;

            HttpResponse::Ok().json(serde_json::json!({
                "success": true,
                "data": messages,
            }))
        }
        Err(e) => {
            tracing::error!("Failed to get messages: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false, "error": "Failed to load messages"
            }))
        }
    }
}

/// POST /api/chat/rooms/{room_id}/messages — send a message
#[post("/api/chat/rooms/{room_id}/messages")]
pub async fn send_message(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    nats: web::Data<Option<NatsBroker>>,
    path: web::Path<Uuid>,
    body: web::Json<SendMessageRequest>,
) -> HttpResponse {
    let guest = match extract_guest(&req, &pool).await {
        Ok(g) => g,
        Err(_) => return HttpResponse::Unauthorized().json(serde_json::json!({
            "success": false, "error": "Not authenticated"
        })),
    };

    let room_id = path.into_inner();

    // Verify membership
    let is_member: Option<(i32,)> = sqlx::query_as(
        "SELECT id FROM chat_room_members WHERE room_id = $1 AND guest_id = $2"
    )
    .bind(room_id).bind(guest.id)
    .fetch_optional(pool.get_ref()).await.ok().flatten();

    if is_member.is_none() {
        return HttpResponse::Forbidden().json(serde_json::json!({
            "success": false, "error": "Not a member of this chat"
        }));
    }

    let msg_type = body.message_type.as_deref().unwrap_or("text");

    match sqlx::query_as::<_, ChatMessage>(
        "INSERT INTO chat_messages (room_id, sender_id, message_type, content, media_url, thumbnail_url, reply_to_id) \
         VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *"
    )
    .bind(room_id)
    .bind(guest.id)
    .bind(msg_type)
    .bind(&body.content)
    .bind(body.media_url.as_deref().unwrap_or(""))
    .bind(body.thumbnail_url.as_deref().unwrap_or(""))
    .bind(body.reply_to_id)
    .fetch_one(pool.get_ref())
    .await
    {
        Ok(msg) => {
            // Update room's updated_at
            let _ = sqlx::query("UPDATE chat_rooms SET updated_at = NOW() WHERE id = $1")
                .bind(room_id).execute(pool.get_ref()).await;

            // Update sender's last_read_at
            let _ = sqlx::query(
                "UPDATE chat_room_members SET last_read_at = NOW() WHERE room_id = $1 AND guest_id = $2"
            )
            .bind(room_id).bind(guest.id)
            .execute(pool.get_ref()).await;

            // Publish for real-time delivery via WebSocket
            if let Some(n) = nats.as_ref() { let _ = n.publish("sanskar.chat.message", &serde_json::json!({
                "room_id": room_id,
                "message_id": msg.id,
                "sender_id": guest.id,
                "sender_name": guest.name,
                "message_type": msg.message_type,
                "content": msg.content,
            })).await; }

            HttpResponse::Created().json(serde_json::json!({
                "success": true,
                "data": msg,
            }))
        }
        Err(e) => {
            tracing::error!("Failed to send message: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false, "error": "Failed to send message"
            }))
        }
    }
}

/// POST /api/chat/calls — initiate an audio/video call
#[post("/api/chat/calls")]
pub async fn initiate_call(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    nats: web::Data<Option<NatsBroker>>,
    body: web::Json<InitiateCallRequest>,
) -> HttpResponse {
    let guest = match extract_guest(&req, &pool).await {
        Ok(g) => g,
        Err(_) => return HttpResponse::Unauthorized().json(serde_json::json!({
            "success": false, "error": "Not authenticated"
        })),
    };

    let call_id = uuid::Uuid::new_v4();

    match sqlx::query_as::<_, CallLog>(
        "INSERT INTO call_logs (id, caller_id, call_type) VALUES ($1, $2, $3) RETURNING *"
    )
    .bind(call_id)
    .bind(guest.id)
    .bind(&body.call_type)
    .fetch_one(pool.get_ref())
    .await
    {
        Ok(call) => {
            // Add caller as participant
            let _ = sqlx::query(
                "INSERT INTO call_participants (call_id, guest_id, status, joined_at) VALUES ($1, $2, 'joined', NOW())"
            )
            .bind(call_id).bind(guest.id)
            .execute(pool.get_ref()).await;

            // Add invitees
            for pid in &body.participant_ids {
                let _ = sqlx::query(
                    "INSERT INTO call_participants (call_id, guest_id, status) VALUES ($1, $2, 'invited') ON CONFLICT DO NOTHING"
                )
                .bind(call_id).bind(pid)
                .execute(pool.get_ref()).await;
            }

            // Notify via NATS
            if let Some(n) = nats.as_ref() { let _ = n.publish("sanskar.chat.call", &serde_json::json!({
                "call_id": call_id,
                "caller_id": guest.id,
                "caller_name": guest.name,
                "call_type": body.call_type,
                "participant_ids": body.participant_ids,
            })).await; }

            HttpResponse::Created().json(serde_json::json!({
                "success": true,
                "call": call,
            }))
        }
        Err(e) => {
            tracing::error!("Failed to initiate call: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false, "error": "Failed to initiate call"
            }))
        }
    }
}

/// GET /api/chat/calls — call history
#[get("/api/chat/calls")]
pub async fn call_history(
    req: HttpRequest,
    pool: web::Data<PgPool>,
) -> HttpResponse {
    let guest = match extract_guest(&req, &pool).await {
        Ok(g) => g,
        Err(_) => return HttpResponse::Unauthorized().json(serde_json::json!({
            "success": false, "error": "Not authenticated"
        })),
    };

    match sqlx::query_as::<_, CallLog>(
        "SELECT cl.* FROM call_logs cl \
         INNER JOIN call_participants cp ON cp.call_id = cl.id \
         WHERE cp.guest_id = $1 \
         ORDER BY cl.created_at DESC LIMIT 50"
    )
    .bind(guest.id)
    .fetch_all(pool.get_ref())
    .await
    {
        Ok(calls) => HttpResponse::Ok().json(serde_json::json!({
            "success": true,
            "data": calls,
        })),
        Err(e) => {
            tracing::error!("Failed to get call history: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false, "error": "Failed to load call history"
            }))
        }
    }
}
