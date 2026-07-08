#!/bin/bash
# =============================================================================
# rollback_api.sh
# Restores the N-1 (previous) release of the .NET API on Linux/systemd.
# =============================================================================

set -euo pipefail

DEST_DIR="$1"
SERVICE_NAME="$2"
RELEASES_DIR="/var/backups/edge_api"

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

if [ -z "$DEST_DIR" ] || [ -z "$SERVICE_NAME" ]; then
  log "Usage: ./rollback_api.sh <DEST_DIR> <SERVICE_NAME>"
  exit 1
fi

log "Starting API Rollback to $DEST_DIR"

if [ ! -d "$RELEASES_DIR" ]; then
  log "❌ Releases directory not found: $RELEASES_DIR"
  exit 1
fi

# Find the most recent backup folder
PREVIOUS_RELEASE=$(ls -td "$RELEASES_DIR"/*/ | head -n 1)

if [ -z "$PREVIOUS_RELEASE" ]; then
  log "❌ No previous release found in $RELEASES_DIR"
  exit 1
fi

log "Found previous release: $PREVIOUS_RELEASE"

log "Stopping service: $SERVICE_NAME..."
sudo systemctl stop "$SERVICE_NAME"
sleep 2

log "Restoring files via rsync..."
rsync -avc --delete "$PREVIOUS_RELEASE" "$DEST_DIR/"

log "Starting service: $SERVICE_NAME..."
sudo systemctl start "$SERVICE_NAME"
sleep 3

if ! systemctl is-active --quiet "$SERVICE_NAME"; then
  log "❌ CRITICAL: Service failed to start after rollback!"
  exit 1
fi

log "✅ API Rollback complete. Previous version restored."
