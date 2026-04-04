mod auth;
mod broker;
mod cache;
mod config;
mod models;
mod routes;
mod services;
mod telemetry;

use actix_cors::Cors;
use actix_web::{App, HttpServer, web};
use sqlx::postgres::PgPoolOptions;
use tracing_actix_web::TracingLogger;
use std::sync::Arc;

use config::AppConfig;

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    // ── Configuration ──
    let cfg = AppConfig::from_env();

    // ── Telemetry (optional — falls back to logs-only if no OTLP endpoint) ──
    let _otel_guard = telemetry::init_telemetry(&cfg.otel_service_name, &cfg.otel_endpoint);
    tracing::info!("🕉️  Sanskar Utsav API starting...");

    // ── PostgreSQL (required) ──
    tracing::info!("📦 Connecting to PostgreSQL...");
    let pool = PgPoolOptions::new()
        .max_connections(10)
        .connect(&cfg.database_url)
        .await
        .expect("Failed to connect to PostgreSQL");
    tracing::info!("✅ PostgreSQL connected");

    // ── Migrations ──
    tracing::info!("📦 Running migrations...");
    sqlx::migrate!("./migrations")
        .run(&pool)
        .await
        .expect("Failed to run migrations");
    tracing::info!("✅ Migrations complete");

    // ── Redis (required) ──
    tracing::info!("📦 Connecting to Redis...");
    let redis = cache::RedisCache::connect(&cfg.redis_url)
        .await
        .expect("Failed to connect to Redis");
    tracing::info!("✅ Redis connected");

    // ── NATS (optional — skip if URL is empty or connection fails) ──
    let nats = if cfg.nats_url.is_empty() {
        tracing::warn!("⚠️  NATS_URL not set, running without NATS");
        None
    } else {
        match broker::NatsBroker::connect(&cfg.nats_url).await {
            Ok(n) => {
                tracing::info!("✅ NATS connected");
                Some(n)
            }
            Err(e) => {
                tracing::warn!("⚠️  NATS connection failed ({e}), running without NATS");
                None
            }
        }
    };

    // ── S3 Client (MinIO / AWS) ──
    tracing::info!("📦 Initializing S3 client...");
    let s3_client = services::media_service::create_s3_client().await;
    tracing::info!("✅ S3 client ready");

    // ── Start Server ──
    let bind_addr = format!("0.0.0.0:{}", cfg.port);
    tracing::info!("🛕 Server running at http://{}", bind_addr);

    let app_config = web::Data::new(cfg.clone());

    let redis_data = web::Data::new(redis);
    let nats_data = web::Data::new(nats);
    let s3_data = web::Data::new(s3_client);
    let ws_state = web::Data::new(Arc::new(routes::ws_handler::WsState::new()));
    tracing::info!("✅ WebSocket state ready");

    HttpServer::new(move || {
        let cors = Cors::default()
            .allow_any_origin()
            .allow_any_method()
            .allow_any_header()
            .max_age(3600);

        App::new()
            .wrap(cors)
            .wrap(TracingLogger::default())
            .app_data(web::Data::new(pool.clone()))
            .app_data(app_config.clone())
            .app_data(redis_data.clone())
            .app_data(nats_data.clone())
            .app_data(s3_data.clone())
            .app_data(ws_state.clone())
            // Health
            .service(routes::health::root)
            .service(routes::health::health)
            // Auth
            .service(routes::auth_routes::invite_info)
            .service(routes::auth_routes::redeem_invite)
            .service(routes::auth_routes::login)
            .service(routes::auth_routes::otp_request)
            .service(routes::auth_routes::otp_verify)
            .service(routes::auth_routes::me)
            .service(routes::auth_routes::logout)
            // Events
            .service(routes::event_routes::list_events)
            .service(routes::event_routes::events_today)
            .service(routes::event_routes::events_by_day)
            .service(routes::event_routes::get_event)
            // Guests
            .service(routes::guest_routes::list_guests)
            .service(routes::guest_routes::get_guest)
            .service(routes::guest_routes::update_profile)
            // RSVP
            .service(routes::rsvp_routes::submit_rsvp)
            .service(routes::rsvp_routes::my_rsvps)
            .service(routes::rsvp_routes::update_rsvp)
            .service(routes::rsvp_routes::bulk_rsvp)
            // Media
            .service(routes::media_routes::list_media)
            .service(routes::media_routes::presign_upload)
            .service(routes::media_routes::create_media)
            .service(routes::media_routes::proxy_upload)
            .service(routes::media_routes::serve_media)
            .service(routes::media_routes::like_media)
            .service(routes::media_routes::get_media_comments)
            .service(routes::media_routes::add_media_comment)
            // Announcements
            .service(routes::announcement_routes::list_announcements)
            .service(routes::announcement_routes::urgent_announcements)
            // Notifications
            .service(routes::notification_routes::list_notifications)
            .service(routes::notification_routes::mark_read)
            .service(routes::notification_routes::mark_all_read)
            .service(routes::notification_routes::register_fcm_token)
            // Blessings
            .service(routes::blessing_routes::list_blessings)
            .service(routes::blessing_routes::create_blessing)
            // Admin
            .service(routes::admin_routes::admin_create_guest)
            .service(routes::admin_routes::admin_list_guests)
            .service(routes::admin_routes::admin_revoke_guest)
            .service(routes::admin_routes::admin_rotate_guest_invite)
            .service(routes::admin_routes::admin_update_guest)
            .service(routes::admin_routes::admin_create_event)
            .service(routes::admin_routes::admin_patch_event)
            .service(routes::admin_routes::admin_delete_event)
            .service(routes::admin_routes::admin_create_announcement)
            .service(routes::admin_routes::admin_patch_announcement)
            .service(routes::admin_routes::admin_delete_announcement)
            .service(routes::admin_routes::admin_rsvp_summary)
            .service(routes::admin_routes::admin_send_notification)
            .service(routes::admin_routes::admin_list_media)
            .service(routes::admin_routes::admin_pending_media)
            .service(routes::admin_routes::admin_patch_media)
            .service(routes::admin_routes::admin_delete_media)
            // Admin Chat
            .service(routes::admin_routes::admin_broadcast_message)
            .service(routes::admin_routes::admin_create_event_group)
            .service(routes::admin_routes::admin_enroll_all_to_family)
            // Chat & Calls
            .service(routes::chat_routes::list_rooms)
            .service(routes::chat_routes::create_direct_chat)
            .service(routes::chat_routes::create_group_chat)
            .service(routes::chat_routes::get_messages)
            .service(routes::chat_routes::send_message)
            .service(routes::chat_routes::initiate_call)
            .service(routes::chat_routes::call_history)
            // WebSocket
            .service(routes::ws_handler::ws_handler)
            .service(routes::ws_handler::list_online)
    })
    .bind(&bind_addr)?
    .run()
    .await
}
