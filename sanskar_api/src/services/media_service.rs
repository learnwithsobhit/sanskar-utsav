/// Media service — handles S3 presign URL generation using aws-sdk-s3.
///
/// For local dev, uses MinIO. For production, uses real AWS S3 / CloudFront.

use aws_sdk_s3::presigning::PresigningConfig;
use aws_sdk_s3::Client as S3Client;
use std::time::Duration;

/// Create an S3 client configured from environment variables.
/// Supports both real AWS S3 and MinIO (local dev).
pub async fn create_s3_client() -> S3Client {
    let endpoint = std::env::var("S3_ENDPOINT").unwrap_or_default();
    let region = std::env::var("AWS_REGION").unwrap_or_else(|_| "us-east-1".to_string());

    let config = aws_config::defaults(aws_config::BehaviorVersion::latest())
        .region(aws_sdk_s3::config::Region::new(region))
        .load()
        .await;

    let mut s3_config = aws_sdk_s3::config::Builder::from(&config)
        .force_path_style(true); // Required for MinIO

    if !endpoint.is_empty() {
        s3_config = s3_config.endpoint_url(&endpoint);
    }

    S3Client::from_conf(s3_config.build())
}

/// Generate a unique S3 object key.
pub fn generate_object_key(prefix: &str, file_ext: &str) -> String {
    let id = uuid::Uuid::new_v4();
    format!("{}/{}.{}", prefix, id, file_ext.trim_start_matches('.'))
}

/// Generate a presigned PUT URL for uploading to S3.
pub async fn presign_upload(
    client: &S3Client,
    bucket: &str,
    key: &str,
    content_type: &str,
    expires_secs: u64,
) -> Result<String, String> {
    let presign_config = PresigningConfig::builder()
        .expires_in(Duration::from_secs(expires_secs))
        .build()
        .map_err(|e| format!("Presign config error: {e}"))?;

    let presigned = client
        .put_object()
        .bucket(bucket)
        .key(key)
        .content_type(content_type)
        .presigned(presign_config)
        .await
        .map_err(|e| format!("Presign error: {e}"))?;

    Ok(presigned.uri().to_string())
}

/// Generate a presigned GET URL for downloading from S3.
pub async fn presign_download(
    client: &S3Client,
    bucket: &str,
    key: &str,
    expires_secs: u64,
) -> Result<String, String> {
    let presign_config = PresigningConfig::builder()
        .expires_in(Duration::from_secs(expires_secs))
        .build()
        .map_err(|e| format!("Presign config error: {e}"))?;

    let presigned = client
        .get_object()
        .bucket(bucket)
        .key(key)
        .presigned(presign_config)
        .await
        .map_err(|e| format!("Presign error: {e}"))?;

    Ok(presigned.uri().to_string())
}

/// Get the public URL for a file.
/// Prefer **`S3_PUBLIC_URL`** in production so clients (especially video) hit CDN/S3 directly with HTTP Range;
/// otherwise URLs go through **`/api/media/serve/...`** on this API (`API_PUBLIC_URL`), which adds latency.
/// Configure bucket CORS for your web app origin when using a public base URL.
pub fn public_url(key: &str) -> String {
    // If a CDN/public URL is configured, use it directly
    if let Ok(base) = std::env::var("S3_PUBLIC_URL") {
        if !base.is_empty() {
            return format!("{}/{}", base, key);
        }
    }

    // Otherwise, route through backend proxy (avoids CORS)
    let api_base = std::env::var("API_PUBLIC_URL")
        .unwrap_or_else(|_| "http://localhost:8080".to_string());
    format!("{}/api/media/serve/{}", api_base, key)
}
