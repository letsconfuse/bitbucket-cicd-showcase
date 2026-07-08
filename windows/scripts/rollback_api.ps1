# =============================================================================
# rollback_api.ps1
# Restores the N-1 (previous) release of the .NET API from the backups directory.
# Requires stopping the app pool to release file locks.
# =============================================================================
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [string]$IisApiPath,

  [Parameter(Mandatory=$true)]
  [string]$AppPoolName
)

$ErrorActionPreference = 'Stop'
$releasesDir = 'C:\releases\api'

Import-Module WebAdministration

function Write-Log {
  param([string]$Message, [string]$Level = 'INFO')
  $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  Write-Host "[$ts] [$Level] $Message"
}

Write-Log "Starting API Rollback..."
Write-Log "Target IIS Path: $IisApiPath"
Write-Log "Target App Pool: $AppPoolName"

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

Write-Log "Stopping App Pool: $AppPoolName"
Stop-WebAppPool -Name $AppPoolName
Start-Sleep -Seconds 5

Write-Log "Restoring files to $IisApiPath ..."
try {
  Copy-Item -Path "$($previousRelease.FullName)\*" -Destination $IisApiPath -Recurse -Force
} catch {
  Write-Log "Failed to copy files: $_" 'ERROR'
  # Try to start app pool anyway to prevent complete outage if partial copy worked
} finally {
  Write-Log "Starting App Pool: $AppPoolName"
  Start-WebAppPool -Name $AppPoolName
  Start-Sleep -Seconds 3

  $state = (Get-WebAppPoolState -Name $AppPoolName).Value
  Write-Log "App Pool state is: $state"
  
  if ($state -ne 'Started') {
    Write-Log "CRITICAL: App pool failed to start after rollback!" 'ERROR'
    exit 1
  }
}

Write-Log "✅ API Rollback complete. Previous version restored."
