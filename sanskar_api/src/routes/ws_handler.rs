/// WebSocket handler for real-time chat message delivery and presence.
///
/// Each connected client maintains a WebSocket connection authenticated via
/// a session token. Messages are broadcast to all members of a chat room
/// using an in-memory concurrent map of connections.

use actix_web::{get, web, HttpRequest, HttpResponse};
use actix_ws::Message;
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::{broadcast, RwLock};
use uuid::Uuid;

use crate::auth::invite_code;

// ═══════════════════════════════════════════════
// Types
// ═══════════════════════════════════════════════

/// A message that flows through the WebSocket broadcast channel.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum WsEvent {
    /// A new chat message was sent
    #[serde(rename = "chat_message")]
    ChatMessage {
        room_id: String,
        message_id: i32,
        sender_id: String,
        sender_name: String,
        content: String,
        message_type: String,
        timestamp: String,
    },

    /// User is typing
    #[serde(rename = "typing")]
    Typing {
        room_id: String,
        guest_id: String,
        guest_name: String,
    },

    /// Typing stopped
    #[serde(rename = "typing_stop")]
    TypingStop {
        room_id: String,
        guest_id: String,
    },

    /// User presence update
    #[serde(rename = "presence")]
    Presence {
        guest_id: String,
        guest_name: String,
        status: String, // "online" | "offline"
    },

    /// New announcement broadcast
    #[serde(rename = "announcement")]
    Announcement {
        id: i32,
        title: String,
        message: String,
        priority: i32,
        category: String,
    },

    /// WebRTC signaling
    #[serde(rename = "rtc_signal")]
    RtcSignal {
        from_id: String,
        to_id: String,
        signal_type: String, // "offer" | "answer" | "ice_candidate"
        payload: serde_json::Value,
    },

    /// Call invitation
    #[serde(rename = "call_invite")]
    CallInvite {
        call_id: String,
        caller_id: String,
        caller_name: String,
        call_type: String, // "audio" | "video"
        room_id: String,
    },

    /// Call response (accept/reject/end)
    #[serde(rename = "call_action")]
    CallAction {
        call_id: String,
        call_action: String, // "accept" | "reject" | "end"
        guest_id: String,
    },
}

/// Incoming message from client
#[derive(Debug, Deserialize)]
#[serde(tag = "action")]
pub enum WsClientAction {
    #[serde(rename = "send_message")]
    SendMessage {
        room_id: String,
        content: String,
        message_type: Option<String>,
    },

    #[serde(rename = "typing")]
    Typing { room_id: String },

    #[serde(rename = "typing_stop")]
    TypingStop { room_id: String },

    #[serde(rename = "rtc_signal")]
    RtcSignal {
        to_id: String,
        signal_type: String,
        payload: serde_json::Value,
    },

    #[serde(rename = "call_invite")]
    CallInvite {
        to_id: String,
        call_type: String,
        room_id: String,
    },

    #[serde(rename = "call_action")]
    CallAction {
        call_id: String,
        call_action: String,
    },
}

/// Connection info for a connected guest
struct ConnectedGuest {
    guest_id: Uuid,
    guest_name: String,
    room_ids: Vec<Uuid>,
}

/// The shared state for all WebSocket connections.
pub struct WsState {
    /// Broadcast channel for all events
    pub tx: broadcast::Sender<WsEvent>,
    /// Map of guest_id → list of room_ids they belong to (cache)
    pub guest_rooms: RwLock<HashMap<Uuid, Vec<Uuid>>>,
    /// Online guests for presence tracking
    pub online: RwLock<HashMap<Uuid, String>>,
}

impl WsState {
    pub fn new() -> Self {
        let (tx, _) = broadcast::channel(1024);
        Self {
            tx,
            guest_rooms: RwLock::new(HashMap::new()),
            online: RwLock::new(HashMap::new()),
        }
    }
}

// ═══════════════════════════════════════════════
// WebSocket endpoint
// ═══════════════════════════════════════════════

