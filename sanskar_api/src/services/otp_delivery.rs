use crate::config::{AppConfig, OtpDeliveryMode};
use crate::services::sms_service;

/// Resulting channel for API `delivery_channel` field: `whatsapp`, `sms`, or `none`.
pub async fn send_login_otp(cfg: &AppConfig, to_e164: &str, body: &str) -> &'static str {
    match cfg.otp_delivery {
        OtpDeliveryMode::TwilioSms => match sms_service::send_sms_e164(to_e164, body).await {
            Ok(()) => "sms",
            Err(_) => "none",
        },
        OtpDeliveryMode::TwilioWhatsapp => {
            let Some(ref from) = cfg.twilio_whatsapp_from else {
                tracing::warn!(target: "otp", "TWILIO_WHATSAPP_FROM not set; WhatsApp OTP skipped");
                return "none";
            };
            match sms_service::send_whatsapp_e164(to_e164, body, from).await {
                Ok(()) => "whatsapp",
                Err(_) => "none",
            }
        }
        OtpDeliveryMode::TwilioWhatsappThenSms => {
            if let Some(ref from) = cfg.twilio_whatsapp_from {
                if sms_service::send_whatsapp_e164(to_e164, body, from)
                    .await
                    .is_ok()
                {
                    return "whatsapp";
                }
            }
            match sms_service::send_sms_e164(to_e164, body).await {
                Ok(()) => "sms",
                Err(_) => "none",
            }
        }
    }
}
