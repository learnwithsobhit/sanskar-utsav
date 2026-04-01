#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════
#  Sanskar Utsav — Dev Startup Script
#  Starts all services and the backend for local testing.
# ════════════════════════════════════════════════════════════

set -e

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
API_DIR="$ROOT_DIR/sanskar_api"
APP_DIR="$ROOT_DIR/sanskar_app"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GOLD='\033[0;33m'
NC='\033[0m' # No Color

banner() {
  echo ""
  echo -e "${GOLD}  ═══════════════════════════════════════════${NC}"
  echo -e "${GOLD}   🕉️  संस्कार उत्सव — Sanskar Utsav${NC}"
  echo -e "${GOLD}   Shrihan's Yogyopaveet Ceremony Platform${NC}"
  echo -e "${GOLD}  ═══════════════════════════════════════════${NC}"
  echo ""
}

log()  { echo -e "  ${CYAN}▸${NC} $1"; }
ok()   { echo -e "  ${GREEN}✅ $1${NC}"; }
warn() { echo -e "  ${YELLOW}⚠️  $1${NC}"; }
err()  { echo -e "  ${RED}❌ $1${NC}"; }

# ─── Preflight checks ──────────────────────────────────────
check_deps() {
  log "Checking dependencies..."

  local missing=0

  if ! command -v docker &>/dev/null; then
    err "Docker is not installed. Install: https://docs.docker.com/get-docker/"
    missing=1
  fi

  if ! command -v cargo &>/dev/null; then
    err "Rust/Cargo is not installed. Install: https://rustup.rs/"
    missing=1
  fi

  if ! command -v flutter &>/dev/null; then
    warn "Flutter is not installed. Frontend won't start, but backend will work."
  fi

  if [ $missing -eq 1 ]; then
    err "Missing required dependencies. Aborting."
    exit 1
  fi

  ok "Dependencies OK"
}

# ─── Docker services ───────────────────────────────────────
start_docker() {
  log "Starting infrastructure (Postgres, Redis, NATS, Jaeger)..."
  cd "$ROOT_DIR"

  if ! docker info &>/dev/null; then
    err "Docker daemon is not running. Please start Docker Desktop first."
    exit 1
  fi

  docker compose up -d

  log "Waiting for services to be healthy..."

  # Wait for Postgres
  local retries=30
  until docker exec sanskar_postgres pg_isready -U sanskar -d sanskar_utsav &>/dev/null; do
    retries=$((retries - 1))
    if [ $retries -le 0 ]; then
      err "Postgres failed to start"
      exit 1
    fi
    sleep 1
  done
  ok "PostgreSQL ready"

  # Wait for Redis
  retries=15
  until docker exec sanskar_redis redis-cli ping 2>/dev/null | grep -q PONG; do
    retries=$((retries - 1))
    if [ $retries -le 0 ]; then
      err "Redis failed to start"
      exit 1
    fi
    sleep 1
  done
  ok "Redis ready"

  # Wait for NATS
  retries=15
  until curl -sf http://localhost:8222/healthz &>/dev/null; do
    retries=$((retries - 1))
    if [ $retries -le 0 ]; then
      warn "NATS monitoring not reachable (may still work)"
      break
    fi
    sleep 1
  done
  ok "NATS ready"

  ok "All infrastructure services running"
}

# ─── Rust backend ──────────────────────────────────────────
start_backend() {
  log "Building & starting Rust API..."
  cd "$API_DIR"

  # Build first to catch errors
  cargo build 2>&1 | tail -3

  ok "Backend built successfully"
  log "Starting API server on http://localhost:8080 ..."
  echo ""

  # Run in background, stream logs
  cargo run &
  BACKEND_PID=$!

  # Wait for the server to respond
  local retries=30
  until curl -sf http://localhost:8080/ &>/dev/null; do
    retries=$((retries - 1))
    if [ $retries -le 0 ]; then
      warn "Backend health check timed out (may still be starting)"
      break
    fi
    sleep 1
  done

  ok "Backend API running (PID: $BACKEND_PID)"
}

