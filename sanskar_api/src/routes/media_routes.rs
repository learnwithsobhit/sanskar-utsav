use actix_web::{get, post, web, HttpRequest, HttpResponse};
use actix_multipart::Multipart;
use futures_util::StreamExt;
use sqlx::PgPool;

use crate::auth::middleware::extract_guest;
use crate::broker::{NatsBroker, subjects};
use crate::models::media::*;

/// GET /api/media — list shared media (paginated, filterable)
#[get("/api/media")]
pub async fn list_media(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    query: web::Query<MediaQuery>,
) -> HttpResponse {
    if extract_guest(&req, &pool).await.is_err() {
        return HttpResponse::Unauthorized().json(serde_json::json!({
            "success": false, "error": "Not authenticated"
        }));
    }

    let page = query.page.unwrap_or(1).max(1);
    let per_page = query.per_page.unwrap_or(20).min(100);
    let offset = ((page - 1) * per_page) as i64;

    let mut sql = String::from(
        "SELECT m.*, g.name as uploader_name, e.title as event_title \
         FROM media_items m \
         LEFT JOIN guests g ON g.id = m.uploaded_by \
         LEFT JOIN ceremony_events e ON e.id = m.event_id \
         WHERE m.is_approved = TRUE"
    );

    if let Some(eid) = query.event_id {
        sql.push_str(&format!(" AND m.event_id = {}", eid));
    }
    if let Some(ref mt) = query.media_type {
        sql.push_str(&format!(" AND m.media_type = '{}'", mt.replace('\'', "''")));
    }
    if query.featured_only == Some(true) {
        sql.push_str(" AND m.is_featured = TRUE");
    }

    sql.push_str(&format!(" ORDER BY m.created_at DESC LIMIT {} OFFSET {}", per_page, offset));

    match sqlx::query_as::<_, MediaItemView>(&sql)
        .fetch_all(pool.get_ref())
        .await
    {
        Ok(items) => HttpResponse::Ok().json(serde_json::json!({
            "success": true,
            "page": page,
            "per_page": per_page,
            "data": items,
        })),
        Err(e) => {
            tracing::error!("Failed to list media: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false,
                "error": "Failed to load media",
            }))
        }
    }
}

/// POST /api/media/presign — get a presigned S3 upload URL
#[post("/api/media/presign")]
pub async fn presign_upload(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    s3: web::Data<aws_sdk_s3::Client>,
    body: web::Json<PresignUploadRequest>,
) -> HttpResponse {
    if extract_guest(&req, &pool).await.is_err() {
        return HttpResponse::Unauthorized().json(serde_json::json!({
            "success": false, "error": "Not authenticated"
        }));
    }

    let prefix = body.prefix.as_deref().unwrap_or("uploads");
    let key = crate::services::media_service::generate_object_key(prefix, &body.file_ext);
    let bucket = std::env::var("S3_BUCKET").unwrap_or_else(|_| "sanskar-utsav-media".to_string());
    let content_type = body.content_type.as_deref().unwrap_or("application/octet-stream");

    match crate::services::media_service::presign_upload(&s3, &bucket, &key, content_type, 3600).await {
        Ok(upload_url) => {
            let public_url = crate::services::media_service::public_url(&key);
            HttpResponse::Ok().json(PresignUploadResponse {
                success: true,
                upload_url,
                public_url,
                key,
                expires_in_sec: 3600,
            })
        }
        Err(e) => {
            tracing::error!("Presign failed: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false, "error": "Failed to generate upload URL"
            }))
        }
    }
}

/// POST /api/media — create media entry after upload
#[post("/api/media")]
pub async fn create_media(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    nats: web::Data<Option<NatsBroker>>,
    body: web::Json<CreateMediaRequest>,
) -> HttpResponse {
    let guest = match extract_guest(&req, &pool).await {
        Ok(g) => g,
        Err(_) => return HttpResponse::Unauthorized().json(serde_json::json!({
            "success": false, "error": "Not authenticated"
        })),
    };

    match sqlx::query_as::<_, MediaItem>(
        "INSERT INTO media_items (uploaded_by, event_id, media_type, title, description, \
         file_url, thumbnail_url, file_size_bytes, duration_secs, mime_type) \
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) RETURNING *"
    )
    .bind(guest.id)
    .bind(body.event_id)
    .bind(&body.media_type)
    .bind(body.title.as_deref().unwrap_or(""))
    .bind(body.description.as_deref().unwrap_or(""))
    .bind(&body.file_url)
    .bind(body.thumbnail_url.as_deref().unwrap_or(""))
    .bind(body.file_size_bytes.unwrap_or(0))
    .bind(body.duration_secs.unwrap_or(0))
    .bind(body.mime_type.as_deref().unwrap_or(""))
    .fetch_one(pool.get_ref())
    .await
    {
        Ok(item) => {
            // Publish event for async processing
            if let Some(n) = nats.as_ref() { let _ = n.publish(subjects::MEDIA_UPLOADED, &serde_json::json!({
                "media_id": item.id,
                "uploaded_by": guest.id,
                "media_type": item.media_type,
            })).await; }

            HttpResponse::Created().json(serde_json::json!({
                "success": true,
                "data": item,
            }))
        }
        Err(e) => {
            tracing::error!("Failed to create media: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false,
                "error": "Failed to save media",
            }))
        }
    }
}

