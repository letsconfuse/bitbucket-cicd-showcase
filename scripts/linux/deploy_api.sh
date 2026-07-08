#!/bin/bash
# =============================================================================
# deploy_api.sh — .NET 8 API Deployment (Linux/systemd)
#
# Deployed to server via SCP and executed remotely via SSH by the pipeline.
#
# Downtime: ~5-15 seconds
#   The systemd service is stopped, files are synced via rsync, and
#   the service is started again.
# =============================================================================

set -euo pipefail

# Injected variables
SOURCE_DIR="/tmp/edge_publish_api"
ZIP_PATH="/tmp/edge_publish_api.zip"
DEST_DIR="LINUX_API_PATH_PLACEHOLDER"
SERVICE_NAME="LINUX_SYSTEMD_SERVICE_PLACEHOLDER"

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

log "Starting API Deployment..."
log "Destination: $DEST_DIR"
log "Service:     $SERVICE_NAME"

# 1. Clean previous temp extract
if [ -d "$SOURCE_DIR" ]; then
  log "Cleaning old temp directory..."
  rm -rf "$SOURCE_DIR"
fi

# 2. Extract Artifact
log "Extracting artifact..."
unzip -q "$ZIP_PATH" -d "$SOURCE_DIR"

# 3. Stop Service (Releases file locks on .dlls)
log "Stopping systemd service: $SERVICE_NAME..."
sudo systemctl stop "$SERVICE_NAME"
sleep 3

# 4. Rsync differential sync
log "Running rsync to update API files..."
rsync -avc --delete \
  --exclude 'appsettings.json' \
  --exclude 'appsettings.*.json' \
  "$SOURCE_DIR/" "$DEST_DIR/"

# 5. Start Service
log "Starting systemd service: $SERVICE_NAME..."
sudo systemctl start "$SERVICE_NAME"
sleep 3

# 6. Verify Service Status
if ! systemctl is-active --quiet "$SERVICE_NAME"; then
  log "❌ CRITICAL: Service failed to start! Check 'journalctl -u $SERVICE_NAME'."
  exit 1
fi

# 7. Cleanup
log "Cleaning up temp files..."
rm -rf "$SOURCE_DIR" "$ZIP_PATH" /tmp/deploy_api.sh

log "✅ API Deployment complete!"
