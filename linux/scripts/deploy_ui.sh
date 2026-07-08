#!/bin/bash
# =============================================================================
# deploy_ui.sh — Angular UI Deployment via rsync (Linux/Nginx)
#
# Deployed to server via SCP and executed remotely via SSH by the pipeline.
#
# Downtime: ~0 seconds
#   rsync performs a differential sync. Content-hashed filenames mean
#   there is never a broken state during the transfer.
# =============================================================================

set -euo pipefail

# Injected variables (sed will replace these placeholders)
SOURCE_DIR="/tmp/edge_publish_ui"
ZIP_PATH="/tmp/edge_publish_ui.zip"
DEST_DIR="LINUX_UI_PATH_PLACEHOLDER"

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

log "Starting UI Deployment..."
log "Destination: $DEST_DIR"

# 1. Clean previous temp extract
if [ -d "$SOURCE_DIR" ]; then
  log "Cleaning old temp directory..."
  rm -rf "$SOURCE_DIR"
fi

# 2. Extract Artifact
log "Extracting artifact..."
unzip -q "$ZIP_PATH" -d "$SOURCE_DIR"

# 3. Rsync differential sync
log "Running rsync to update Nginx web root..."
# -a: archive mode (preserves permissions, times)
# -v: verbose
# -c: use checksums instead of mod-time/size
# --delete: remove files in destination that don't exist in source
# --exclude: protect environment configs
rsync -avc --delete \
  --exclude 'assets/configuration/appsetting.json' \
  "$SOURCE_DIR/" "$DEST_DIR/"

# 4. Cleanup
log "Cleaning up temp files..."
rm -rf "$SOURCE_DIR" "$ZIP_PATH" /tmp/deploy_ui.sh

log "✅ UI Deployment complete!"
