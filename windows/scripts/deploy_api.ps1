[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$IisApiPath,
    
    [Parameter(Mandatory=$true)]
    [string]$AppPoolName
)

$ErrorActionPreference = 'Stop'
Import-Module WebAdministration

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message"
}

try {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $zipPath = "C:\temp\edge_publish_api.zip"
    $extractPath = "C:\temp\api_extract_$timestamp"
    $backupPath = "C:\releases\api\$timestamp"

    Write-Log "Starting API deployment..."
    
    if (-not (Test-Path $zipPath)) {
        throw "API package not found at $zipPath"
    }

    Write-Log "Extracting API package to $extractPath..."
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

    Write-Log "Creating backup at $backupPath..."
    New-Item -ItemType Directory -Force -Path $backupPath | Out-Null
    if (Test-Path "$IisApiPath") {
        Copy-Item -Path "$IisApiPath\*" -Destination $backupPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Log "Pruning old backups..."
    $backupDir = "C:\releases\api"
    if (Test-Path $backupDir) {
        $backups = Get-ChildItem -Path $backupDir -Directory | Sort-Object CreationTime -Descending
        if ($backups.Count -gt 3) {
            $backups[3..($backups.Count - 1)] | Remove-Item -Recurse -Force
        }
    }

    Write-Log "Stopping IIS App Pool: $AppPoolName..."
    Stop-WebAppPool -Name $AppPoolName
    Start-Sleep -Seconds 2

    Write-Log "Deploying new API to $IisApiPath..."
    $exclude = @("appsettings.json", "appsettings.*.json")
    Get-ChildItem -Path $extractPath | Copy-Item -Destination $IisApiPath -Recurse -Force -Exclude $exclude

    Write-Log "Starting IIS App Pool: $AppPoolName..."
    Start-WebAppPool -Name $AppPoolName
    Start-Sleep -Seconds 2

    $state = (Get-WebAppPoolState -Name $AppPoolName).Value
    if ($state -ne 'Started') {
        throw "App Pool $AppPoolName failed to start. Current state: $state"
    }

    Write-Log "API deployment completed successfully."
}
catch {
    Write-Log "ERROR: $_"
    throw
}
finally {
    Write-Log "Cleaning up temporary files..."
    if (Test-Path $extractPath) { Remove-Item -Path $extractPath -Recurse -Force }
    if (Test-Path $zipPath) { Remove-Item -Path $zipPath -Force }
}