/// POST /api/media/{id}/like — toggle like
#[post("/api/media/{id}/like")]
pub async fn like_media(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    path: web::Path<i32>,
) -> HttpResponse {
    let guest = match extract_guest(&req, &pool).await {
        Ok(g) => g,
        Err(_) => return HttpResponse::Unauthorized().json(serde_json::json!({
            "success": false, "error": "Not authenticated"
        })),
    };

    let media_id = path.into_inner();

    // Check if already liked
    let existing: Option<(i32,)> = sqlx::query_as(
        "SELECT id FROM media_likes WHERE media_id = $1 AND guest_id = $2"
    )
    .bind(media_id)
    .bind(guest.id)
    .fetch_optional(pool.get_ref())
    .await
    .unwrap_or(None);

    if let Some((like_id,)) = existing {
        // Unlike
        let _ = sqlx::query("DELETE FROM media_likes WHERE id = $1").bind(like_id).execute(pool.get_ref()).await;
        let _ = sqlx::query("UPDATE media_items SET like_count = GREATEST(like_count - 1, 0) WHERE id = $1")
            .bind(media_id).execute(pool.get_ref()).await;
        HttpResponse::Ok().json(serde_json::json!({ "success": true, "liked": false }))
    } else {
        // Like
        let _ = sqlx::query("INSERT INTO media_likes (media_id, guest_id) VALUES ($1, $2)")
            .bind(media_id).bind(guest.id).execute(pool.get_ref()).await;
        let _ = sqlx::query("UPDATE media_items SET like_count = like_count + 1 WHERE id = $1")
            .bind(media_id).execute(pool.get_ref()).await;
        HttpResponse::Ok().json(serde_json::json!({ "success": true, "liked": true }))
    }
}

/// GET /api/media/{id}/comments
#[get("/api/media/{id}/comments")]
pub async fn get_media_comments(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    path: web::Path<i32>,
) -> HttpResponse {
    if extract_guest(&req, &pool).await.is_err() {
        return HttpResponse::Unauthorized().json(serde_json::json!({
            "success": false, "error": "Not authenticated"
        }));
    }

    let media_id = path.into_inner();

    match sqlx::query_as::<_, MediaComment>(
        "SELECT * FROM media_comments WHERE media_id = $1 ORDER BY created_at"
    )
    .bind(media_id)
    .fetch_all(pool.get_ref())
    .await
    {
        Ok(comments) => HttpResponse::Ok().json(serde_json::json!({
            "success": true,
            "data": comments,
        })),
        Err(e) => {
            tracing::error!("Failed to load comments: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false,
                "error": "Failed to load comments",
            }))
        }
    }
}

/// POST /api/media/{id}/comments
#[post("/api/media/{id}/comments")]
pub async fn add_media_comment(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    path: web::Path<i32>,
    body: web::Json<NewMediaCommentRequest>,
) -> HttpResponse {
    let guest = match extract_guest(&req, &pool).await {
        Ok(g) => g,
        Err(_) => return HttpResponse::Unauthorized().json(serde_json::json!({
            "success": false, "error": "Not authenticated"
        })),
    };

    let media_id = path.into_inner();

    match sqlx::query_as::<_, MediaComment>(
        "INSERT INTO media_comments (media_id, guest_id, guest_name, comment) \
         VALUES ($1, $2, $3, $4) RETURNING *"
    )
    .bind(media_id)
    .bind(guest.id)
    .bind(&guest.name)
    .bind(&body.comment)
    .fetch_one(pool.get_ref())
    .await
    {
        Ok(comment) => HttpResponse::Created().json(serde_json::json!({
            "success": true,
            "data": comment,
        })),
        Err(e) => {
            tracing::error!("Failed to add comment: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false,
                "error": "Failed to add comment",
            }))
        }
    }
}

