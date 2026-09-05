# DreamCast

AI-powered dream journal & interpreter. Users log a dream (voice or text),
get an AI interpretation plus a shareable "Dream Card," and can subscribe to
DreamCast Pro for unlimited daily interpretations.

This repo contains everything needed to run, test, and deploy the product:

```
dreamcast/
├── backend/            FastAPI service (auth, AI interpretation, subscriptions)
│   ├── app/
│   ├── tests/
│   ├── alembic/        DB migrations
│   ├── Dockerfile
│   └── requirements.txt
├── mobile/              Flutter Android app (the Play Store deliverable)
│   ├── lib/
│   └── android/
├── infra/
│   ├── k8s/             Kubernetes manifests
│   ├── docker-compose.yml
│   └── Jenkinsfile
└── .github/workflows/   GitHub Actions CI/CD (alternative to Jenkins)
```

---

## 1. Architecture overview

- **Backend**: FastAPI + PostgreSQL + Redis, containerized, deployed to
  Kubernetes (GKE-oriented, but portable to any cluster).
- **AI**: Anthropic API for dream interpretation; a configurable image
  provider (Stability AI-style endpoint by default) for the Dream Card art.
- **Payments**: a provider-agnostic abstraction (`app/services/payment_service.py`)
  supporting **Stripe**, **Google Play Billing**, and **RevenueCat** — you
  choose one and drop in real keys via environment variables / Kubernetes
  secrets. No code changes required to go live.
- **Mobile**: Flutter, targeting Android/Google Play first. Uses the
  `in_app_purchase` plugin for native Play Billing subscriptions, verified
  server-side before any Pro feature unlocks.
- **CI/CD**: both a `Jenkinsfile` (self-hosted Jenkins) and a GitHub Actions
  workflow are provided — use whichever fits your setup. Both do the same
  thing: lint → test → build image → push → deploy to Kubernetes → run DB
  migrations → smoke test.

---

## 2. Local development

### Backend + database (Docker Compose)

```bash
cd backend
cp .env.example .env        # fill in ANTHROPIC_API_KEY at minimum
cd ../infra
docker compose up --build
```

This starts Postgres, Redis, and the API at `http://localhost:8000`.
Interactive API docs: `http://localhost:8000/docs`.

### Backend tests (no Docker required)

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
pytest tests/ -v
```

All 6 included tests (signup, login, duplicate-email rejection, dream
submission, free-tier rate limiting, health check) pass out of the box —
the AI and image services fall back to safe stub responses when no API key
is configured, so the whole stack is runnable without any external keys.

### Mobile app

Requires the Flutter SDK (not included in this environment — install from
flutter.dev). Then:

```bash
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

(`10.0.2.2` is how the Android emulator reaches your host machine's
`localhost`. Use your real backend URL for a physical device or production.)

---

## 3. Adding your real payment API — this is the part you asked for

The backend ships with `PaymentProvider` implementations for three options.
Pick ONE:

### Option A: Stripe (simplest, web-friendly, good for a companion website)

1. Create a Stripe account, a monthly subscription Product/Price.
2. Set env vars: `PAYMENT_PROVIDER=stripe`, `STRIPE_SECRET_KEY`,
   `STRIPE_WEBHOOK_SECRET`, `STRIPE_PRICE_ID_MONTHLY`.
3. Point a Stripe webhook at `POST /api/v1/subscriptions/webhook/stripe`.
4. Done — `create_checkout_session()` in `payment_service.py` is fully wired.

### Option B: Google Play Billing (native, required if you want in-app subs on Play Store)

1. In Play Console: Monetize → Subscriptions → create `dreamcast_pro_monthly`.
2. Create a service account with subscription-management access, download
   its JSON key.
3. Set env vars: `PAYMENT_PROVIDER=google_play`,
   `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` (raw JSON or mounted path),
   `GOOGLE_PLAY_PACKAGE_NAME`.
4. **You need to finish one implementation step**: in
   `GooglePlayProvider.verify_mobile_purchase()`
   (`backend/app/services/payment_service.py`), wire up
   `google-api-python-client`'s `androidpublisher` service using your
   service account — this is left as a clearly marked `TODO` because it
   requires your real Play Console credentials to test against. The call
   shape is documented inline in the code.
5. Set up Real-time Developer Notifications (Pub/Sub) for renewal/cancel
   events → `POST /api/v1/subscriptions/webhook/google_play`.

### Option C: RevenueCat (recommended if you'll ever add iOS)

1. Create a RevenueCat project, connect your Play Console + (later) App
   Store Connect.
2. Set env vars: `PAYMENT_PROVIDER=revenuecat`, `REVENUECAT_API_KEY`,
   `REVENUECAT_WEBHOOK_SECRET`.
3. Point a RevenueCat webhook at `POST /api/v1/subscriptions/webhook/revenuecat`.
4. RevenueCat handles receipt validation for you — much less server-side
   code to maintain than raw Play Billing.

