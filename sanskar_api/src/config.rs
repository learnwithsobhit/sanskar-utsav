use std::env;

/// How login OTPs are delivered via Twilio (`OTP_DELIVERY`).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum OtpDeliveryMode {
    TwilioSms,
    TwilioWhatsapp,
    TwilioWhatsappThenSms,
}

impl OtpDeliveryMode {
    fn parse(raw: &str) -> Self {
        match raw.trim().to_ascii_lowercase().as_str() {
            "twilio_whatsapp" | "whatsapp" => Self::TwilioWhatsapp,
            "twilio_whatsapp_then_sms" | "whatsapp_then_sms" => Self::TwilioWhatsappThenSms,
            "twilio_sms" | "sms" => Self::TwilioSms,
            _ => Self::TwilioSms,
        }
    }
}

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
    /// Twilio channel for OTP: SMS, WhatsApp, or WhatsApp with SMS fallback.
    pub otp_delivery: OtpDeliveryMode,
    /// E.164 sender for Twilio WhatsApp (`whatsapp:` prefix added when sending).
    pub twilio_whatsapp_from: Option<String>,
    /// Browser `Origin` values allowed for CORS (exact match); localhost dev ports are added in `main`.
    pub cors_allowed_origins: Vec<String>,
    /// When true, send `Access-Control-Allow-Origin: *` (overrides explicit origins).
    pub cors_allow_any: bool,
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

        let otp_delivery = env::var("OTP_DELIVERY")
            .map(|s| OtpDeliveryMode::parse(&s))
            .unwrap_or(OtpDeliveryMode::TwilioSms);

        let twilio_whatsapp_from = env::var("TWILIO_WHATSAPP_FROM")
            .ok()
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty());

        let cors_allow_any = env::var("CORS_ALLOW_ANY")
            .map(|v| matches!(v.to_lowercase().as_str(), "1" | "true" | "yes"))
            .unwrap_or(false);

        let mut cors_allowed_origins: Vec<String> = env::var("CORS_ALLOWED_ORIGINS")
            .unwrap_or_default()
            .split(',')
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty())
            .collect();

        if cors_allowed_origins.is_empty() {
            cors_allowed_origins = vec![
                "https://sanskar-utsav.web.app".into(),
                "https://sanskar-utsav.firebaseapp.com".into(),
                "http://localhost:8080".into(),
                "http://127.0.0.1:8080".into(),
            ];
        }

        let mut config = Self {
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
            otp_delivery,
            twilio_whatsapp_from,
            cors_allowed_origins,
            cors_allow_any,
        };
        config.merge_web_app_into_cors();
        config
    }

    /// Add [WEB_APP_BASE_URL] to CORS allowlist when it is an `https://` origin.
    fn merge_web_app_into_cors(&mut self) {
        let base = self.web_app_base_url.trim_end_matches('/').to_string();
        if base.starts_with("https://") && !self.cors_allowed_origins.contains(&base) {
            self.cors_allowed_origins.push(base);
        }
    }
}