/// GET /ws?token=<session_token>
/// Upgrades to WebSocket for real-time chat/calls/announcements.
#[get("/ws")]
pub async fn ws_handler(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    ws_state: web::Data<Arc<WsState>>,
    query: web::Query<WsQuery>,
    body: web::Payload,
) -> Result<HttpResponse, actix_web::Error> {
    // Authenticate via token
    let guest = invite_code::validate_session(pool.get_ref(), &query.token)
        .await
        .map_err(|_| actix_web::error::ErrorUnauthorized("Invalid token"))?;

    let guest_id = guest.id;
    let guest_name = guest.name.clone();

    // Load guest's chat rooms
    let room_ids: Vec<Uuid> = sqlx::query_scalar::<_, Uuid>(
        "SELECT room_id FROM chat_room_members WHERE guest_id = $1"
    )
    .bind(guest_id)
    .fetch_all(pool.get_ref())
    .await
    .unwrap_or_default();

    // Cache room membership
    {
        let mut rooms = ws_state.guest_rooms.write().await;
        rooms.insert(guest_id, room_ids.clone());
    }

    // Mark online
    {
        let mut online = ws_state.online.write().await;
        online.insert(guest_id, guest_name.clone());
    }

    // Broadcast presence
    let _ = ws_state.tx.send(WsEvent::Presence {
        guest_id: guest_id.to_string(),
        guest_name: guest_name.clone(),
        status: "online".to_string(),
    });

    let (response, mut session, mut stream) = actix_ws::handle(&req, body)?;

    let tx = ws_state.tx.clone();
    let mut rx = ws_state.tx.subscribe();
    let pool_ref = pool.get_ref().clone();
    let ws_ref = ws_state.get_ref().clone();

    // Spawn the WebSocket actor
    actix_web::rt::spawn(async move {
        // Spawn a task to forward broadcast events to this client
        let mut session_clone = session.clone();
        let guest_rooms = room_ids.clone();
        let my_id = guest_id;
        let my_id_str = guest_id.to_string();

        let forward_task = actix_web::rt::spawn(async move {
            while let Ok(event) = rx.recv().await {
                let should_send = match &event {
                    WsEvent::ChatMessage { room_id, sender_id, .. } => {
                        sender_id != &my_id_str &&
                        guest_rooms.iter().any(|r| r.to_string() == *room_id)
                    }
                    WsEvent::Typing { room_id, guest_id, .. } |
                    WsEvent::TypingStop { room_id, guest_id, .. } => {
                        guest_id != &my_id_str &&
                        guest_rooms.iter().any(|r| r.to_string() == *room_id)
                    }
                    WsEvent::Presence { guest_id, .. } => {
                        guest_id != &my_id_str
                    }
                    WsEvent::Announcement { .. } => true,
                    WsEvent::RtcSignal { to_id, .. } => to_id == &my_id_str,
                    WsEvent::CallInvite { .. } => {
                        // Send to all in room for now
                        true
                    }
                    WsEvent::CallAction { .. } => true,
                };

                if should_send {
                    if let Ok(json) = serde_json::to_string(&event) {
                        if session_clone.text(json).await.is_err() {
                            break;
                        }
                    }
                }
            }
        });

        // Process incoming messages from this client
        while let Some(Ok(msg)) = stream.recv().await {
            match msg {
                Message::Text(text) => {
                    if let Ok(action) = serde_json::from_str::<WsClientAction>(&text) {
                        match action {
                            WsClientAction::SendMessage { room_id, content, message_type } => {
                                let msg_type = message_type.as_deref().unwrap_or("text");

                                // Persist to database
                                if let Ok(room_uuid) = room_id.parse::<Uuid>() {
                                    let msg_result = sqlx::query_scalar::<_, i32>(
                                        "INSERT INTO chat_messages (room_id, sender_id, message_type, content) \
                                         VALUES ($1, $2, $3, $4) RETURNING id"
                                    )
                                    .bind(room_uuid)
                                    .bind(guest_id)
                                    .bind(msg_type)
                                    .bind(&content)
                                    .fetch_one(&pool_ref)
                                    .await;

                                    if let Ok(msg_id) = msg_result {
                                        // Update room timestamp
                                        let _ = sqlx::query(
                                            "UPDATE chat_rooms SET updated_at = NOW() WHERE id = $1"
                                        ).bind(room_uuid).execute(&pool_ref).await;

                                        // Broadcast to all room members
                                        let _ = tx.send(WsEvent::ChatMessage {
                                            room_id: room_id.clone(),
                                            message_id: msg_id,
                                            sender_id: guest_id.to_string(),
                                            sender_name: guest_name.clone(),
                                            content,
                                            message_type: msg_type.to_string(),
                                            timestamp: chrono::Utc::now().to_rfc3339(),
                                        });
                                    }
                                }
                            }
                            WsClientAction::Typing { room_id } => {
                                let _ = tx.send(WsEvent::Typing {
                                    room_id,
                                    guest_id: guest_id.to_string(),
                                    guest_name: guest_name.clone(),
                                });
                            }
                            WsClientAction::TypingStop { room_id } => {
                                let _ = tx.send(WsEvent::TypingStop {
                                    room_id,
                                    guest_id: guest_id.to_string(),
                                });
                            }
                            WsClientAction::RtcSignal { to_id, signal_type, payload } => {
                                let _ = tx.send(WsEvent::RtcSignal {
                                    from_id: guest_id.to_string(),
                                    to_id,
                                    signal_type,
                                    payload,
                                });
                            }
                            WsClientAction::CallInvite { to_id, call_type, room_id } => {
                                let call_id = Uuid::new_v4().to_string();

                                // Log call in DB
                                let _ = sqlx::query(
                                    "INSERT INTO call_logs (room_id, initiated_by, call_type, status) \
                                     VALUES ($1::uuid, $2, $3, 'ringing')"
                                )
                                .bind(&room_id)
                                .bind(guest_id)
                                .bind(&call_type)
                                .execute(&pool_ref)
                                .await;

                                let _ = tx.send(WsEvent::CallInvite {
                                    call_id,
                                    caller_id: guest_id.to_string(),
                                    caller_name: guest_name.clone(),
                                    call_type,
                                    room_id,
                                });
                            }
                            WsClientAction::CallAction { call_id, call_action } => {
                                let _ = tx.send(WsEvent::CallAction {
                                    call_id,
                                    call_action,
                                    guest_id: guest_id.to_string(),
                                });
                            }
                        }
                    }
                }
                Message::Ping(bytes) => {
                    let _ = session.pong(&bytes).await;
                }
                Message::Close(_) => break,
                _ => {}
            }
        }

        // Cleanup on disconnect
        forward_task.abort();

        // Mark offline
        {
            let mut online = ws_ref.online.write().await;
            online.remove(&guest_id);
        }
        {
            let mut rooms = ws_ref.guest_rooms.write().await;
            rooms.remove(&guest_id);
        }

        // Broadcast offline presence
        let _ = tx.send(WsEvent::Presence {
            guest_id: guest_id.to_string(),
            guest_name,
            status: "offline".to_string(),
        });

        let _ = session.close(None).await;
    });

    Ok(response)
}

/// GET /api/online — list currently online guests
#[get("/api/online")]
pub async fn list_online(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    ws_state: web::Data<Arc<WsState>>,
) -> HttpResponse {
    if crate::auth::middleware::extract_guest(&req, &pool).await.is_err() {
        return HttpResponse::Unauthorized().json(serde_json::json!({
            "success": false, "error": "Not authenticated"
        }));
    }

    let online = ws_state.online.read().await;
    let users: Vec<serde_json::Value> = online.iter().map(|(id, name)| {
        serde_json::json!({ "id": id.to_string(), "name": name })
    }).collect();

    HttpResponse::Ok().json(serde_json::json!({
        "success": true,
        "online_count": users.len(),
        "data": users,
    }))
}

#[derive(Debug, Deserialize)]
pub struct WsQuery {
    pub token: String,
}
