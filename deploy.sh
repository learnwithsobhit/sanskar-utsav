#!/bin/bash
set -e

# ═══════════════════════════════════════════════
#  Sanskar Utsav — Deployment Script
# ═══════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
API_DIR="$SCRIPT_DIR/sanskar_api"
APP_DIR="$SCRIPT_DIR/sanskar_app"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN} 🛕 Sanskar Utsav — $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
}

# ─── Deploy Backend to Railway ───
deploy_backend() {
    print_header "Deploying Backend to Railway"

    # Check Railway CLI
    if ! command -v railway &> /dev/null; then
        echo -e "${YELLOW}Installing Railway CLI...${NC}"
        npm install -g @railway/cli
    fi

    # Check login
    if ! railway whoami &> /dev/null 2>&1; then
        echo -e "${YELLOW}Please login to Railway:${NC}"
        railway login
    fi

    cd "$API_DIR"

    echo -e "  ${CYAN}▸${NC} Deploying to Railway..."
    railway up --detach

    echo -e "  ${GREEN}✅ Backend deployed to Railway!${NC}"
    echo ""
    echo -e "  ${YELLOW}📋 Next steps:${NC}"
    echo -e "     1. Add PostgreSQL plugin in Railway dashboard"
    echo -e "     2. Add Redis plugin in Railway dashboard"
    echo -e "     3. Set environment variables (see implementation_plan.md)"
    echo -e "     4. Get your Railway domain from Settings → Networking"
    echo ""
}

# ─── Deploy Flutter Web to Firebase ───
deploy_web() {
    print_header "Deploying Flutter Web to Firebase"

    # Check Firebase CLI
    if ! command -v firebase &> /dev/null; then
        echo -e "${YELLOW}Installing Firebase CLI...${NC}"
        npm install -g firebase-tools
    fi

    # Check login
    if ! firebase projects:list &> /dev/null 2>&1; then
        echo -e "${YELLOW}Please login to Firebase:${NC}"
        firebase login
    fi

    cd "$APP_DIR"

    # Get API URL
    API_URL="${API_BASE_URL:-}"
    if [ -z "$API_URL" ]; then
        echo -e "${YELLOW}Enter your Railway backend URL (e.g., https://sanskar-api-production.up.railway.app):${NC}"
        read -r API_URL
    fi

    if [ -z "$API_URL" ]; then
        echo -e "${RED}❌ API_BASE_URL is required for production build${NC}"
        exit 1
    fi

    echo -e "  ${CYAN}▸${NC} Building Flutter web (API: $API_URL)..."
    flutter build web --release --dart-define="API_BASE_URL=$API_URL"

    echo -e "  ${CYAN}▸${NC} Deploying to Firebase Hosting..."
    firebase deploy --only hosting

    echo -e "  ${GREEN}✅ Flutter web deployed to Firebase!${NC}"
}

# ─── Build Flutter Web Only (no deploy) ───
build_web() {
    print_header "Building Flutter Web"

    cd "$APP_DIR"

    API_URL="${API_BASE_URL:-http://localhost:8080}"
    echo -e "  ${CYAN}▸${NC} Building Flutter web (API: $API_URL)..."
    flutter build web --release --dart-define="API_BASE_URL=$API_URL"

    echo -e "  ${GREEN}✅ Build complete: $APP_DIR/build/web${NC}"
}

# ─── Main ───
case "${1:-help}" in
    backend)
        deploy_backend
        ;;
    web)
        deploy_web
        ;;
    build)
        build_web
        ;;
    all)
        deploy_backend
        deploy_web
        ;;
    *)
        echo ""
        echo "Usage: ./deploy.sh <command>"
        echo ""
        echo "Commands:"
        echo "  backend    Deploy Rust API to Railway"
        echo "  web        Build & deploy Flutter web to Firebase"
        echo "  build      Build Flutter web only (no deploy)"
        echo "  all        Deploy everything"
        echo ""
        echo "Environment variables:"
        echo "  API_BASE_URL   Backend API URL (for Flutter web build)"
        echo ""
        ;;
esac
