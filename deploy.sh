#!/bin/bash
set -e

# ═══════════════════════════════════════════
# 🛕 Sanskar Utsav — Deploy Script
# ═══════════════════════════════════════════
#
# Usage:
#   ./deploy.sh              # Deploy both backend + frontend
#   ./deploy.sh backend      # Deploy backend only (Railway)
#   ./deploy.sh frontend     # Deploy frontend only (Firebase)
#
# Prerequisites:
#   - Railway CLI: npm i -g @railway/cli && railway login
#   - Firebase CLI: npm i -g firebase-tools && firebase login
#   - Flutter SDK installed
#
# Before first deploy:
#   1. Create Railway project: railway init
#   2. Add Postgres add-on in Railway dashboard
#   3. Add Redis add-on in Railway dashboard
#   4. Set env vars in Railway dashboard (see .env.production)
#   5. Create Firebase project: firebase projects:create sanskar-utsav
#   6. Update .firebaserc with your project ID

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
API_DIR="$SCRIPT_DIR/sanskar_api"
APP_DIR="$SCRIPT_DIR/sanskar_app"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo -e "${CYAN} 🛕 $1${NC}"
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
}

print_step() {
    echo -e "  ${YELLOW}▸${NC} $1"
}

print_success() {
    echo -e "  ${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "  ${RED}❌ $1${NC}"
}

# ─── Backend Deploy (Railway) ───
deploy_backend() {
    print_header "Deploying Backend to Railway"
    
    # Check Railway CLI
    if ! command -v railway &> /dev/null; then
        print_error "Railway CLI not installed. Run: npm i -g @railway/cli"
        exit 1
    fi

    # Check if logged in
    if ! railway whoami &> /dev/null 2>&1; then
        print_error "Not logged into Railway. Run: railway login"
        exit 1
    fi

    print_step "Pushing to Railway..."
    cd "$SCRIPT_DIR"
    railway up --detach

    print_success "Backend deployed to Railway!"
    echo ""
    echo -e "  ${CYAN}Check status:${NC} railway status"
    echo -e "  ${CYAN}View logs:${NC}    railway logs"
    echo -e "  ${CYAN}Open URL:${NC}     railway open"
}

# ─── Frontend Deploy (Firebase) ───
deploy_frontend() {
    print_header "Deploying Frontend to Firebase"

    # Check Firebase CLI
    if ! command -v firebase &> /dev/null; then
        print_error "Firebase CLI not installed. Run: npm i -g firebase-tools"
        exit 1
    fi

    # Check Flutter
    if ! command -v flutter &> /dev/null; then
        print_error "Flutter not found in PATH"
        exit 1
    fi

    # Get Railway URL for API
    API_URL="${DEPLOY_API_URL:-}"
    if [ -z "$API_URL" ]; then
        echo ""
        echo -e "  ${YELLOW}Enter your Railway backend URL${NC}"
        echo -e "  ${YELLOW}(e.g., https://sanskar-api-production.up.railway.app):${NC}"
        read -r API_URL
    fi

    if [ -z "$API_URL" ]; then
        print_error "API URL is required for frontend build"
        exit 1
    fi

    # Build Flutter web
    print_step "Building Flutter web app..."
    cd "$APP_DIR"
    flutter build web --release \
        --dart-define="API_URL=$API_URL"

    print_success "Flutter build complete"

    # Deploy to Firebase
    print_step "Deploying to Firebase Hosting..."
    firebase deploy --only hosting

    print_success "Frontend deployed to Firebase!"
    echo ""
    echo -e "  ${CYAN}Your app:${NC} $(firebase hosting:channel:list 2>/dev/null | head -1 || echo 'Check Firebase console')"
}

# ─── Main ───
case "${1:-all}" in
    backend)
        deploy_backend
        ;;
    frontend)
        deploy_frontend
        ;;
    all)
        deploy_backend
        echo ""
        deploy_frontend
        ;;
    *)
        echo "Usage: ./deploy.sh [backend|frontend|all]"
        exit 1
        ;;
esac

echo ""
print_header "Deployment Complete! 🙏"
echo ""
