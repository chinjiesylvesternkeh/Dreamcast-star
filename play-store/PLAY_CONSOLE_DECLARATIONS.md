# DreamCast — Play Console declarations

Copy-paste answers for **Play Console › DreamCast › Policy › App content**,
derived from what the app and backend actually do (app version 1.0.0).
You submit these under your own name, so read each one; if you later turn on
something listed under "Revisit if…", update the matching declaration first.

- Developer: CHINJIE Sylvester (Cameroon)
- Contact email: chinjiesylvestern@gmail.com
- Package: `com.dreamcast.app`

Public pages (live once GitHub Pages is enabled — see step 0):

| Page | URL |
|---|---|
| Privacy Policy | https://chinjiesylvesternkeh.github.io/Dreamcast-star/privacy.html |
| Terms of Service | https://chinjiesylvesternkeh.github.io/Dreamcast-star/terms.html |
| Account deletion | https://chinjiesylvesternkeh.github.io/Dreamcast-star/delete-account.html |

French versions live under `/fr/` (e.g. `…/Dreamcast-star/fr/privacy.html`);
the app opens the version matching the user's language. Play Console takes
one privacy URL — use the English one; each page links to its translation.

---

## 0. Publish the legal pages (5 minutes, do this first)

1. github.com/chinjiesylvesternkeh/Dreamcast-star › **Settings › Pages**.
2. Source: **Deploy from a branch** · Branch: **main** · Folder: **/docs** › Save.
3. After ~1 minute, open the three URLs above and check they load.

GitHub Pages on a free account requires the repository to be **public**. If
you want to keep the code private, host the four files in `docs/` anywhere
else (Netlify, Cloudflare Pages, your own domain) and rebuild the app with
`--dart-define=PRIVACY_POLICY_URL=… --dart-define=TERMS_URL=…`.

> The policies promise that server logs and backups are deleted within 30
> days and that email deletion requests are handled within 30 days. Configure
> your hosting to match (log retention ≤ 30 days, backup retention ≤ 30 days).

---

## 1. Privacy policy

- **Privacy policy URL:** `https://chinjiesylvesternkeh.github.io/Dreamcast-star/privacy.html`

## 2. App access

All functionality is behind sign-in → choose **"All or some functionality is
restricted"** and add instructions:

- **Name:** Reviewer account
- **Username:** `play-review@dreamcast-test.com` *(create this account in the
  live app before submitting; any email-format address works — the backend
  does not send email)*
- **Password:** a strong password you set when creating it
- **Instructions:**
  > Sign in with the credentials above on the "Log in" screen. Record a dream
  > on the Dream tab and tap "Reveal its meaning" to see an AI reading. Past
  > dreams are on the Archive tab. Subscription plans are under PLANS (top
  > right); the account icon next to it contains Manage subscription, Privacy
  > Policy, Terms, Log out and Delete account. The flag icon on a reading
  > reports AI-generated content. The app is available in English and French
  > (account icon › Language).

The backend must be online at the URL the release was built with, or review
will fail.

## 3. Ads

- **Does your app contain ads?** **No**

## 4. Content rating (IARC questionnaire)

- **Email:** chinjiesylvestern@gmail.com
- **Category:** **All Other App Types** (not a game, not social/communication)

| Question theme | Answer | Note |
|---|---|---|
| Violence, blood, gore | No | |
| Fear / horror content | No | Readings are calm by design; no frightening media |
| Sexuality, nudity | No | |
| Profanity / crude humor | No | |
| Drugs, alcohol, tobacco | No | |
| Gambling or simulated gambling | No | |
| Users can interact or exchange content with each other in the app | **No** | No chat, feeds or profiles. Sharing a Dream Card hands an image to the phone's share sheet. |
| Shares the user's current physical location with other users | No | |
| Allows purchase of digital goods | **Yes** | Google Play subscriptions |
| Unrestricted internet / web browsing | No | Only fixed links (legal pages, Play) |
| Generative AI content (if asked) | **Yes** | Text readings and images generated from the user's own dream; users can report output in-app |

Expected rating: Everyone / PEGI 3 range. Target audience below is 18+
regardless of the rating.

## 5. Target audience and content

- **Target age groups:** **18 and over** only.
- **Could your app unintentionally appeal to children?** **No** — dark,
  adult-oriented design; no cartoon characters, games or child themes.
- **Store presence:** no "Teacher Approved"/Families programs.

Choosing 18+ keeps DreamCast out of the Families policy, which matches the
Terms ("you must be at least 18").

## 6. News apps

- **Is your app a news app?** **No**

## 7. Health apps

- **Does your app have health features?** **No.** DreamCast offers
  interpretive readings for reflection/entertainment and says so in-app and in
  the Terms; it does not diagnose, treat, track or advise on health.

## 8. Financial features

- **None of the listed financial features.**

## 9. Government apps

- **No**

## 10. Advertising ID

- **Does your app use advertising ID?** **No.** The manifest explicitly
  removes `com.google.android.gms.permission.AD_ID`.

## 11. Data safety

### Overview questions

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all of the user data collected by your app encrypted in transit? | **Yes** (HTTPS only — build with an `https://` API URL) |
| Do you provide a way for users to request that their data is deleted? | **Yes** |
| Account deletion URL | `https://chinjiesylvesternkeh.github.io/Dreamcast-star/delete-account.html` |
| Has your app undergone independent security review (MASA)? | No |

