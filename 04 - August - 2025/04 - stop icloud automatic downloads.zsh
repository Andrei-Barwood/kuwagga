#!/usr/bin/env zsh
# stop-icloud.zsh — halt unwanted iCloud Drive downloads with verbosity + monitoring
# Safe Ctrl+C: send SIGINT to the script's process group, then SIGKILL after timeout.

set -euo pipefail

# --- Make this script a process-group leader for safe group kills ---
# If not already leader, re-exec in a new session/process group so group signals
# target only this script’s descendants (not the parent shell).
if [[ "$(ps -o pgid= $$ | tr -d ' ')" != "$$" ]]; then
  if command -v setsid >/dev/null 2>&1; then
    exec setsid "$0" "$@"
  else
    # Fallback: proceed without setsid; group kill will still help in most cases.
    :
  fi
fi

# ---- CLI flags ----
VERB=1              # 0 quiet, 1 info (default), 2 debug, 3 trace
DRYRUN=0
MONITOR_MODE="log"  # log | meta | off
KILL_TIMEOUT=1.0    # seconds to wait before escalating to SIGKILL

print_usage() {
  cat <<EOF
Usage: $(basename "$0") [-q|-v|-vv] [-n] [--monitor[=log|meta|off]] [--kill-timeout SECONDS]
  -q              Quiet
  -v              More verbose (debug)
  -vv             Very verbose (trace)
  -n              Dry-run (no changes)
  --monitor       Enable monitoring (log; default)
  --monitor=log   Monitor brctl log -w --shorten
  --monitor=meta  Monitor brctl monitor com.apple.CloudDocs
  --monitor=off   Disable monitoring
  --kill-timeout  Seconds to wait before escalating to SIGKILL (default: ${KILL_TIMEOUT})
EOF
}

while (( $# )); do
  case "${1:-}" in
    -q) VERB=0 ;;
    -v) VERB=2 ;;
    -vv) VERB=3 ;;
    -n) DRYRUN=1 ;;
    --monitor) MONITOR_MODE="log" ;;
    --monitor=log) MONITOR_MODE="log" ;;
    --monitor=meta) MONITOR_MODE="meta" ;;
    --monitor=off|--no-monitor) MONITOR_MODE="off" ;;
    --kill-timeout)
      shift
      KILL_TIMEOUT="${1:-1.0}"
      ;;
    -h|--help) print_usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; print_usage; exit 2 ;;
  esac
  shift || true
done

# ---- Logging helpers ----
_log_ts() { date +"%Y-%m-%d %H:%M:%S"; }
log_info()  { [[ $VERB -ge 1 ]] && echo "[$(_log_ts)] [INFO] $*" >&2; }
log_debug() { [[ $VERB -ge 2 ]] && echo "[$(_log_ts)] [DEBUG] $*" >&2; }
log_trace() { [[ $VERB -ge 3 ]] && echo "[$(_log_ts)] [TRACE] $*" >&2; }
log_warn()  { echo "[$(_log_ts)] [WARN] $*" >&2; }
log_error() { echo "[$(_log_ts)] [ERROR] $*" >&2; }

[[ $VERB -ge 3 ]] && set -x

run() {
  if (( DRYRUN )); then
    echo "[$(_log_ts)] [DRYRUN] $*" >&2
  else
    log_trace "exec: $*"
    eval "$@"
  fi
}

# ---- Globals for progress ----
typeset -gi EVICT_COUNT=0
typeset -a MON_PIDS=()

# ---- Eviction batch ----
evict_batch() {
  set -o noglob
  local count=0
  while IFS= read -r -d '' f; do
    ((count++))
    # Ignore per-file failures to keep scanning robust
    run "brctl evict ${(q)f} >/dev/null 2>&1 || true"
    if (( VERB >= 2 )) && (( count % 500 == 0 )); then
      log_debug "Evicted $count files so far..."
    fi
  done
  EVICT_COUNT=$count
  log_info "Eviction requests issued for $EVICT_COUNT files."
}

# ---- Monitoring helpers ----
ticker() {
  while :; do
    sleep 5
    [[ "$MONITOR_MODE" != "off" ]] || break
    log_info "Progress: eviction requests issued = $EVICT_COUNT (waiting on CloudDocs to apply)…"
  done
}