# ─── Flutter app ───────────────────────────────────────────
start_flutter() {
  if ! command -v flutter &>/dev/null; then
    warn "Flutter not found — skipping frontend"
    return
  fi

  log "Starting Flutter app..."
  cd "$APP_DIR"

  flutter run -d chrome --web-port=3000 &
  FLUTTER_PID=$!

  ok "Flutter web app starting (PID: $FLUTTER_PID)"
}

# ─── Display dashboard ────────────────────────────────────
show_dashboard() {
  echo ""
  echo -e "${GOLD}  ═══════════════════════════════════════════${NC}"
  echo -e "${GOLD}   🛕 All Services Running!${NC}"
  echo -e "${GOLD}  ═══════════════════════════════════════════${NC}"
  echo ""
  echo -e "  ${CYAN}Service              URL${NC}"
  echo -e "  ─────────────────  ──────────────────────────"
  echo -e "  🌐 Backend API      ${GREEN}http://localhost:8080${NC}"
  echo -e "  🎨 Flutter Web      ${GREEN}http://localhost:3000${NC}"
  echo -e "  📊 Jaeger Traces    ${GREEN}http://localhost:16686${NC}"
  echo -e "  📡 NATS Monitor     ${GREEN}http://localhost:8222${NC}"
  echo -e "  🗄️  PostgreSQL       localhost:5432"
  echo -e "  📦 Redis             localhost:6379"
  echo ""
  echo -e "  ${YELLOW}Test credentials:${NC}"
  echo -e "  Admin:   ${GREEN}ADMIN2026${NC}"
  echo -e "  Guest:   ${GREEN}SHRIHAN2026${NC} / ${GREEN}RSVP001${NC} / ${GREEN}RSVP002${NC}"
  echo ""
  echo -e "  ${CYAN}Quick API tests:${NC}"
  echo -e "  curl http://localhost:8080/"
  echo -e "  curl -X POST http://localhost:8080/api/auth/login -H 'Content-Type: application/json' -d '{\"invite_code\":\"ADMIN2026\"}'"
  echo ""
  echo -e "  ${YELLOW}Press Ctrl+C to stop all services${NC}"
  echo ""
}

# ─── Cleanup on exit ──────────────────────────────────────
cleanup() {
  echo ""
  log "Shutting down..."

  if [ -n "$BACKEND_PID" ]; then
    kill $BACKEND_PID 2>/dev/null && log "Stopped backend (PID: $BACKEND_PID)"
  fi
  if [ -n "$FLUTTER_PID" ]; then
    kill $FLUTTER_PID 2>/dev/null && log "Stopped Flutter (PID: $FLUTTER_PID)"
  fi

  echo ""
  read -p "  Stop Docker containers too? (y/N): " stop_docker
  if [[ "$stop_docker" =~ ^[Yy]$ ]]; then
    cd "$ROOT_DIR"
    docker compose down
    ok "Docker containers stopped"
  else
    log "Docker containers left running"
  fi

  echo ""
  ok "Goodbye! 🙏"
  exit 0
}

trap cleanup SIGINT SIGTERM

# ─── Main ──────────────────────────────────────────────────
main() {
  banner
  check_deps

  case "${1:-all}" in
    infra|docker)
      start_docker
      show_dashboard
      wait
      ;;
    api|backend)
      start_docker
      start_backend
      show_dashboard
      wait
      ;;
    app|flutter)
      start_flutter
      wait
      ;;
    all)
      start_docker
      start_backend
      start_flutter
      show_dashboard
      wait
      ;;
    stop)
      cd "$ROOT_DIR"
      docker compose down
      ok "All containers stopped"
      ;;
    status)
      echo ""
      log "Docker containers:"
      docker compose -f "$ROOT_DIR/docker-compose.yml" ps
      echo ""
      log "API health:"
      curl -sf http://localhost:8080/ 2>/dev/null && ok "Backend is UP" || warn "Backend is DOWN"
      echo ""
      ;;
    *)
      echo "Usage: $0 [command]"
      echo ""
      echo "Commands:"
      echo "  all       Start everything (default)"
      echo "  infra     Start only Docker services"
      echo "  api       Start Docker + Rust backend"
      echo "  app       Start only Flutter frontend"
      echo "  stop      Stop Docker containers"
      echo "  status    Check service status"
      ;;
  esac
}

main "$@"
