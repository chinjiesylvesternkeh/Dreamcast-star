## DreamCast plans (XAF)

The app sells three monthly plans, billed in XAF through Flutterwave
(MTN MoMo, Orange Money, card). They are served and enforced by the
FastAPI backend (`backend/app/plans.py` is the single source of truth):

| Plan   | Price / month | Readings        | Depth                                          |
|--------|---------------|-----------------|------------------------------------------------|
| Free   | —             | 1 per week      | Standard                                       |
| Lucid  | XAF 1,000     | 1 per day       | Standard                                       |
| Mystic | XAF 2,000     | up to 5 per day | In-depth: key symbols + a practical reflection |
| Oracle | XAF 5,000     | up to 15 per day | Oracle: patterns across recent dreams + a guiding question |

To go live, set in the backend environment:

- `FLW_SECRET_KEY` — Flutterwave secret key
- `FLW_WEBHOOK_SECRET` — any random string; paste the same value in
  Flutterwave Dashboard → Settings → Webhooks → Secret hash
- Webhook URL: `https://<api-domain>/api/v1/subscriptions/webhook/flutterwave`
- Optional `FLW_PLAN_ID_LUCID` / `FLW_PLAN_ID_MYSTIC` / `FLW_PLAN_ID_ORACLE`
  — Flutterwave payment-plan ids. When set, plans renew automatically each
  month; otherwise each payment buys 30 days with no automatic charge.

Run `make migrate` after deploying (adds the `plan` column).

The Node server documented below (`infra/server.js`) predates this and is
no longer used by the app.

# Payment Backend (Flutterwave — Mobile Money + Card Subscriptions)

Minimal Node/Express backend that lets your Android app charge monthly
subscriptions (normal / premium) via MTN/Orange Mobile Money and cards,
using Flutterwave as the payment processor.

## 1. Install dependencies

```bash
npm install
```

## 2. Configure environment

```bash
cp .env.example .env
```

Fill in:
- `FLW_SECRET_KEY` / `FLW_PUBLIC_KEY` — from your Flutterwave dashboard (Settings → API).
- `FLW_WEBHOOK_SECRET` — invent a random string, then paste the SAME string into
  Flutterwave Dashboard → Settings → Webhooks → "Secret Hash".
- `PLAN_ID_NORMAL` / `PLAN_ID_PREMIUM` — create these once via the API (see below).

## 3. Create your two subscription plans (one-time)

```bash
curl -X POST https://api.flutterwave.com/v3/payment-plans \
  -H "Authorization: Bearer YOUR_SECRET_KEY" \
  -H "Content-Type: application/json" \
  -d '{"amount": 2000, "name": "Normal Monthly", "interval": "monthly", "currency": "XAF"}'

curl -X POST https://api.flutterwave.com/v3/payment-plans \
  -H "Authorization: Bearer YOUR_SECRET_KEY" \
  -H "Content-Type: application/json" \
  -d '{"amount": 5000, "name": "Premium Monthly", "interval": "monthly", "currency": "XAF"}'
```

Copy the returned `id` values into `.env` as `PLAN_ID_NORMAL` and `PLAN_ID_PREMIUM`.

## 4. Run the server

```bash
npm start
```

## 5. Set your webhook URL in Flutterwave

In the Flutterwave dashboard, set your webhook URL to:
```
https://yourdomain.com/api/webhook
```
(For local testing, use a tunnel like `ngrok http 3000` and use the ngrok URL.)

## 6. How your Android app talks to this backend

**Start a subscription:**
```
POST /api/subscribe
{ "userId": "u123", "email": "user@example.com", "phone": "6XXXXXXXX", "name": "User", "tier": "premium" }
```
Returns `{ checkoutUrl }` — open this in a WebView or the system browser (Chrome Custom Tabs).

**After the WebView redirects back to your redirect_url:**
```
GET /api/verify?transaction_id=xxxx
```

**On app launch / periodically, check entitlement:**
```
GET /api/status/u123
```
Returns `{ tier, status, renewsAt }` — use this to gate premium features.

## Before going to production

- Replace `db.js` (JSON file) with a real database — it is a placeholder only.
- Put this server behind HTTPS (required by Flutterwave for webhooks).
- Never ship `FLW_SECRET_KEY` inside the Android app — only the backend should hold it.
- Add retry/reconciliation logic for renewals (`charge.completed` fires monthly per plan).
- Test in Flutterwave's sandbox mode before switching to live keys.
