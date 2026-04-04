use crate::cache::RedisCache;

/// Redis key for cached `GET /api/guests` (public directory JSON).
pub const GUESTS_DIRECTORY_KEY: &str = "guests:directory";

/// Invalidate all event-related caches.
pub async fn invalidate_events(cache: &RedisCache) {
    let _ = cache.del("events:all").await;
    // Could also pattern-delete events:today:* if needed
}

/// Invalidate announcement cache.
pub async fn invalidate_announcements(cache: &RedisCache) {
    let _ = cache.del("announcements:active").await;
}

/// Invalidate guest directory cache (after admin or profile changes).
pub async fn invalidate_guest_directory(cache: &RedisCache) {
    let _ = cache.del(GUESTS_DIRECTORY_KEY).await;
}
