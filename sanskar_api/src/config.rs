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
    /// Comma-separated E.164 numbers allowed to receive `is_admin` on first bootstrap (see auth docs).
    pub admin_phones: Vec<String>,
    // S3
    pub s3_bucket: String,
    pub s3_region: String,
    pub s3_endpoint: Option<String>,
    /// Base URL for invite links (no trailing slash), e.g. https://sanskar-utsav.web.app
    pub web_app_base_url: String,
    /// Shown on invite preview (GET /api/auth/invite-info).
    pub event_display_name: String,
    /// When true, `/api/auth/login` and `/api/auth/redeem-invite` require OTP flow instead.
    pub otp_login_required: bool,
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

        let otp_login_required = env::var("OTP_LOGIN_REQUIRED")
            .map(|v| matches!(v.to_lowercase().as_str(), "1" | "true" | "yes"))
            .unwrap_or(false);

        Self {
            port: env::var("PORT")
                .unwrap_or_else(|_| "8080".into())
                .parse()
                .unwrap_or(8080),
            database_url: env::var("DATABASE_URL").expect("DATABASE_URL must be set"),
            redis_url: env::var("REDIS_URL")
                .unwrap_or_else(|_| "redis://127.0.0.1:6379".into()),
            nats_url: env::var("NATS_URL").unwrap_or_default(),
            otel_endpoint: env::var("OTEL_EXPORTER_OTLP_ENDPOINT").unwrap_or_default(),
            otel_service_name: env::var("OTEL_SERVICE_NAME")
                .unwrap_or_else(|_| "sanskar-api".into()),
            admin_phones,
            s3_bucket: env::var("S3_BUCKET")
                .unwrap_or_else(|_| "sanskar-utsav-media".into()),
            s3_region: env::var("AWS_REGION")
                .unwrap_or_else(|_| "ap-south-1".into()),
            s3_endpoint: env::var("S3_ENDPOINT").ok().filter(|s| !s.is_empty()),
            web_app_base_url: env::var("WEB_APP_BASE_URL")
                .unwrap_or_else(|_| "http://localhost:8080".into())
                .trim_end_matches('/')
                .to_string(),
            event_display_name: env::var("EVENT_DISPLAY_NAME")
                .unwrap_or_else(|_| "Sanskar Utsav".into()),
            otp_login_required,
        }
    }
}