start_monitors() {
  case "$MONITOR_MODE" in
    log)
      log_info "Starting brctl log monitor (press Ctrl+C to stop)..."
      ( brctl log -w --shorten 2>&1 | awk '{print "[LOG] " $0}' ) &
      MON_PIDS+=($!)
      ( ticker ) &
      MON_PIDS+=($!)
      ;;
    meta)
      log_info "Starting brctl metadata monitor (com.apple.CloudDocs)..."
      ( brctl monitor com.apple.CloudDocs 2>&1 | awk '{print "[MON] " $0}' ) &
      MON_PIDS+=($!)
      ( ticker ) &
      MON_PIDS+=($!)
      ;;
    off) ;;
  esac
}

# ---- Group-aware stop with escalation ----
stop_children_soft() {
  # Send SIGINT to entire process group (negative PGID)
  # This stops monitor pipelines and ticker immediately in most cases.
  kill -s INT -- -$$ >/dev/null 2>&1 || true
}

stop_children_hard() {
  # If anything still alive, escalate to SIGKILL for the group.
  kill -s KILL -- -$$ >/dev/null 2>&1 || true
}

wait_for_children_or_timeout() {
  # Wait up to KILL_TIMEOUT seconds for processes to die after SIGINT.
  # If any remain, escalate.
  local deadline now
  deadline=$(( $(date +%s%3N 2>/dev/null || echo 0) + ${KILL_TIMEOUT/./} ))
  # Fallback if %3N unsupported: just sleep and escalate.
  if [[ "$deadline" -eq 0 ]]; then
    sleep "$KILL_TIMEOUT"
  else
    while jobs -p >/dev/null 2>&1 && [[ -n "$(jobs -p)" ]]; do
      now=$(date +%s%3N 2>/dev/null || echo 0)
      if [[ "$now" -ge "$deadline" ]]; then
        break
      fi
      sleep 0.05
    done
  fi

  if jobs -p >/dev/null 2>&1 && [[ -n "$(jobs -p)" ]]; then
    log_warn "Some child jobs did not exit after ${KILL_TIMEOUT}s; escalating to SIGKILL…"
    stop_children_hard
    # Brief sleep to allow kill to take effect
    sleep 0.05
  fi

  # Reap any remaining to avoid zombies
  jobs -p | while read -r jp; do
    wait "$jp" >/dev/null 2>&1 || true
  done
}

cleanup() {
  log_info "Stopping monitors and child jobs…"
  stop_children_soft
  wait_for_children_or_timeout
  log_info "Cleanup complete."
}

on_signal() {
  cleanup
  # Ensure the interactive prompt returns immediately and no background output lingers.
  trap - INT TERM
  # Exit with a SIGINT-style code
  exit 130
}

trap 'on_signal' INT TERM
trap 'cleanup' EXIT

# ---- Main ----
ICLOUD_ROOT="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
log_info "Target iCloud Drive root: $ICLOUD_ROOT"
if [[ ! -d "$ICLOUD_ROOT" ]]; then
  log_error "iCloud Drive path not found. Adjust ICLOUD_ROOT."
  exit 1
fi

start_monitors

# 1) Evict files so they stop downloading locally
log_info "Requesting eviction (Remove Download) across iCloud Drive..."
if (( DRYRUN )); then
  log_info "Dry-run: showing up to 10 candidate files..."
  run "find ${(q)ICLOUD_ROOT} -type f -print0 | xargs -0 -n 1 | head -n 10"
else
  find "$ICLOUD_ROOT" -type f -print0 | evict_batch
fi

# 2) Restart iCloud sync daemons
log_info "Restarting iCloud sync daemons (bird, cloudd)..."
run "killall bird >/dev/null 2>&1 || true"
run "killall cloudd >/dev/null 2>&1 || true"

# 3) Temporarily unload NSURLSession agents (revert on reboot or resume script)
log_info "Temporarily unloading NSURLSession agents (revert on reboot or resume script)..."
run "launchctl unload /System/Library/LaunchAgents/com.apple.nsurlsessiond.plist >/dev/null 2>&1 || true"
run "sudo launchctl unload /System/Library/LaunchDaemons/com.apple.nsurlsessiond.plist >/dev/null 2>&1 || true"
run "sudo launchctl unload /System/Library/LaunchDaemons/com.apple.nsurlstoraged.plist >/dev/null 2>&1 || true"

log_info "Monitoring will continue; press Ctrl+C to stop."
if [[ "$MONITOR_MODE" != "off" ]]; then
  # Wait on all background monitors and ticker until interrupted
  wait
fi
