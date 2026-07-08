# =============================================================================
# deploy_ui.ps1 — Angular UI Deployment via MSDeploy
#
# Deployed to server via SCP and executed remotely via SSH by the pipeline.
# Variables are injected via sed substitution before upload; this allows
# Bitbucket env vars to cross the SSH session boundary.
#
# Downtime: ~0 seconds
#   MSDeploy performs a live differential sync using checksums. Content-hashed
#   filenames (e.g. main.a1b2c3.js) mean there is never a moment where a
#   browser receives a mismatched index.html and JS bundle.
#
# Protected files (never overwritten by MSDeploy):
#   - web.config                           (IIS rewrite rules)
#   - assets/configuration/appsetting.json (Angular runtime config)
# =============================================================================

#Requires -Version 5.1
#Requires -Modules WebAdministration

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'  # Suppresses slow progress bars

# ── Variables (injected by pipeline via sed) ──────────────────────────────────
$msdeploy   = 'C:\Program Files\IIS\Microsoft Web Deploy V3\msdeploy.exe'
$zipPath    = 'C:\temp\edge_publish_ui.zip'
$source     = 'C:\temp\edge_publish_ui'
$dest       = 'IIS_UI_PHYSICAL_PATH_PLACEHOLDER'   # ← injected by pipeline
$scriptPath = 'C:\temp\deploy_ui.ps1'

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

# ── Validate MSDeploy is installed ────────────────────────────────────────────
Write-Section "Pre-Flight Checks"
if (-not (Test-Path $msdeploy)) {
  Write-Log "MSDeploy not found at: $msdeploy" 'ERROR'
  Write-Log "Install Web Deploy 3.5+ (Complete option) and retry." 'ERROR'
  exit 1
}
Write-Log "MSDeploy found: $msdeploy"
Write-Log "Source extract: $source"
Write-Log "Destination:    $dest"

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

# ── Step 3: MSDeploy differential sync ───────────────────────────────────────
Write-Section "Step 3 — MSDeploy Sync (Differential)"
Write-Log "Running MSDeploy sync..."
Write-Log "  -useCheckSum:        Only writes changed files"
Write-Log "  -enableRule:DoNotDeleteRule: Never deletes server-only files"
Write-Log "  -skip web.config:    Protects IIS rewrite rules"
Write-Log "  -skip appsetting.json: Protects Angular runtime config"

& $msdeploy `
  -verb:sync `
  -source:contentPath=$source `
  -dest:contentPath=$dest `
  -skip:objectName=filePath,absolutePath='.*web\.config$' `
  -skip:objectName=filePath,absolutePath='.*appsetting\.json$' `
  -useCheckSum `
  -enableRule:DoNotDeleteRule `
  -verbose

if ($LASTEXITCODE -ne 0) {
  Write-Log "MSDeploy exited with code $LASTEXITCODE" 'ERROR'
  exit $LASTEXITCODE
}
Write-Log "MSDeploy sync completed successfully."

# ── Step 4: Cleanup temp files ────────────────────────────────────────────────
Write-Section "Step 4 — Cleanup"
Remove-Item $zipPath    -Force -ErrorAction SilentlyContinue
Remove-Item $source     -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue
Write-Log "Temp files removed."

# ── Done ──────────────────────────────────────────────────────────────────────
Write-Section "Deployment Complete"
Write-Log "✅ Angular UI deployed successfully to: $dest"
Write-Log "Deployment finished at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC' -AsUTC)"
