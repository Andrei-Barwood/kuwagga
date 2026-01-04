#!/bin/zsh
set -euo pipefail

# Ensure PATH is set correctly (especially when running as root)
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH"

LOG="/tmp/cleanup_large_dirs_$(date +%Y%m%d_%H%M%S).log"

log() { print -r -- "[$(date '+%F %T')] $*" | /usr/bin/tee -a "$LOG"; }

if [[ $EUID -ne 0 ]]; then
  echo "This script needs sudo. Requesting..."
  sudo -v
fi

# Function to categorize directories
categorize_dir() {
  local path="$1"
  case "$path" in
    */Users/*|*/private/*|*/System/*|*/usr/*|*/bin/*|*/sbin/*|*/Library/Frameworks/*|*/Library/CoreServices/*)
      echo "WARNING|System-critical directory. Contains user data, system binaries, or essential macOS components. DO NOT DELETE unless you know what you're doing."
      ;;
    *"macOS Install Data"*)
      echo "SAFE|Leftover macOS installer/update files. Safe to delete - macOS will recreate these only when you update. Typically 5-15GB."
      ;;
    */.Spotlight-V100/*|*/.Spotlight-V100)
      echo "WARNING|Spotlight search index. Deletion will disable search until reindexing completes (can take hours). Better to disable Spotlight instead: 'sudo mdutil -i off /'"
      ;;
    */.Trash/*|*/.Trash)
      echo "SAFE|Trash/Deleted files. Safe to empty. Can recover significant space."
      ;;
    */Library/Caches/*|*/Caches/*)
      echo "SAFE|Application caches. Safe to delete - apps will recreate as needed. May cause apps to rebuild caches on next launch."
      ;;
    */Library/Logs/*|*/Logs/*)
      echo "SAFE|System and application logs. Safe to delete - logs will be recreated. May lose diagnostic history."
      ;;
    *"Library/Application Support"*"Cache"*)
      echo "SAFE|Application support caches. Safe to delete - apps will recreate. May cause temporary slowdowns."
      ;;
    */Library/Developer/*)
      echo "WARNING|Xcode/Developer tools data. Contains SDKs, simulators, derived data. Safe only if you don't develop. Can be 10-50GB+."
      ;;
    */Library/Containers/*)
      echo "WARNING|Sandboxed app containers. Contains app data and documents. May lose app settings/data if deleted."
      ;;
    */Applications/*)
      echo "WARNING|Installed applications. Only delete if you intentionally want to remove that app. Check if app is user-installed or system."
      ;;
    */Volumes/*)
      echo "WARNING|Mounted volumes/disk images. System mount points. DO NOT DELETE."
      ;;
    *)
      echo "UNKNOWN|Unknown directory type. Review manually before deleting."
      ;;
  esac
}

log "Scanning large directories in /System/Volumes/Data/..."
echo "Scanning for large directories..."

# Get top directories, skip if not accessible
if [[ $EUID -eq 0 ]]; then
  LARGE_DIRS=$(/usr/bin/du -xh /System/Volumes/Data/* 2>/dev/null | /usr/bin/sort -h | /usr/bin/tail -20 || echo "")
else
  LARGE_DIRS=$(/usr/bin/sudo /usr/bin/du -xh /System/Volumes/Data/* 2>/dev/null | /usr/bin/sort -h | /usr/bin/tail -20 || echo "")
fi

if [[ -z "$LARGE_DIRS" ]]; then
  echo "Error: Could not scan directories. Ensure you have proper permissions."
  exit 1
fi

# Parse and store results
typeset -A dirs
typeset -a dir_list
typeset -a dir_sizes

while IFS=$'\t' read -r size path; do
  # Skip if empty
  [[ -z "$path" ]] && continue
  
  dir_list+=("$path")
  dir_sizes+=("$size")
  dirs[$path]="$size"
done <<< "$LARGE_DIRS"

if [[ ${#dir_list[@]} -eq 0 ]]; then
  echo "No large directories found."
  exit 0
fi

# Show current disk space
echo ""
echo "Current disk space:"
/bin/df -H / | /usr/bin/head -2
echo ""

# Display menu with categorizations
echo "=== Large Directories Found ==="
echo ""

for i in {1..${#dir_list[@]}}; do
  idx=$((i))
  path="${dir_list[$idx]}"
  size="${dir_sizes[$idx]}"
  
  result=$(categorize_dir "$path")
  category="${result%%|*}"
  description="${result#*|}"
  
  if [[ "$category" == "WARNING" ]]; then
    printf "%2d. [WARNING] %-8s  %s\n" "$i" "$size" "$path"
    printf "    └─ %s\n" "$description"
  elif [[ "$category" == "SAFE" ]]; then
    printf "%2d. [SAFE]    %-8s  %s\n" "$i" "$size" "$path"
    printf "    └─ %s\n" "$description"
  else
    printf "%2d. [?]       %-8s  %s\n" "$i" "$size" "$path"
    printf "    └─ %s\n" "$description"
  fi
  echo ""
done

echo " 0. Exit without deleting anything"
echo ""

# Get user selection
read "selection?Enter numbers to delete (comma-separated, e.g., 1,3,5) or 0 to exit: " || {
  echo "Entrada cancelada por el usuario." >&2
  exit 1
}

if [[ "$selection" == "0" ]] || [[ -z "$selection" ]]; then
  echo "Exiting without deleting anything."
  exit 0
fi

# Parse selections
declare -a to_delete
IFS=',' read -rA selections <<< "$selection"

for sel in "${selections[@]}"; do
  sel=$(echo "$sel" | /usr/bin/tr -d ' ')
  if [[ "$sel" =~ ^[0-9]+$ ]] && [[ $sel -ge 1 ]] && [[ $sel -le ${#dir_list[@]} ]]; then
    idx=$sel
    path="${dir_list[$idx]}"
    
    result=$(categorize_dir "$path")
    category="${result%%|*}"
    
    if [[ "$category" == "WARNING" ]]; then
      echo ""
      echo "⚠️  WARNING: You selected a system-critical directory!"
      echo "   Path: $path"
      echo "   ${result#*|}"
      read -q "confirm?Are you absolutely sure you want to delete this? (y/N): " || {
        echo ""
        log "Entrada cancelada por el usuario para: $path"
        continue
      }
      echo ""
      if [[ "$confirm" == [Yy] ]]; then
        to_delete+=("$path")
        log "User confirmed deletion of WARNING directory: $path"
      else
        log "User cancelled deletion of: $path"
      fi
    else
      to_delete+=("$path")
    fi
  fi
done

if [[ ${#to_delete[@]} -eq 0 ]]; then
  echo "No directories selected for deletion."
  exit 0
fi

# Confirm final deletion
echo ""
echo "=== Ready to delete ==="
for path in "${to_delete[@]}"; do
  size="${dirs[$path]}"
  echo "  $size  $path"
done

echo ""
read -q "final_confirm?Proceed with deletion? (y/N): " || {
  echo ""
  echo "Deletion cancelled."
  exit 0
}
echo ""

if [[ "$final_confirm" != [Yy] ]]; then
  echo "Deletion cancelled."
  exit 0
fi

# Perform deletions
echo ""
log "Starting deletion process..."
space_before=$(/bin/df -k / | /usr/bin/awk 'NR==2{print $4}')

for path in "${to_delete[@]}"; do
  size="${dirs[$path]}"
  echo "Deleting: $size  $path"
  log "Deleting: $path (size: $size)"
  
  if /bin/rm -rf "$path" 2>/dev/null; then
    echo "  ✓ Deleted successfully"
    log "  Successfully deleted: $path"
  else
    echo "  ✗ Failed to delete (may be protected or in use)"
    log "  Failed to delete: $path"
  fi
done

space_after=$(/bin/df -k / | /usr/bin/awk 'NR==2{print $4}')
space_freed=$((space_after - space_before))
space_freed_mb=$((space_freed / 1024))
space_freed_gb=$(echo "scale=2; $space_freed / 1024 / 1024" | /usr/bin/bc)

echo ""
echo "=== Deletion Complete ==="
echo "Space freed: ~${space_freed_mb} MB (~${space_freed_gb} GB)"
log "Space freed: ${space_freed_mb} MB (${space_freed_gb} GB)"

echo ""
echo "Updated disk space:"
/bin/df -H / | /usr/bin/head -2
log "Final disk space:"
/bin/df -H / | /usr/bin/head -2 | /usr/bin/tee -a "$LOG"

echo ""
echo "Log saved to: $LOG"