"Shared" means transferred to a third party for its own purposes. Sending data
to service providers that process it on your behalf (hosting, Anthropic for
readings, the image provider, Google Play for billing) is **not** sharing
under Play's definitions, so every row below is **Collected: Yes · Shared: No**.

### Data types

| Category › Type | Collected | Shared | Ephemeral? | Required or optional | Purposes |
|---|---|---|---|---|---|
| Personal info › **Email address** | Yes | No | No | Required | App functionality, Account management |
| Personal info › **Name** (optional display name) | Yes | No | No | Optional | App functionality, Account management |
| Personal info › **User IDs** (internal account ID) | Yes | No | No | Required | App functionality, Account management |
| Financial info › **Purchase history** (plan, status, Play purchase token) | Yes | No | No | Optional (only subscribers) | App functionality, Account management |
| App activity › **Other user-generated content** (dream text, readings, reports) | Yes | No | No | Required | App functionality |

Answer **No / not collected** for everything else, including: Location;
Financial info › payment info, credit score, other; Health and fitness;
Messages; Photos and videos; **Audio** (speech is converted to text by the
device's speech service; DreamCast receives only text); Files and docs;
Calendar; Contacts; App activity › app interactions, in-app search, installed
apps, other actions, web browsing; App info and performance › crash logs,
diagnostics (no crash SDK in the app); **Device or other IDs** (Firebase is
bundled but never initialized — no push token is created).

**Revisit if…** you enable push notifications (Device or other IDs),
add analytics/crash reporting in the app (App interactions, Crash logs,
Diagnostics), or let users upload photos.

## 12. Account deletion

Answered within Data safety above. In the app: **account icon › Delete
account** (calls `DELETE /api/v1/users/me`, removing the account, dreams,
readings, reports and subscription record).

## 13. Store settings

- **App category:** Lifestyle
- **Tags:** Journal, Self-improvement (pick the closest available)
- **Contact details:** Email `chinjiesylvestern@gmail.com`; Website
  `https://chinjiesylvesternkeh.github.io/Dreamcast-star/`

## 14. Subscriptions (Monetize › Products › Subscriptions)

Create each product, then add one **base plan** (ID `monthly`,
auto-renewing, billing period 1 month, grace period 7 days, no free trial or
offers) and **activate** it. Set the price in USD and let Play convert other
countries.

| Product ID | Name | Price | Benefits (max 4, shown by Play) | Description |
|---|---|---|---|---|
| `dreamcast_lucid_monthly` | DreamCast Lucid | US$1.79 / month | A reading every day · Dream Cards for every dream · Full dream archive | A dream reading every day. |
| `dreamcast_mystic_monthly` | DreamCast Mystic | US$3.49 / month | Up to 2 readings a day · Every key symbol explained · A daily reflection | In-depth readings of every dream. |
| `dreamcast_oracle_monthly` | DreamCast Oracle | US$8.79 / month | Up to 3 readings a day · Patterns across your dreams · A guiding question | The deepest readings, connected across your dreams. |

Product IDs must match exactly — they are hard-wired in
`backend/app/plans.py`.

**French text for each subscription** (in the product, add the French
language to its listing):

| Product ID | Nom | Avantages (max 4) | Description |
|---|---|---|---|
| `dreamcast_lucid_monthly` | DreamCast Lucid | Une lecture chaque jour · Une carte de rêve pour chaque rêve · Toutes vos archives | Une lecture de rêve chaque jour. |
| `dreamcast_mystic_monthly` | DreamCast Mystic | Jusqu'à 2 lectures par jour · Chaque symbole clé expliqué · Une réflexion quotidienne | Des lectures approfondies de chaque rêve. |
| `dreamcast_oracle_monthly` | DreamCast Oracle | Jusqu'à 3 lectures par jour · Des liens entre vos rêves · Une question pour vous guider | Les lectures les plus approfondies, reliées entre vos rêves. |

## 15. Monetization setup (needed for real purchases)

1. **Google Cloud** › create a service account › create a JSON key.
2. **Play Console › Users and permissions** › invite the service account
   email › app permissions for DreamCast: *View financial data* and *Manage
   orders and subscriptions*.
3. Set the JSON on the backend as `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` and
   `PAYMENT_PROVIDER=google_play`.
4. **Real-time developer notifications:** create a Pub/Sub topic, grant
   `google-play-developer-notifications@system.gserviceaccount.com` the
   *Pub/Sub Publisher* role, enter the topic in **Monetize › Monetization
   setup**, then add a push subscription to
   `https://<your-api>/api/v1/subscriptions/webhook/google_play?token=<GOOGLE_PLAY_RTDN_TOKEN>`.
   Press **Send test notification** — the backend should answer 200.

## 16. Generative AI compliance (no form — keep for your records)

- Users can report offensive output in-app (flag icon → `dream_reports`).
- The AI is instructed to stay non-clinical and never alarming
  (`backend/app/services/ai_service.py`).
- Readings are labelled "AI-generated for reflection and entertainment — not
  medical or psychological advice."
- **Review `dream_reports` at least weekly** and act on harmful output
  (adjust the prompt, contact affected users if needed).
