# ══════════════════════════════════════════════════
# Stage 1: Build the Rust binary
# ══════════════════════════════════════════════════
FROM rust:1.91.1-slim-bookworm AS builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y \
    pkg-config libssl-dev ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Cache dependencies — copy manifests first
COPY sanskar_api/Cargo.toml sanskar_api/Cargo.lock ./
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release && rm -rf src

# Build the actual application
COPY sanskar_api/src/ src/
COPY sanskar_api/migrations/ migrations/
RUN touch src/main.rs && cargo build --release

# ══════════════════════════════════════════════════
# Stage 2: Minimal runtime image
# ══════════════════════════════════════════════════
FROM debian:bookworm-slim

WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates libssl3 curl \
    && rm -rf /var/lib/apt/lists/*

# Copy the built binary and migrations
COPY --from=builder /app/target/release/sanskar_api /app/sanskar_api
COPY --from=builder /app/migrations /app/migrations

# Health check
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD curl -f http://localhost:${PORT:-8080}/health || exit 1

# Default port (Railway provides PORT dynamically)
ENV PORT=8080
EXPOSE ${PORT}

CMD ["/app/sanskar_api"]
