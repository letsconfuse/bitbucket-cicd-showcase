# =============================================================================
# deploy_api.ps1 — .NET API Deployment via MSDeploy
#
# Deployed to server via SCP and executed remotely via SSH by the pipeline.
# Variables are injected via sed substitution before upload; this allows
# Bitbucket env vars to cross the SSH session boundary.
#
# Downtime: ~10-30 seconds
#   The app pool is stopped to release .dll file locks, MSDeploy syncs files,
#   then the app pool is restarted.
#
# Protected files (never overwritten by MSDeploy):
#   - web.config
#   - appsettings.json
#   - appsettings.*.json  (e.g. appsettings.Production.json)
# =============================================================================

#Requires -Version 5.1
#Requires -Modules WebAdministration

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

# ── Variables (injected by pipeline via sed) ──────────────────────────────────
$msdeploy   = 'C:\Program Files\IIS\Microsoft Web Deploy V3\msdeploy.exe'
$zipPath    = 'C:\temp\edge_publish_api.zip'
$source     = 'C:\temp\edge_publish_api'
$dest       = 'IIS_API_PHYSICAL_PATH_PLACEHOLDER'  # ← injected by pipeline
$appPool    = 'IIS_APP_POOL_NAME_PLACEHOLDER'       # ← injected by pipeline
$scriptPath = 'C:\temp\deploy_api.ps1'

# ── Helper: Timestamped log messages ─────────────────────────────────────────
function Write-Log {
  param([string]$Message, [string]$Level = 'INFO')
  $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  Write-Host "[$ts] [$Level] $Message"
}

function Write-Section {
  param([string]$Title)
  Write-Host ""
  Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  Write-Host "  $Title"
  Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ── Validate Dependencies ─────────────────────────────────────────────────────
Write-Section "Pre-Flight Checks"
if (-not (Test-Path $msdeploy)) {
  Write-Log "MSDeploy not found at: $msdeploy" 'ERROR'
  exit 1
}
if (-not (Get-Module -ListAvailable WebAdministration)) {
  Write-Log "IIS WebAdministration module is required." 'ERROR'
  exit 1
}

Import-Module WebAdministration
Write-Log "MSDeploy found: $msdeploy"
Write-Log "Source extract: $source"
Write-Log "Destination:    $dest"
Write-Log "App Pool:       $appPool"

# ── Step 1: Clean old extract ─────────────────────────────────────────────────
Write-Section "Step 1 — Clean Previous Extract"
if (Test-Path $source) {
  Write-Log "Removing old extract directory: $source"
  Remove-Item $source -Recurse -Force
}
Write-Log "Clean complete."

# ── Step 2: Extract zip artifact ─────────────────────────────────────────────
Write-Section "Step 2 — Extract Build Artifact"
if (-not (Test-Path $zipPath)) {
  Write-Log "ZIP not found: $zipPath" 'ERROR'
  exit 1
}
Write-Log "Expanding: $zipPath → $source"
Expand-Archive -Path $zipPath -DestinationPath $source -Force
Write-Log "Extracted files:"
Get-ChildItem $source | Select-Object Name, Length | Format-Table -AutoSize

# ── Step 3: Stop App Pool (Required for .dll locks) ──────────────────────────
Write-Section "Step 3 — Stop App Pool"
Write-Log "Stopping app pool: $appPool"
try {
  Stop-WebAppPool -Name $appPool
  Write-Log "Waiting 5 seconds for in-flight requests to drain..."
  Start-Sleep -Seconds 5
} catch {
  Write-Log "Failed to stop app pool: $_" 'WARNING'
  Write-Log "Continuing deployment, but MSDeploy may fail on file locks." 'WARNING'
}

# ── Step 4: MSDeploy differential sync ───────────────────────────────────────
Write-Section "Step 4 — MSDeploy Sync"
Write-Log "Running MSDeploy sync..."
Write-Log "  -skip appsettings.*.json: Protects environment config overrides"
Write-Log "  -skip web.config:         Protects IIS configs"

& $msdeploy `
  -verb:sync `
  -source:contentPath=$source `
  -dest:contentPath=$dest `
  -skip:objectName=filePath,absolutePath='.*appsettings.*\.json$' `
  -skip:objectName=filePath,absolutePath='.*web\.config$' `
  -useCheckSum `
  -enableRule:DoNotDeleteRule `
  -verbose

$msdeployExitCode = $LASTEXITCODE

# ── Step 5: Start App Pool ────────────────────────────────────────────────────
Write-Section "Step 5 — Start App Pool"
Write-Log "Starting app pool: $appPool"
try {
  Start-WebAppPool -Name $appPool
  Start-Sleep -Seconds 3
} catch {
  Write-Log "Failed to start app pool: $_" 'ERROR'
  # Check if we should exit here. We probably want to try cleanup anyway,
  # but deployment is essentially failed.
}

Write-Log "Verifying app pool state..."
$state = (Get-WebAppPoolState -Name $appPool).Value
Write-Log "App pool state is: $state"
if ($state -ne 'Started') {
  Write-Log "CRITICAL: App pool failed to start! State is $state. Check Event Viewer." 'ERROR'
  # We will exit with an error code after cleanup
  $msdeployExitCode = if ($msdeployExitCode -eq 0) { 1 } else { $msdeployExitCode }
}

if ($msdeployExitCode -ne 0) {
  Write-Log "Deployment failed. MSDeploy exit code: $msdeployExitCode" 'ERROR'
  exit $msdeployExitCode
}

# ── Step 6: Cleanup temp files ────────────────────────────────────────────────
Write-Section "Step 6 — Cleanup"
Remove-Item $zipPath    -Force -ErrorAction SilentlyContinue
Remove-Item $source     -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue
Write-Log "Temp files removed."

# ── Done ──────────────────────────────────────────────────────────────────────
Write-Section "Deployment Complete"
Write-Log "✅ .NET API deployed successfully to: $dest"
Write-Log "Deployment finished at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC' -AsUTC)"
