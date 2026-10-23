## DreamCast plans (Google Play subscriptions)

The Android app sells three monthly auto-renewing subscriptions through
**Google Play Billing** (required by Play's Payments policy for digital
subscriptions). Plans are defined in `backend/app/plans.py`, which also
enforces each plan's limits:

| Plan   | Play product id            | Base price (USD) | Readings         | Depth |
|--------|----------------------------|------------------|------------------|-------|
| Free   | —                          | —                | 1 per week       | Standard |
| Lucid  | `dreamcast_lucid_monthly`  | US$1.79 / month  | 1 per day        | Standard |
| Mystic | `dreamcast_mystic_monthly` | US$3.49 / month  | up to 5 per day  | In-depth: key symbols + a practical reflection |
| Oracle | `dreamcast_oracle_monthly` | US$8.79 / month  | up to 15 per day | Oracle: patterns across recent dreams + a guiding question |

USD prices are the former XAF 1,000 / 2,000 / 5,000 converted at ~570 XAF
per USD. Set them as the base price in Play Console and let Play convert to
local currencies; the app always shows the localized price Play returns.

### Play Console setup

1. **Monetize > Products > Subscriptions**: create the three products above,
   each with an auto-renewing base plan billed monthly (no free trial).
2. **Users & permissions**: grant a service account "View financial data" and
   "Manage orders and subscriptions"; set its JSON as
   `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` on the backend
   (`PAYMENT_PROVIDER=google_play`).
3. **Real-time developer notifications**: create a Pub/Sub topic, grant
   `google-play-developer-notifications@system.gserviceaccount.com` publish
   rights, add the topic under Monetization setup, and create a push
   subscription to
   `https://<api-domain>/api/v1/subscriptions/webhook/google_play?token=<GOOGLE_PLAY_RTDN_TOKEN>`.
4. Run `make migrate` after deploying.

### Play policy checklist

Done in the app:

- Google Play Billing only for subscriptions; no external payment links.
- Play Billing Library 9.1 (`in_app_purchase_android` 0.5.5) — Play requires 8+.
- `targetSdkVersion 36` — required for new apps/updates since 31 Aug 2026.
- Paywall shows Play's localized price and period, states auto-renewal and
  how to cancel before purchase, and links to Play's subscription center,
  Restore purchases, Terms and Privacy Policy.
- Purchases are verified server-side before access is granted, then
  acknowledged; pending payments grant nothing until completed; plan changes
  replace the existing subscription (upgrade now, downgrade at renewal).
- Cancelled subscriptions keep access until the paid period ends.
- In-app account deletion (Account > Delete account) that warns the user to
  cancel their Play subscription; `DELETE /api/v1/users/me` removes all data.
- In-app reporting of AI-generated readings (flag icon on a reading);
  reports land in the `dream_reports` table for review.
- AI readings are labelled as reflection/entertainment, not medical advice.

Still required in Play Console (cannot be done in code):

- Host a **Privacy Policy** and **Terms of Service** and enter the privacy URL
  in App content. The app links to `https://dreamcast.app/privacy` and
  `/terms` by default — override with `--dart-define=PRIVACY_POLICY_URL=...`
  and `--dart-define=TERMS_URL=...`.
- **Account deletion URL**: a web page where users can request deletion
  without the app (App content > Data deletion).
- **Data safety** form: declare email (account), dream text and audio
  (voice entry, processed for speech-to-text), purchase history, and that
  dream text is sent to an AI provider for processing.
- **Content rating** questionnaire, **target audience** (not designed for
  children), and **Ads** declaration (no ads).
- Review the **moderation queue** (`dream_reports`) regularly.

# Payment Backend (Flutterwave — Mobile Money + Card Subscriptions)

> **Legacy — not used by the Android app.** Google Play requires Play
> Billing for in-app digital subscriptions, so the app no longer links to
> Flutterwave checkout. This standalone server is kept for reference only.

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
