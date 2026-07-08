#!/bin/bash
# =============================================================================
# rollback_ui.sh
# Restores the N-1 (previous) release of the Angular UI on Nginx.
# =============================================================================

set -euo pipefail

DEST_DIR="$1"
RELEASES_DIR="/var/backups/edge_ui"

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

if [ -z "$DEST_DIR" ]; then
  log "Usage: ./rollback_ui.sh <DEST_DIR>"
  exit 1
fi

log "Starting UI Rollback to $DEST_DIR"

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
log "Restoring files via rsync..."

rsync -avc --delete "$PREVIOUS_RELEASE" "$DEST_DIR/"

log "✅ UI Rollback complete. Previous version restored."
