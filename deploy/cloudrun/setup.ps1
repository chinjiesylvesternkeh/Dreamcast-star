<#
.SYNOPSIS
  One-time Google Cloud setup for the DreamCast API (Cloud Run + Cloud SQL).

.DESCRIPTION
  Safe to re-run: every step checks whether its resource already exists.
  Creates the Artifact Registry repo, a dedicated service account, a
  PostgreSQL 16 Cloud SQL instance with daily backups, the database and its
  user, and generated secrets in Secret Manager. It never asks for or prints
  your Anthropic API key — add that yourself (see README.md, step 4).

.EXAMPLE
  ./setup.ps1 -ProjectId dreamcast-prod
#>
param(
    [Parameter(Mandatory = $true)][string]$ProjectId,
    [string]$Region = "europe-west1",
    [string]$SqlTier = "db-f1-micro"
)

$ErrorActionPreference = "Stop"
$Instance = "dreamcast-db"
$ServiceAccount = "dreamcast-api@$ProjectId.iam.gserviceaccount.com"

function Invoke-Gcloud {
    & gcloud @args
    if ($LASTEXITCODE -ne 0) { throw "gcloud $($args -join ' ') failed" }
}

function Test-Gcloud {
    & gcloud @args *> $null
    return $LASTEXITCODE -eq 0
}

function New-RandomSecret([int]$Length) {
    # Letters and digits only: safe inside a database URL and in config files.
    $chars = [char[]]'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'
    $bytes = New-Object byte[] $Length
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
}

function Set-Secret([string]$Name, [string]$Value) {
    if (Test-Gcloud secrets describe $Name) {
        Write-Host "  secret $Name already exists - keeping it"
        return $false
    }
    Invoke-Gcloud secrets create $Name --replication-policy=automatic
    # Via a temp file: piping from PowerShell would append a line break to the value.
    $file = New-TemporaryFile
    try {
        [System.IO.File]::WriteAllText($file.FullName, $Value)
        & gcloud secrets versions add $Name --data-file=$($file.FullName) | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Could not store secret $Name" }
    } finally {
        Remove-Item $file.FullName -Force
    }
    Write-Host "  created secret $Name"
    return $true
}

Write-Host "== Project $ProjectId, region $Region"
Invoke-Gcloud config set project $ProjectId

Write-Host "== Enabling APIs (first run takes a minute)"
Invoke-Gcloud services enable run.googleapis.com sqladmin.googleapis.com secretmanager.googleapis.com `
    artifactregistry.googleapis.com cloudbuild.googleapis.com

Write-Host "== Artifact Registry"
if (-not (Test-Gcloud artifacts repositories describe dreamcast --location=$Region)) {
    Invoke-Gcloud artifacts repositories create dreamcast --repository-format=docker --location=$Region `
        --description="DreamCast API images"
}

Write-Host "== Service account"
if (-not (Test-Gcloud iam service-accounts describe $ServiceAccount)) {
    Invoke-Gcloud iam service-accounts create dreamcast-api --display-name="DreamCast API"
}
foreach ($role in "roles/cloudsql.client", "roles/secretmanager.secretAccessor") {
    Invoke-Gcloud projects add-iam-policy-binding $ProjectId --member="serviceAccount:$ServiceAccount" `
        --role=$role --condition=None | Out-Null
}

Write-Host "== Cloud SQL (creating an instance takes 5-10 minutes)"
if (-not (Test-Gcloud sql instances describe $Instance)) {
    # 7 daily backups + 7 days of point-in-time recovery: within the 30 days the privacy policy promises.
    Invoke-Gcloud sql instances create $Instance --database-version=POSTGRES_16 --edition=ENTERPRISE `
        --tier=$SqlTier --region=$Region --storage-type=SSD --storage-size=10 --storage-auto-increase `
        --backup-start-time=02:00 --retained-backups-count=7 --enable-point-in-time-recovery `
        --retained-transaction-log-days=7
}
if (-not (Test-Gcloud sql databases describe dreamcast --instance=$Instance)) {
    Invoke-Gcloud sql databases create dreamcast --instance=$Instance
}
$connection = (& gcloud sql instances describe $Instance --format="value(connectionName)").Trim()

Write-Host "== Secrets"
if (-not (Test-Gcloud secrets describe database-url)) {
    $dbPassword = New-RandomSecret 32
    if (Test-Gcloud sql users describe dreamcast --instance=$Instance) {
        Invoke-Gcloud sql users set-password dreamcast --instance=$Instance --password=$dbPassword
    } else {
        Invoke-Gcloud sql users create dreamcast --instance=$Instance --password=$dbPassword
    }
    Set-Secret database-url "postgresql://dreamcast:$dbPassword@/dreamcast?host=/cloudsql/$connection" | Out-Null
} else {
    Write-Host "  secret database-url already exists - keeping it"
}
Set-Secret jwt-secret-key (New-RandomSecret 64) | Out-Null
Set-Secret google-play-rtdn-token (New-RandomSecret 40) | Out-Null

Write-Host ""
if (Test-Gcloud secrets versions describe latest --secret=anthropic-api-key) {
    Write-Host "Anthropic API key: found in Secret Manager."
} else {
    Write-Host "NEXT: add your Anthropic API key (README.md, step 4). It is the only secret this script does not create."
}
Write-Host "Setup complete. Deploy with: ./deploy.ps1 -ProjectId $ProjectId -Region $Region"
