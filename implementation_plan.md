# Phase 5: Deployment

Deploy the Sanskar Utsav platform to production — Rust backend on **Railway**, Flutter web app on **Firebase Hosting**, and media storage on **AWS S3**.

## User Review Required

> [!IMPORTANT]
> **Platform choices** — Please confirm:
> 1. **Backend**: Railway (auto-deploys from GitHub, includes Postgres/Redis add-ons) — or do you prefer a different platform?
> 2. **Frontend**: Firebase Hosting (free, fast CDN, already used in your BrijYatra project) — or Vercel/Netlify?
> 3. **S3 Storage**: Real AWS S3 with a bucket — do you have an AWS account set up, or should we use Railway's volume storage for now?
> 4. **Domain**: Do you have a custom domain (e.g., `sanskarutsav.com`), or are you fine with the Railway/Firebase default URLs?

> [!WARNING]
> **Secrets**: The `.env` file contains dev credentials. We'll need production values for `DATABASE_URL`, `REDIS_URL`, `AWS_ACCESS_KEY_ID`, etc. **Never commit production secrets to GitHub.**

## Proposed Changes

### 1. Backend Deployment (Railway)

#### [NEW] [Dockerfile](file:///Users/shobhit/MyDevelopment/new_prject/sanskar_utsav/sanskar_api/Dockerfile)
- Multi-stage Rust build (builder → slim runtime image)
- Copies migrations for auto-run on startup
- Sets production-optimized flags (`--release`)

#### [NEW] [railway.toml](file:///Users/shobhit/MyDevelopment/new_prject/sanskar_utsav/railway.toml)
- Configure Railway build settings and healthcheck
- Point to `sanskar_api/` subdirectory

#### [MODIFY] [main.rs](file:///Users/shobhit/MyDevelopment/new_prject/sanskar_utsav/sanskar_api/src/main.rs)
- Read `PORT` from env (Railway provides it dynamically)
- Make NATS/Jaeger optional (not available on Railway free tier)
- Graceful fallback when services are unavailable

#### Railway Services Setup:
| Service | How |
|---------|-----|
| **PostgreSQL** | Railway Postgres add-on (free tier: 1GB) |
| **Redis** | Railway Redis add-on (free tier: 256MB) |
| **NATS** | Skip for production (use Redis pub/sub instead, or make optional) |
| **Jaeger** | Skip for production (use Railway logs) |

---

### 2. Frontend Deployment (Firebase Hosting)

#### [NEW] [firebase.json](file:///Users/shobhit/MyDevelopment/new_prject/sanskar_utsav/sanskar_app/firebase.json)
- Configure hosting with rewrites for SPA (single-page app)

#### [NEW] [.firebaserc](file:///Users/shobhit/MyDevelopment/new_prject/sanskar_utsav/sanskar_app/.firebaserc)
- Firebase project configuration

#### [MODIFY] [api_config.dart](file:///Users/shobhit/MyDevelopment/new_prject/sanskar_utsav/sanskar_app/lib/config/api_config.dart)
- Switch API URL to production Railway URL
- Add environment-aware URL switching (dev vs prod)

#### Build & Deploy Steps:
```bash
cd sanskar_app
flutter build web --release --web-renderer canvaskit
firebase deploy --only hosting
```

---

### 3. S3 Storage (AWS)

#### [MODIFY] [.env (production)](file:///Users/shobhit/MyDevelopment/new_prject/sanskar_utsav/sanskar_api/.env)
- Set real AWS credentials (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`)
- Set `S3_BUCKET` to production bucket name
- Set `S3_PUBLIC_URL` to CloudFront/S3 public URL
- Remove `S3_ENDPOINT` (uses real AWS endpoint)

---

### 4. Production Infrastructure Files

#### [NEW] [.dockerignore](file:///Users/shobhit/MyDevelopment/new_prject/sanskar_utsav/sanskar_api/.dockerignore)
- Exclude `target/`, `.git/`, `.env`

#### [MODIFY] [.gitignore](file:///Users/shobhit/MyDevelopment/new_prject/sanskar_utsav/.gitignore)
- Ensure `.env` and production secrets are excluded

#### [NEW] [deploy.sh](file:///Users/shobhit/MyDevelopment/new_prject/sanskar_utsav/deploy.sh)
- One-command deploy script for both backend and frontend

## Open Questions

> [!IMPORTANT]
> 1. **Railway project**: Do you already have a Railway account? Should I help set one up?
> 2. **Firebase project**: Do you have a Firebase project for this? (You had `brijyatra` before — want a new one like `sanskar-utsav`?)
> 3. **AWS S3**: Do you have an AWS account with S3 access? If not, we can use Railway volumes or a free tier S3-compatible service (e.g., Cloudflare R2).
> 4. **NATS**: Should we make NATS fully optional in production (connect if available, skip if not)?
> 5. **Custom domain**: Any domain to configure?

## Verification Plan

### Automated Tests
```bash
# Backend health
curl https://<railway-url>/health

# API login
curl -X POST https://<railway-url>/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"invite_code":"ADMIN2026"}'

# Frontend loads
curl -I https://<firebase-url>/
```

### Manual Verification
- Login flow on deployed Flutter web app
- Upload a photo and verify it appears in gallery
- Send a chat message and verify delivery
- WebSocket connection on production
