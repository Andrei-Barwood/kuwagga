cat > /tmp/cleanup_installer_data.zsh << 'EOFSCRIPT'
#!/bin/zsh
set -euo pipefail

LOG="/tmp/cleanup_installer_data_$(date +%Y%m%d_%H%M%S).log"

log() { print -r -- "[$(date '+%F %T')] $*" | tee -a "$LOG"; }

if [[ $EUID -ne 0 ]]; then
  echo "This script needs sudo. Requesting..."
  sudo -v
fi

INSTALL_DATA="/System/Volumes/Data/macOS Install Data"

if [[ -d "$INSTALL_DATA" ]]; then
  log "Found macOS Install Data directory: $INSTALL_DATA"
  log "Size: $(du -sh "$INSTALL_DATA" 2>/dev/null | awk '{print $1}')"
  log "Removing..."
  sudo rm -rf "$INSTALL_DATA"
  log "Removed successfully."
else
  log "Directory not found: $INSTALL_DATA"
fi

log "Current free space:"
df -H / | tee -a "$LOG"

log "Done. Log saved to: $LOG"
EOFSCRIPT
chmod +x /tmp/cleanup_installer_data.zsh