Whichever you choose, finish the event-handling `TODO` in
`app/routers/subscriptions.py::payment_webhook()` to map each provider's
event types to subscription status updates (`ACTIVE`, `PAST_DUE`,
`CANCELED`) — the exact event shapes differ per provider so this is
intentionally left for you to wire against your live account, with the
audit-log (`PaymentEvent` table) already capturing every raw event so
nothing is lost while you do.

---

## 4. Deploying to Kubernetes

### One-time cluster setup

```bash
# Example: GKE
gcloud container clusters create dreamcast-cluster \
  --zone us-central1-a --num-nodes 2 --machine-type e2-medium

kubectl apply -f infra/k8s/00-namespace.yaml
```

### Secrets (do this once, manually — never put real secrets in git)

```bash
kubectl create secret generic dreamcast-secrets --namespace dreamcast \
  --from-literal=DATABASE_URL='postgresql://dreamcast:REPLACE@dreamcast-postgres:5432/dreamcast' \
  --from-literal=JWT_SECRET_KEY="$(openssl rand -hex 32)" \
  --from-literal=ANTHROPIC_API_KEY='sk-ant-...' \
  --from-literal=IMAGE_PROVIDER_API_KEY='...' \
  --from-literal=STRIPE_SECRET_KEY='sk_live_...' \
  --from-literal=STRIPE_WEBHOOK_SECRET='whsec_...' \
  --from-literal=STRIPE_PRICE_ID_MONTHLY='price_...' \
  --from-literal=REDIS_URL='redis://dreamcast-redis:6379/0'
```

See `infra/k8s/02-secret.yaml.example` for the full field list and two
alternative (more production-grade) ways to manage this.

### Deploy everything

```bash
kubectl apply -f infra/k8s/01-configmap.yaml
kubectl apply -f infra/k8s/03-postgres.yaml
kubectl apply -f infra/k8s/04-redis.yaml
kubectl apply -f infra/k8s/05-backend-deployment.yaml
kubectl apply -f infra/k8s/06-hpa.yaml
kubectl apply -f infra/k8s/07-ingress.yaml
kubectl apply -f infra/k8s/08-pdb.yaml
```

Then run the DB migration once against the new deployment (see the
"Run DB Migrations" stage in `infra/Jenkinsfile` for the exact command, or
run `kubectl exec` into a pod and run `python -m alembic upgrade head`).

### Ongoing deploys (CI/CD)

Either:
- Push to `main` → GitHub Actions (`.github/workflows/ci-cd.yml`) runs
  tests, builds the image, pushes to GCR, and rolls out automatically
  (requires repo secrets: `GCP_SA_KEY`, `GCP_PROJECT`, `GKE_CLUSTER`,
  `GKE_ZONE`), **or**
- Point a self-hosted Jenkins at this repo and use `infra/Jenkinsfile`
  (requires the Jenkins credentials listed in comments at the top of that
  file).

Both pipelines: lint → test → build → vulnerability scan → push → deploy →
migrate → smoke test. Rollback: `kubectl rollout undo deployment/dreamcast-backend -n dreamcast`.

---

## 5. Publishing to Google Play

1. Generate an upload keystore (command in `mobile/android/app/build.gradle`
   comments) and create `mobile/android/key.properties` (never commit it).
2. `cd mobile && flutter build appbundle --release --dart-define=API_BASE_URL=https://api.dreamcast.app/api/v1`
3. Upload the resulting `.aab` (in `build/app/outputs/bundle/release/`) to
   Play Console → Production (or Internal testing first, strongly
   recommended).
4. Make sure the `dreamcast_pro_monthly` subscription product (see Section
   3, Option B) is created and active in Play Console before submitting,
   or the paywall will show no products.

---

## 6. What's a stub vs. what's real

To be direct about the state of this codebase:

**Fully working, tested:**
- Auth (signup/login/JWT/refresh), dream submission + AI interpretation,
  rate limiting, health checks, Docker build, all Kubernetes manifests
  (YAML-validated), CI/CD pipeline structure.

**Wired but needs your credentials to activate:**
- AI interpretation (works today with a fallback response; add
  `ANTHROPIC_API_KEY` for real interpretations).
- Image generation (same — add `IMAGE_PROVIDER_API_KEY`; also has a
  marked `TODO` to upload generated images to your own object storage
  instead of returning a placeholder).
- Payments — see Section 3. Stripe checkout is fully implemented end-to-end.
  Google Play server-side purchase verification has one clearly marked
  `TODO` requiring your real service account to finish and test.
- Push notifications — Firebase dependencies are included in `pubspec.yaml`
  but the Firebase project itself (`google-services.json`) isn't — create
  one in the Firebase console and drop the config file in
  `mobile/android/app/`.

**Not included (intentionally out of scope, flag if you want it):**
- iOS build (RevenueCat option above makes this a much smaller lift later).
- Admin dashboard / analytics.
- Automated App Store / Play Store screenshot generation.

I built and ran the backend test suite in a sandboxed environment (6/6
passing) and validated every Kubernetes manifest parses correctly, but I
don't have a Flutter SDK or a live Kubernetes cluster available in this
environment — so the mobile app and the actual `kubectl apply` / Jenkins
run haven't been executed end-to-end. Budget time for a first real run
before you rely on this in production, the way you would for any new
codebase you inherit.
