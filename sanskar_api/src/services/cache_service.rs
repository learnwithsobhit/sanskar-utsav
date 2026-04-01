use crate::cache::RedisCache;

/// Invalidate all event-related caches.
pub async fn invalidate_events(cache: &RedisCache) {
    let _ = cache.del("events:all").await;
    // Could also pattern-delete events:today:* if needed
}

/// Invalidate announcement cache.
pub async fn invalidate_announcements(cache: &RedisCache) {
    let _ = cache.del("announcements:active").await;
}
