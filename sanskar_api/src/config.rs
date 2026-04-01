use std::env;

/// Central configuration loaded from environment variables.
#[derive(Debug, Clone)]
pub struct AppConfig {
    pub port: u16,
    pub database_url: String,
    pub redis_url: String,
    pub nats_url: String,
    pub otel_endpoint: String,
    pub otel_service_name: String,
    pub admin_phones: Vec<String>,
    // S3
    pub s3_bucket: String,
    pub s3_region: String,
    pub s3_endpoint: Option<String>,
}

impl AppConfig {
    /// Load configuration from environment variables (with defaults for local dev).
    pub fn from_env() -> Self {
        dotenv::dotenv().ok();

        let admin_phones_raw = env::var("ADMIN_PHONES").unwrap_or_default();
        let admin_phones: Vec<String> = admin_phones_raw
            .split(',')
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty())
            .collect();

        Self {
            port: env::var("PORT")
                .unwrap_or_else(|_| "8080".into())
                .parse()
                .unwrap_or(8080),
            database_url: env::var("DATABASE_URL")
                .expect("DATABASE_URL must be set"),
            redis_url: env::var("REDIS_URL")
                .unwrap_or_else(|_| "redis://127.0.0.1:6379".into()),
            nats_url: env::var("NATS_URL")
                .unwrap_or_else(|_| "nats://127.0.0.1:4222".into()),
            otel_endpoint: env::var("OTEL_EXPORTER_OTLP_ENDPOINT")
                .unwrap_or_else(|_| "http://localhost:4317".into()),
            otel_service_name: env::var("OTEL_SERVICE_NAME")
                .unwrap_or_else(|_| "sanskar-api".into()),
            admin_phones,
            s3_bucket: env::var("S3_BUCKET")
                .unwrap_or_else(|_| "sanskar-utsav-media".into()),
            s3_region: env::var("AWS_REGION")
                .unwrap_or_else(|_| "ap-south-1".into()),
            s3_endpoint: env::var("S3_ENDPOINT").ok().filter(|s| !s.is_empty()),
        }
    }
}
