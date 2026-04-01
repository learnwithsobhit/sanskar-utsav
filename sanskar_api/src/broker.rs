use async_nats::Client;

/// Thin wrapper around a NATS client for event-driven messaging.
/// In production, NATS is optional — if not connected, publishes are silently skipped.
#[derive(Clone)]
pub struct NatsBroker {
    client: Option<Client>,
}

/// Standard subject prefixes for the Sanskar Utsav platform.
pub mod subjects {
    pub const NOTIFICATION_PUSH: &str = "sanskar.notification.push";
    pub const MEDIA_UPLOADED: &str = "sanskar.media.uploaded";
    pub const ANNOUNCEMENT_NEW: &str = "sanskar.announcement.new";
    pub const RSVP_UPDATED: &str = "sanskar.rsvp.updated";
    pub const EVENT_REMINDER: &str = "sanskar.event.reminder";
}

impl NatsBroker {
    /// Connect to a NATS server. Returns a connected broker if successful.
    pub async fn connect(nats_url: &str) -> Result<Self, async_nats::ConnectError> {
        let client = async_nats::connect(nats_url).await?;
        Ok(Self { client: Some(client) })
    }

    /// Create a no-op broker (for when NATS is not available).
    pub fn noop() -> Self {
        Self { client: None }
    }

    /// Publish a JSON message to a subject.
    /// Silently returns Ok if NATS is not connected (noop mode).
    pub async fn publish(&self, subject: &str, payload: &impl serde::Serialize) -> Result<(), BrokerError> {
        let client = match &self.client {
            Some(c) => c,
            None => return Ok(()), // No NATS — silently skip
        };
        let bytes = serde_json::to_vec(payload).map_err(BrokerError::Serialize)?;
        client
            .publish(subject.to_string(), bytes.into())
            .await
            .map_err(BrokerError::Publish)?;
        Ok(())
    }

    /// Publish raw bytes to a subject.
    pub async fn publish_raw(&self, subject: &str, data: Vec<u8>) -> Result<(), BrokerError> {
        let client = match &self.client {
            Some(c) => c,
            None => return Ok(()),
        };
        client
            .publish(subject.to_string(), data.into())
            .await
            .map_err(BrokerError::Publish)?;
        Ok(())
    }

    /// Health-check: verify NATS connection state.
    pub fn is_connected(&self) -> bool {
        match &self.client {
            Some(c) => c.connection_state() == async_nats::connection::State::Connected,
            None => false,
        }
    }
}

#[derive(Debug, thiserror::Error)]
pub enum BrokerError {
    #[error("serialization error: {0}")]
    Serialize(serde_json::Error),
    #[error("NATS publish error: {0}")]
    Publish(#[from] async_nats::PublishError),
}
