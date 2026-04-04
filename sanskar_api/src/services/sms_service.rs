/// Send SMS via Twilio when `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, and `TWILIO_FROM_NUMBER` are set.
pub async fn send_sms_e164(to_e164: &str, body: &str) -> Result<(), String> {
    let sid = std::env::var("TWILIO_ACCOUNT_SID").unwrap_or_default();
    let token = std::env::var("TWILIO_AUTH_TOKEN").unwrap_or_default();
    let from = std::env::var("TWILIO_FROM_NUMBER").unwrap_or_default();

    if sid.is_empty() || token.is_empty() || from.is_empty() {
        tracing::warn!(
            target: "sms",
            "SMS not configured (missing Twilio env); message not sent to {}",
            to_e164
        );
        return Err("SMS provider not configured".into());
    }

    let url = format!("https://api.twilio.com/2010-04-01/Accounts/{sid}/Messages.json");
    let client = reqwest::Client::new();
    let form = [
        ("To", to_e164),
        ("From", from.as_str()),
        ("Body", body),
    ];

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
        return Err("Failed to send SMS".into());
    }

    Ok(())
}
