<#
.SYNOPSIS
  Builds the DreamCast API image, migrates the database and deploys to Cloud Run.

.DESCRIPTION
  Run setup.ps1 once first. Each run: builds the image with Cloud Build,
  applies Alembic migrations as a Cloud Run job, deploys the service, then
  checks /healthz and /readyz on the live URL.

.EXAMPLE
  ./deploy.ps1 -ProjectId dreamcast-prod
#>
param(
    [Parameter(Mandatory = $true)][string]$ProjectId,
    [string]$Region = "europe-west1",
    [string]$Tag = ""
)

$ErrorActionPreference = "Stop"
$Here = $PSScriptRoot
$Backend = Resolve-Path (Join-Path $Here "..\..\backend")
$ServiceAccount = "dreamcast-api@$ProjectId.iam.gserviceaccount.com"
$EnvFile = Join-Path $Here "env.yaml"

function Invoke-Gcloud {
    & gcloud @args
    if ($LASTEXITCODE -ne 0) { throw "gcloud $($args -join ' ') failed" }
}

function Test-Gcloud {
    & gcloud @args *> $null
    return $LASTEXITCODE -eq 0
}

Invoke-Gcloud config set project $ProjectId

if (-not (Test-Gcloud secrets versions describe latest --secret=anthropic-api-key)) {
    throw "Secret 'anthropic-api-key' has no value yet. Add your key first (README.md, step 4)."
}

if (-not $Tag) {
    $Tag = (& git -C $Backend rev-parse --short HEAD).Trim()
    if (& git -C $Backend status --porcelain) { $Tag = "$Tag-dirty-$(Get-Date -Format yyyyMMddHHmm)" }
}
$Image = "$Region-docker.pkg.dev/$ProjectId/dreamcast/api:$Tag"
$Connection = (& gcloud sql instances describe dreamcast-db --format="value(connectionName)").Trim()

$Secrets = @(
    "DATABASE_URL=database-url:latest",
    "JWT_SECRET_KEY=jwt-secret-key:latest",
    "ANTHROPIC_API_KEY=anthropic-api-key:latest",
    "GOOGLE_PLAY_RTDN_TOKEN=google-play-rtdn-token:latest"
)
if (Test-Gcloud secrets versions describe latest --secret=google-play-service-account) {
    $Secrets += "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON=google-play-service-account:latest"
} else {
    Write-Warning "No 'google-play-service-account' secret yet: Play purchases can't be verified until you add it (README.md, step 7)."
}
$SecretArg = $Secrets -join ","

Write-Host "== Building $Image"
Invoke-Gcloud builds submit $Backend --tag $Image

Write-Host "== Migrating the database"
Invoke-Gcloud run jobs deploy dreamcast-migrate --image $Image --region $Region `
    --service-account $ServiceAccount --set-cloudsql-instances $Connection `
    --env-vars-file $EnvFile --set-secrets $SecretArg `
    --command python --args="-m,alembic,upgrade,head" --max-retries 0 --task-timeout 600
Invoke-Gcloud run jobs execute dreamcast-migrate --region $Region --wait

Write-Host "== Deploying the API"
# --timeout 300: readings can take minutes. --max-instances 2 caps cost and Cloud SQL connections.
Invoke-Gcloud run deploy dreamcast-api --image $Image --region $Region --platform managed `
    --service-account $ServiceAccount --add-cloudsql-instances $Connection `
    --env-vars-file $EnvFile --set-secrets $SecretArg `
    --allow-unauthenticated --port 8080 --cpu 1 --memory 512Mi `
    --concurrency 20 --timeout 300 --min-instances 0 --max-instances 2

$Url = (& gcloud run services describe dreamcast-api --region $Region --format="value(status.url)").Trim()
Write-Host "== Checking $Url"
$health = Invoke-RestMethod "$Url/healthz"
$ready = Invoke-RestMethod "$Url/readyz"
Write-Host "  healthz: $($health.status)   readyz: $($ready.status)"
if ($ready.status -ne "ready") { throw "The API is up but can't reach the database: $($ready.error)" }

Write-Host ""
Write-Host "Live API: $Url/api/v1"
Write-Host "Build the app against it:"
Write-Host "  flutter build appbundle --release --dart-define=API_BASE_URL=$Url/api/v1"
Write-Host "Play real-time notifications push endpoint (README.md, step 8):"
Write-Host "  $Url/api/v1/subscriptions/webhook/google_play?token=<google-play-rtdn-token secret>"
