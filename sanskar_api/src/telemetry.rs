use opentelemetry::KeyValue;
use opentelemetry::trace::TracerProvider;
use opentelemetry_otlp::WithExportConfig;
use opentelemetry_sdk::{runtime, Resource};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

/// Initialise the OpenTelemetry tracing pipeline and the `tracing` subscriber.
///
/// If the OTLP endpoint is empty or unreachable, falls back to logs-only mode.
/// Returns a guard that, when dropped, flushes remaining spans.
pub fn init_telemetry(service_name: &str, otlp_endpoint: &str) -> Option<OtelGuard> {
    let env_filter = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| EnvFilter::new("sanskar_api=debug,actix_web=info"));

    let fmt_layer = tracing_subscriber::fmt::layer()
        .with_target(true)
        .with_thread_ids(false)
        .compact();

    // If OTLP endpoint is provided, try to set up full tracing
    if !otlp_endpoint.is_empty() {
        match opentelemetry_otlp::SpanExporter::builder()
            .with_tonic()
            .with_endpoint(otlp_endpoint)
            .build()
        {
            Ok(exporter) => {
                let resource = Resource::new(vec![
                    KeyValue::new("service.name", service_name.to_string()),
                ]);

                let provider = opentelemetry_sdk::trace::TracerProvider::builder()
                    .with_batch_exporter(exporter, runtime::Tokio)
                    .with_resource(resource)
                    .build();

                let tracer = provider.tracer(service_name.to_string());
                let otel_layer = tracing_opentelemetry::layer().with_tracer(tracer);

                tracing_subscriber::registry()
                    .with(env_filter)
                    .with(fmt_layer)
                    .with(otel_layer)
                    .init();

                return Some(OtelGuard { provider });
            }
            Err(e) => {
                eprintln!("⚠️  OTLP exporter failed to build ({e}), using logs-only mode");
            }
        }
    }

    // Fallback: logs only (no OTLP/Jaeger)
    tracing_subscriber::registry()
        .with(env_filter)
        .with(fmt_layer)
        .init();

    None
}

/// RAII guard — flushes the tracer provider on drop.
pub struct OtelGuard {
    provider: opentelemetry_sdk::trace::TracerProvider,
}

impl Drop for OtelGuard {
    fn drop(&mut self) {
        if let Err(e) = self.provider.shutdown() {
            eprintln!("OpenTelemetry shutdown error: {e:?}");
        }
    }
}
