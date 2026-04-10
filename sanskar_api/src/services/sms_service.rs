fn twilio_credentials() -> Option<(String, String)> {
    let sid = std::env::var("TWILIO_ACCOUNT_SID").unwrap_or_default();
    let token = std::env::var("TWILIO_AUTH_TOKEN").unwrap_or_default();
    if sid.is_empty() || token.is_empty() {
        return None;
    }
    Some((sid, token))
}

async fn twilio_send_message(to: &str, from: &str, body: &str) -> Result<(), String> {
    let Some((sid, token)) = twilio_credentials() else {
        return Err("Twilio not configured".into());
    };

    let url = format!("https://api.twilio.com/2010-04-01/Accounts/{sid}/Messages.json");
    let client = reqwest::Client::new();
    let form = [("To", to), ("From", from), ("Body", body)];

    let resp = client
        .post(&url)
        .basic_auth(&sid, Some(&token))
        .form(&form)
        .send()
        .await
        .map_err(|e| e.to_string())?;

    if !resp.status().is_success() {
        let txt = resp.text().await.unwrap_or_default();
        tracing::error!(target: "sms", "Twilio error: {txt}");
        return Err("Twilio message send failed".into());
    }

    Ok(())
}

/// Send SMS via Twilio when `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, and `TWILIO_FROM_NUMBER` are set.
pub async fn send_sms_e164(to_e164: &str, body: &str) -> Result<(), String> {
    let from = std::env::var("TWILIO_FROM_NUMBER").unwrap_or_default();
    if from.is_empty() {
        tracing::warn!(
            target: "sms",
            "SMS not configured (missing TWILIO_FROM_NUMBER); message not sent to {}",
            to_e164
        );
        return Err("SMS provider not configured".into());
    }

    twilio_send_message(to_e164, &from, body).await
}

/// WhatsApp outbound via Twilio Messages API (`whatsapp:+E164` on both sides).
pub async fn send_whatsapp_e164(to_e164: &str, body: &str, from_e164: &str) -> Result<(), String> {
    let to = if to_e164.starts_with("whatsapp:") {
        to_e164.to_string()
    } else {
        format!("whatsapp:{to_e164}")
    };
    let from = if from_e164.starts_with("whatsapp:") {
        from_e164.to_string()
    } else {
        format!("whatsapp:{from_e164}")
    };

    if twilio_credentials().is_none() {
        tracing::warn!(
            target: "sms",
            "WhatsApp not configured (missing Twilio credentials); message not sent to {}",
            to_e164
        );
        return Err("WhatsApp provider not configured".into());
    }

    twilio_send_message(&to, &from, body).await
}
