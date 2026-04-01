use opentelemetry::KeyValue;
use opentelemetry::trace::TracerProvider;
use opentelemetry_otlp::WithExportConfig;
use opentelemetry_sdk::{runtime, Resource};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

/// Initialise the tracing subscriber.
/// If `otlp_endpoint` is non-empty, enables OpenTelemetry export to Jaeger/collector.
/// Otherwise, falls back to stdout-only logging (production-safe).
pub fn init_telemetry(service_name: &str, otlp_endpoint: &str) -> Option<OtelGuard> {
    let env_filter = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| EnvFilter::new("sanskar_api=info,actix_web=info"));

    let fmt_layer = tracing_subscriber::fmt::layer()
        .with_target(true)
        .with_thread_ids(false)
        .compact();

    // If OTEL endpoint is provided, enable full tracing pipeline
    if !otlp_endpoint.is_empty() {
        match build_otel_provider(service_name, otlp_endpoint) {
            Ok((provider, otel_layer)) => {
                tracing_subscriber::registry()
                    .with(env_filter)
                    .with(fmt_layer)
                    .with(otel_layer)
                    .init();
                return Some(OtelGuard { provider });
            }
            Err(e) => {
                eprintln!("⚠️  OpenTelemetry init failed ({e}), using stdout-only logging");
            }
        }
    }

    // Fallback: stdout-only logging
    tracing_subscriber::registry()
        .with(env_filter)
        .with(fmt_layer)
        .init();

    None
}

fn build_otel_provider(
    service_name: &str,
    otlp_endpoint: &str,
) -> Result<(
    opentelemetry_sdk::trace::TracerProvider,
    tracing_opentelemetry::OpenTelemetryLayer<tracing_subscriber::Registry, opentelemetry_sdk::trace::Tracer>,
), Box<dyn std::error::Error>> {
    let exporter = opentelemetry_otlp::SpanExporter::builder()
        .with_tonic()
        .with_endpoint(otlp_endpoint)
        .build()?;

    let resource = Resource::new(vec![
        KeyValue::new("service.name", service_name.to_string()),
    ]);

    let provider = opentelemetry_sdk::trace::TracerProvider::builder()
        .with_batch_exporter(exporter, runtime::Tokio)
        .with_resource(resource)
        .build();

    let tracer = provider.tracer(service_name.to_string());
    let otel_layer = tracing_opentelemetry::layer().with_tracer(tracer);

    Ok((provider, otel_layer))
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
