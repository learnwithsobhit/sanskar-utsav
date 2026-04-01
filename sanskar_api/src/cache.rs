use redis::aio::ConnectionManager;
use redis::AsyncCommands;
use std::time::Duration;

/// Thin wrapper around a Redis connection-manager for caching.
#[derive(Clone)]
pub struct RedisCache {
    conn: ConnectionManager,
}

impl RedisCache {
    /// Connect to Redis and return a cache handle.
    pub async fn connect(redis_url: &str) -> Result<Self, redis::RedisError> {
        let client = redis::Client::open(redis_url)?;
        let conn = ConnectionManager::new(client).await?;
        Ok(Self { conn })
    }

    /// GET a cached value.
    pub async fn get(&self, key: &str) -> Option<String> {
        let mut conn = self.conn.clone();
        redis::cmd("GET")
            .arg(key)
            .query_async::<Option<String>>(&mut conn)
            .await
            .ok()
            .flatten()
    }

    /// SET a value with TTL.
    pub async fn set(&self, key: &str, value: &str, ttl: Duration) -> Result<(), redis::RedisError> {
        let mut conn = self.conn.clone();
        conn.set_ex(key, value, ttl.as_secs()).await
    }

    /// DELETE a key (cache invalidation).
    pub async fn del(&self, key: &str) -> Result<(), redis::RedisError> {
        let mut conn = self.conn.clone();
        conn.del(key).await
    }

    /// Check if Redis is reachable (health-check).
    pub async fn ping(&self) -> bool {
        let mut conn = self.conn.clone();
        redis::cmd("PING")
            .query_async::<String>(&mut conn)
            .await
            .map(|v| v == "PONG")
            .unwrap_or(false)
    }

    /// Increment a counter with TTL (for rate-limiting).
    pub async fn incr_with_ttl(&self, key: &str, ttl: Duration) -> Result<i64, redis::RedisError> {
        let mut conn = self.conn.clone();
        let count: i64 = conn.incr(key, 1i64).await?;
        if count == 1 {
            let _: () = conn.expire(key, ttl.as_secs() as i64).await?;
        }
        Ok(count)
    }
}
