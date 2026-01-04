#!/bin/zsh
set -euo pipefail

LOG="/tmp/disk_log_scan_$(date +%Y%m%d_%H%M%S).log"
HORIZON="${HORIZON:-1h}"  # set HORIZON=3h for a longer lookback

log_msg(){ print -r -- "[$(date '+%F %T')] $*" | tee -a "$LOG"; }

need_cmds=(log tmutil diskutil lsof awk sort uniq head grep sed)
for c in "${need_cmds[@]}"; do
  command -v "$c" >/dev/null 2>&1 || { echo "Missing $c; install first."; exit 1; }
done

log_msg "Scanning unified logs for last $HORIZON (output -> $LOG)"

log_msg "--- Spotlight / mds events ---"
/usr/bin/log show --last "$HORIZON" --info --predicate 'process == "mds" || process == "mds_stores"' 2>/dev/null \
  | grep -Ei "index|store|error|throttle|scan" | tail -n 200 | tee -a "$LOG"

log_msg "--- Time Machine / backupd events ---"
/usr/bin/log show --last "$HORIZON" --info --predicate 'process == "backupd" || subsystem CONTAINS "backup"' 2>/dev/null \
  | tail -n 200 | tee -a "$LOG"

log_msg "--- APFS snapshot / purge / reclaim events ---"
/usr/bin/log show --last "$HORIZON" --info --predicate 'subsystem CONTAINS "apfs" OR eventMessage CONTAINS[c] "snapshot" OR eventMessage CONTAINS[c] "purge" OR eventMessage CONTAINS[c] "reclaim"' 2>/dev/null \
  | tail -n 200 | tee -a "$LOG"

log_msg "--- Filesystem write hints (fslogd) ---"
/usr/bin/log show --last "$HORIZON" --info --predicate 'process == "fslogd" || eventMessage CONTAINS[c] "write"' 2>/dev/null \
  | tail -n 200 | tee -a "$LOG"

log_msg "--- Current Time Machine local snapshots ---"
tmutil listlocalsnapshots / 2>&1 | tee -a "$LOG"

log_msg "--- Current APFS snapshots ---"
diskutil apfs listSnapshots / 2>&1 | tee -a "$LOG"

log_msg "--- Open-but-deleted files (first 40) ---"
if sudo -n true 2>/dev/null; then
  sudo lsof -nP +L1 2>/dev/null | head -n 40 | tee -a "$LOG" || log_msg "No se pudieron obtener archivos abiertos-eliminados"
else
  log_msg "Se requieren permisos de administrador para listar archivos abiertos-eliminados"
fi

log_msg "Done. Review $LOG"
echo "Log guardado en: $LOG"