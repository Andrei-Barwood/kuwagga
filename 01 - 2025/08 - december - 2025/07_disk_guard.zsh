#!/bin/zsh
set -euo pipefail

LOG="/tmp/disk_drain_guard2_$(date +%Y%m%d_%H%M%S).log"
TMP_FS="/tmp/fs_usage_capture.log"
TMP_FS_ERR="/tmp/fs_usage_capture.err"

log() { print -r -- "[$(date '+%F %T')] $*" | tee -a "$LOG"; }

need_cmds=(df tmutil diskutil mdutil fs_usage lsof awk sort uniq head sed grep)
for c in "${need_cmds[@]}"; do
  command -v "$c" >/dev/null 2>&1 || { echo "Missing $c; install first."; exit 1; }
done

if [[ $EUID -ne 0 ]]; then
  echo "Requesting sudo upfront..."
  sudo -v || exit 1
fi

bytes_free() { df -k / | awk 'NR==2{print $4*1024}'; }
pretty_free() { df -H / | awk 'NR==2{print $4}'; }

monitor_and_trigger() {
  local prev curr delta drop_threshold=$((500*1024*1024)) interval=2 window=5 count=0
  prev=$(bytes_free)
  log "Monitoring free space; trigger if drop > $((drop_threshold/1024/1024)) MB within ~${window}s"
  while true; do
    sleep "$interval"
    curr=$(bytes_free)
    delta=$((curr - prev))
    log "Δ free: $((delta/1024/1024)) MB over ${interval}s (now $(pretty_free))"
    # accumulate over window
    if (( delta < 0 )); then
      count=$((count + 1))
      if (( count * interval >= window && (-delta) >= drop_threshold )); then
        log "Trigger: rapid drop detected."
        break
      fi
    else
      count=0
    fi
    prev=$curr
  done
}

capture_writers() {
  log "Capturing filesystem writers for 20s..."
  sudo fs_usage -w -f filesys 20 >"$TMP_FS" 2>"$TMP_FS_ERR" || true
  if [[ ! -s "$TMP_FS" ]]; then
    log "fs_usage capture is empty. Ensure Terminal has Full Disk Access. stderr:"
    sed -n '1,20p' "$TMP_FS_ERR" | tee -a "$LOG"
    return
  fi
  log "Top writers:"
  grep -E 'WRIT|WRITE' "$TMP_FS" \
    | awk '{print $(NF-1)}' | sed 's/\..*$//' \
    | sort | uniq -c | sort -nr | head -20 | tee -a "$LOG"
}

list_snapshots() {
  log "Time Machine local snapshots:"
  tmutil listlocalsnapshots / 2>&1 | tee -a "$LOG"
  log "APFS snapshots:"
  diskutil apfs listSnapshots / 2>&1 | tee -a "$LOG"
}

open_deleted() {
  log "Open-but-deleted files (first 40):"
  sudo lsof -nP +L1 2>/dev/null | head -n 40 | tee -a "$LOG"
}

mitigate_if_common() {
  local top=$(grep -E 'WRIT|WRITE' "$TMP_FS" | awk '{print $(NF-1)}' | sed 's/\..*$//' | sort | uniq -c | sort -nr | head -5 || true)
  if print "$top" | grep -qE 'mds|mds_stores'; then
    log "Detected Spotlight writers; pausing indexing..."
    sudo mdutil -i off / 2>&1 | tee -a "$LOG"
    log "Re-enable later with: sudo mdutil -i on /"
  fi
  if print "$top" | grep -qE 'backupd|MobileTimeMachine'; then
    log "Detected Time Machine writers; thinning local snapshots..."
    sudo tmutil thinlocalsnapshots / 5000000000 4 2>&1 | tee -a "$LOG"
    log "You can also pause TM backups: sudo tmutil disable (or re-enable later)."
  fi
}

offer_os_update_snapshot_removal() {
  local os_snap="BAE3E18E-0D22-40CD-88C7-477AE31F427C"
  if diskutil apfs listSnapshots / | grep -q "$os_snap"; then
    echo
    read -q "ans?Delete OS update snapshot $os_snap (can reclaim space)? [y/N] " || {
      echo ""
      log "Entrada cancelada por el usuario"
      return
    }
    echo
    if [[ "${ans:-n}" == [Yy] ]]; then
      log "Deleting OS update snapshot $os_snap ..."
      sudo diskutil apfs deleteSnapshot disk3s3s1 -uuid "$os_snap" 2>&1 | tee -a "$LOG"
    else
      log "Skipped deleting OS update snapshot."
    fi
  fi
}

main() {
  log "Starting disk drain guard v2. Log: $LOG"
  log "Baseline free: $(pretty_free)"
  monitor_and_trigger
  capture_writers
  list_snapshots
  open_deleted
  mitigate_if_common
  offer_os_update_snapshot_removal
  log "Done. Review log at $LOG"
  log "If writers were not captured, grant Terminal Full Disk Access and rerun."
}

main "$@"