/// POST /api/media/upload — proxy upload: receives file via multipart, uploads to S3, creates record
///
/// Multipart fields:
/// - `file`: the binary file data
/// - `media_type`: "photo" | "video" | "audio"
/// - `title` (optional)
/// - `description` (optional)
/// - `event_id` (optional)
#[post("/api/media/upload")]
pub async fn proxy_upload(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    s3: web::Data<aws_sdk_s3::Client>,
    nats: web::Data<Option<NatsBroker>>,
    mut payload: Multipart,
) -> HttpResponse {
    let guest = match extract_guest(&req, &pool).await {
        Ok(g) => g,
        Err(_) => return HttpResponse::Unauthorized().json(serde_json::json!({
            "success": false, "error": "Not authenticated"
        })),
    };

    let mut file_data: Vec<u8> = Vec::new();
    let mut content_type = String::from("application/octet-stream");
    let mut file_ext = String::from("bin");
    let mut media_type = String::from("photo");
    let mut title = String::new();
    let mut description = String::new();
    let mut event_id: Option<i32> = None;

    // Parse multipart fields
    while let Some(Ok(mut field)) = payload.next().await {
        let field_name = field.name().unwrap_or("").to_string();

        match field_name.as_str() {
            "file" => {
                // Get content type from the file field
                if let Some(ct) = field.content_type() {
                    content_type = ct.to_string();
                }
                // Get filename for extension
                if let Some(cd) = field.content_disposition() {
                    if let Some(fname) = cd.get_filename() {
                        if let Some(ext) = fname.rsplit('.').next() {
                            file_ext = ext.to_lowercase();
                        }
                    }
                }
                // Read file bytes
                while let Some(Ok(chunk)) = field.next().await {
                    file_data.extend_from_slice(&chunk);
                }
            }
            _ => {
                // Read text fields
                let mut value = String::new();
                while let Some(Ok(chunk)) = field.next().await {
                    value.push_str(&String::from_utf8_lossy(&chunk));
                }
                match field_name.as_str() {
                    "media_type" => media_type = value,
                    "title" => title = value,
                    "description" => description = value,
                    "event_id" => event_id = value.parse().ok(),
                    _ => {}
                }
            }
        }
    }

    if file_data.is_empty() {
        return HttpResponse::BadRequest().json(serde_json::json!({
            "success": false, "error": "No file provided"
        }));
    }

    let file_size = file_data.len() as i64;
    let prefix = match media_type.as_str() {
        "video" => "videos",
        "audio" => "audio",
        _ => "photos",
    };
    let key = crate::services::media_service::generate_object_key(prefix, &file_ext);
    let bucket = std::env::var("S3_BUCKET").unwrap_or_else(|_| "sanskar-utsav-media".to_string());

    // Upload to S3 directly from the server (no CORS issues)
    let put_result = s3
        .put_object()
        .bucket(&bucket)
        .key(&key)
        .content_type(&content_type)
        .body(file_data.into())
        .send()
        .await;

    if let Err(e) = put_result {
        tracing::error!("S3 upload failed: {e}");
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "success": false, "error": "Failed to upload file to storage"
        }));
    }

    let public_url = crate::services::media_service::public_url(&key);

    // Create DB record
    match sqlx::query_as::<_, MediaItem>(
        "INSERT INTO media_items (uploaded_by, event_id, media_type, title, description, \
         file_url, thumbnail_url, file_size_bytes, duration_secs, mime_type) \
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) RETURNING *"
    )
    .bind(guest.id)
    .bind(event_id)
    .bind(&media_type)
    .bind(if title.is_empty() { "" } else { &title })
    .bind(if description.is_empty() { "" } else { &description })
    .bind(&public_url)
    .bind("")
    .bind(file_size)
    .bind(0i32)
    .bind(&content_type)
    .fetch_one(pool.get_ref())
    .await
    {
        Ok(item) => {
            if let Some(n) = nats.as_ref() { let _ = n.publish(crate::broker::subjects::MEDIA_UPLOADED, &serde_json::json!({
                "media_id": item.id,
                "uploaded_by": guest.id,
                "media_type": item.media_type,
            })).await; }

            HttpResponse::Created().json(serde_json::json!({
                "success": true,
                "data": item,
                "public_url": public_url,
            }))
        }
        Err(e) => {
            tracing::error!("Failed to create media record: {e}");
            HttpResponse::InternalServerError().json(serde_json::json!({
                "success": false,
                "error": "File uploaded but failed to save record",
            }))
        }
    }
}

/// GET /api/media/serve/{prefix}/{filename} — proxy media files from S3 with CORS headers.
/// This bypasses browser CORS restrictions when loading from MinIO directly.
#[get("/api/media/serve/{prefix}/{filename}")]
pub async fn serve_media(
    path: web::Path<(String, String)>,
    s3: web::Data<aws_sdk_s3::Client>,
) -> HttpResponse {
    let (prefix, filename) = path.into_inner();
    let key = format!("{}/{}", prefix, filename);
    let bucket = std::env::var("S3_BUCKET").unwrap_or_else(|_| "sanskar-utsav-media".to_string());

    match s3.get_object().bucket(&bucket).key(&key).send().await {
        Ok(output) => {
            let content_type = output.content_type()
                .unwrap_or("application/octet-stream")
                .to_string();
            let body = output.body.collect().await
                .map(|data| data.into_bytes().to_vec())
                .unwrap_or_default();

            HttpResponse::Ok()
                .insert_header(("Content-Type", content_type))
                .insert_header(("Cache-Control", "public, max-age=31536000"))
                .insert_header(("Access-Control-Allow-Origin", "*"))
                .body(body)
        }
        Err(e) => {
            tracing::error!("S3 get failed for {key}: {e}");
            HttpResponse::NotFound().json(serde_json::json!({
                "success": false,
                "error": "File not found",
            }))
        }
    }
}
