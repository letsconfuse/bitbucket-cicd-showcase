# =============================================================================
# rollback_ui.ps1
# Restores the N-1 (previous) release of the Angular UI from the backups directory.
# =============================================================================
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [string]$IisUiPath
)

$ErrorActionPreference = 'Stop'
$releasesDir = 'C:\releases\ui'

function Write-Log {
  param([string]$Message, [string]$Level = 'INFO')
  $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  Write-Host "[$ts] [$Level] $Message"
}

Write-Log "Starting UI Rollback..."
Write-Log "Target IIS Path: $IisUiPath"

if (-not (Test-Path $releasesDir)) {
  Write-Log "Releases directory not found: $releasesDir" 'ERROR'
  exit 1
}

$previousRelease = Get-ChildItem $releasesDir | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-not $previousRelease) {
  Write-Log "No previous release found in $releasesDir" 'ERROR'
  exit 1
}

Write-Log "Found previous release: $($previousRelease.FullName)"
Write-Log "Restoring files to $IisUiPath ..."

# Note: We use -Force to overwrite existing files. We don't delete files in the
# target path first to avoid deleting things like web.config, though MSDeploy
# would be cleaner for differential syncing if we had a zip. For instant rollback
# from a directory, Copy-Item is fastest.
Copy-Item -Path "$($previousRelease.FullName)\*" -Destination $IisUiPath -Recurse -Force

Write-Log "✅ UI Rollback complete. Previous version restored."
