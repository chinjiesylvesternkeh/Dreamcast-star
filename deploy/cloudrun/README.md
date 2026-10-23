# Deploying the DreamCast API to Google Cloud Run

Real visitors need the backend on a public HTTPS address. This folder runs it
on **Cloud Run** (the API) with **Cloud SQL for PostgreSQL** (the data), with
every secret in **Secret Manager**.

| Piece | What it is | Approx. cost at launch |
|---|---|---|
| Cloud Run `dreamcast-api` | The API, scales to zero when idle, max 2 instances | ~$0–5 / month |
| Cloud SQL `dreamcast-db` | PostgreSQL 16, db-f1-micro, daily backups (7 kept) | ~$9–12 / month |
| Secret Manager, Artifact Registry, Cloud Build | Secrets, images, builds | cents |
| Anthropic API | Readings: Haiku 5.5 (Free), Sonnet 5.5 (paid plans) | pay per reading |

Commands are PowerShell, run from this folder
(`cd dreamcast\deploy\cloudrun`).

## 1. Install the Google Cloud CLI and sign in

```powershell
winget install Google.CloudSDK
# open a new terminal, then:
gcloud auth login
```

Sign in with the Google account you use for Play Console
(chinjiesylvestern@gmail.com) so everything lives in one place.

## 2. Create the project and turn on billing

1. https://console.cloud.google.com/projectcreate — name it e.g. `DreamCast`
   and note the **Project ID** (e.g. `dreamcast-prod`).
2. https://console.cloud.google.com/billing — link the project to a billing
   account.
3. Recommended: **Billing › Budgets & alerts** — create a monthly budget
   (e.g. $25) with email alerts at 50 / 90 / 100 %.

## 3. Run the one-time setup

```powershell
./setup.ps1 -ProjectId dreamcast-prod
```

Creates the image repository, the service account, the Cloud SQL instance
(5–10 minutes the first time), the database and user, and three generated
secrets: `database-url`, `jwt-secret-key`, `google-play-rtdn-token`.
Safe to run again; it keeps whatever already exists.

Default region is `europe-west1` (Belgium) — usually the fastest Google
region for Cameroon. Pass `-Region africa-south1` (Johannesburg) to compare.

## 4. Add your Anthropic API key (you do this — it never goes in git or chat)

1. https://console.anthropic.com — **Settings › Billing**: add credit.
2. **Settings › Limits**: set a monthly spend limit you're comfortable with.
   This is your hard safety net on AI cost.
3. **Settings › API keys › Create key** — name it `dreamcast-production`.
4. Store it in Secret Manager. Either paste it in the Cloud Console
   (**Security › Secret Manager › Create secret**, name `anthropic-api-key`),
   or run this; it asks for the key without showing it:

```powershell
$key = Read-Host -AsSecureString "Anthropic API key"
$plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($key))
$file = New-TemporaryFile; [IO.File]::WriteAllText($file.FullName, $plain)
gcloud secrets create anthropic-api-key --replication-policy=automatic
gcloud secrets versions add anthropic-api-key --data-file=$($file.FullName)
Remove-Item $file.FullName; Remove-Variable plain, key
```

To try real readings on your own PC too, put the same key in
`backend/.env` as `ANTHROPIC_API_KEY=...` (that file is git-ignored).

## 5. Deploy

```powershell
./deploy.ps1 -ProjectId dreamcast-prod
```

Builds the image, applies database migrations, deploys, and checks the live
`/healthz` and `/readyz`. It prints the live API URL, e.g.
`https://dreamcast-api-abc123-ew.a.run.app/api/v1`. Run the same command
for every update.

In production the API refuses to start with a development JWT secret or a
SQLite database, and it never serves the sample reading: without an
Anthropic key, readings fail with a "try again" message instead.

## 6. Point the app at the live API

```powershell
cd ..\..\mobile
flutter build appbundle --release --dart-define=API_BASE_URL=https://<your-service-url>/api/v1
```

(Run Flutter through the `C:\Users\CHINJI~1\...` short path — see
`mobile/PLAY_STORE_RELEASE.md`.) Upload `app-release.aab` to the closed
testing track (`play-store/CLOSED_TESTING.md`).

## 7. Let the API verify Play purchases

1. Cloud Console › **IAM & Admin › Service accounts › Create** —
   `play-billing-verifier`, no project roles. Open it › **Keys › Add key ›
   JSON**; a file downloads.
2. Play Console › **Users and permissions › Invite new users** — the service
   account's email; for the DreamCast app grant *View financial data* and
   *Manage orders and subscriptions*.
3. Store the file and redeploy:

```powershell
gcloud secrets create google-play-service-account --replication-policy=automatic
gcloud secrets versions add google-play-service-account --data-file="C:\path\to\downloaded-key.json"
./deploy.ps1 -ProjectId dreamcast-prod
```

Then delete the downloaded file.

## 8. Real-time subscription notifications

```powershell
gcloud services enable pubsub.googleapis.com
gcloud pubsub topics create play-billing
gcloud pubsub topics add-iam-policy-binding play-billing `
  --member="serviceAccount:google-play-developer-notifications@system.gserviceaccount.com" `
  --role="roles/pubsub.publisher"
$token = gcloud secrets versions access latest --secret=google-play-rtdn-token
gcloud pubsub subscriptions create play-billing-push --topic=play-billing `
  --push-endpoint="https://<your-service-url>/api/v1/subscriptions/webhook/google_play?token=$token"
```

Play Console › **Monetize › Monetization setup** — topic
`projects/dreamcast-prod/topics/play-billing` › **Send test notification**.

## Running it

- **Logs:** `gcloud run services logs read dreamcast-api --region europe-west1`
  (or Cloud Console › Cloud Run › dreamcast-api › Logs).
- **AI cost per reading:** every reading logs a line like
  `reading model=claude-sonnet-5-5 depth=deep lang=fr input_tokens=1350 output_tokens=2100`.
  Filter the logs for `reading model=` to see real usage per plan.
- **Roll back:** Cloud Console › Cloud Run › dreamcast-api › Revisions ›
  route 100 % of traffic to the previous revision.
- **Cold starts:** with min instances 0 the first request after a quiet
  period takes a few seconds. `gcloud run services update dreamcast-api
  --min-instances 1 --region europe-west1` keeps one warm (~$10–15 / month
  extra).
- **Custom domain (optional):** Cloud Run › Manage custom domains, e.g.
  `api.yourdomain.com`; then rebuild the app with that URL.
