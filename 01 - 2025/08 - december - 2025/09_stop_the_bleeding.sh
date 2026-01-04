#!/bin/zsh
set -euo pipefail

LOG="/tmp/stop_drain_now_$(date +%Y%m%d_%H%M%S).log"
OS_SNAP="BAE3E18E-0D22-40CD-88C7-477AE31F427C"

log(){ print -r -- "[$(date '+%F %T')] $*" | tee -a "$LOG"; }

if [[ $EUID -ne 0 ]]; then
  echo "Requesting sudo..."
  sudo -v
fi

log "Pausing Spotlight indexing on /"
sudo mdutil -i off / | tee -a "$LOG"

log "Pausing Time Machine auto-backups"
sudo tmutil disable | tee -a "$LOG"

log "Deleting OS update snapshot if present: $OS_SNAP"
if diskutil apfs listSnapshots / 2>/dev/null | grep -q "$OS_SNAP"; then
  # Intentar obtener el dispositivo correcto automáticamente
  DEVICE=$(diskutil apfs listSnapshots / 2>/dev/null | grep "$OS_SNAP" | head -1 | awk '{print $NF}' || echo "")
  if [[ -n "$DEVICE" ]]; then
    sudo diskutil apfs deleteSnapshot "$DEVICE" -uuid "$OS_SNAP" 2>&1 | tee -a "$LOG" || log "Error al eliminar snapshot (puede que ya no exista)"
  else
    log "No se pudo determinar el dispositivo del snapshot"
  fi
else
  log "Snapshot not found; skipping delete."
fi

log "Thinning any Time Machine local snapshots (best-effort)"
sudo tmutil thinlocalsnapshots / 5000000000 4 | tee -a "$LOG" || true

log "Spotlight status:"
mdutil -s / | tee -a "$LOG"

log "Time Machine auto-backup status:"
defaults read /Library/Preferences/com.apple.TimeMachine AutoBackup 2>/dev/null | tee -a "$LOG" || true

log "Current snapshots:"
diskutil apfs listSnapshots / | tee -a "$LOG"
tmutil listlocalsnapshots / | tee -a "$LOG"

log "Done. Review $LOG"