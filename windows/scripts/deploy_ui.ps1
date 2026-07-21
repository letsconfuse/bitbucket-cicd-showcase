[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$IisUiPath
)

$ErrorActionPreference = 'Stop'

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message"
}

try {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $zipPath = "C:\temp\edge_publish_ui.zip"
    $extractPath = "C:\temp\ui_extract_$timestamp"
    $backupPath = "C:\releases\ui\$timestamp"

    Write-Log "Starting UI deployment..."
    
    if (-not (Test-Path $zipPath)) {
        throw "UI package not found at $zipPath"
    }

    Write-Log "Extracting UI package to $extractPath..."
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

    Write-Log "Creating backup at $backupPath..."
    New-Item -ItemType Directory -Force -Path $backupPath | Out-Null
    if (Test-Path "$IisUiPath") {
        Copy-Item -Path "$IisUiPath\*" -Destination $backupPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Log "Pruning old backups..."
    $backupDir = "C:\releases\ui"
    if (Test-Path $backupDir) {
        $backups = Get-ChildItem -Path $backupDir -Directory | Sort-Object CreationTime -Descending
        if ($backups.Count -gt 3) {
            $backups[3..($backups.Count - 1)] | Remove-Item -Recurse -Force
        }
    }

    Write-Log "Deploying new UI to $IisUiPath..."
    $exclude = @("appsetting.json", "web.config")
    Get-ChildItem -Path $extractPath | Copy-Item -Destination $IisUiPath -Recurse -Force -Exclude $exclude

    Write-Log "UI deployment completed successfully."
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
