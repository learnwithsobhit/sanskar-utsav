# ═══════════════════════════════════════════════
# Stage 1: Builder — compile Rust release binary
# ═══════════════════════════════════════════════
FROM rust:1.85-slim-bookworm AS builder

RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Cache dependency compilation
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release && rm -rf src

# Build actual application
COPY src/ src/
COPY migrations/ migrations/
RUN touch src/main.rs && cargo build --release

# ═══════════════════════════════════════════════
# Stage 2: Runtime — slim production image
# ═══════════════════════════════════════════════
FROM debian:bookworm-slim AS runtime

RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the compiled binary
COPY --from=builder /app/target/release/sanskar_api ./sanskar_api

# Copy migrations (needed for sqlx::migrate! at runtime)
COPY migrations/ migrations/

# Default port
ENV PORT=8080
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:${PORT}/health || exit 1

CMD ["./sanskar_api"]
