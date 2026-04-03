use actix_web::{get, web, HttpResponse};
use sqlx::PgPool;
use serde::Serialize;

use crate::cache::RedisCache;
use crate::broker::NatsBroker;

#[derive(Serialize)]
struct HealthResponse {
    status: &'static str,
    service: &'static str,
    version: &'static str,
    postgres: bool,
    redis: bool,
    nats: bool,
}

#[get("/")]
pub async fn root() -> HttpResponse {
    HttpResponse::Ok().json(serde_json::json!({
        "service": "Sanskar Utsav API",
        "status": "🙏 Jai Shri Krishna! Server is running.",
        "version": env!("CARGO_PKG_VERSION"),
    }))
}

#[get("/health")]
pub async fn health(
    pool: web::Data<PgPool>,
    redis: web::Data<RedisCache>,
    nats: web::Data<Option<NatsBroker>>,
) -> HttpResponse {
    let pg_ok = sqlx::query_scalar::<_, i32>("SELECT 1")
        .fetch_one(pool.get_ref())
        .await
        .is_ok();

    let redis_ok = redis.ping().await;
    let nats_ok = match nats.as_ref() {
        Some(n) => n.is_connected(),
        None => true, // NATS not configured, don't report as unhealthy
    };

    let resp = HealthResponse {
        status: if pg_ok && redis_ok { "healthy" } else { "degraded" },
        service: "sanskar-api",
        version: env!("CARGO_PKG_VERSION"),
        postgres: pg_ok,
        redis: redis_ok,
        nats: nats_ok,
    };

    if pg_ok {
        HttpResponse::Ok().json(resp)
    } else {
        HttpResponse::ServiceUnavailable().json(resp)
    }
}
