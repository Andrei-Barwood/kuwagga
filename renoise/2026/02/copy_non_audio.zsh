#!/usr/bin/env zsh
# copy_non_audio.zsh
#
# Copy everything from a source folder to a destination folder,
# except audio files. Handles deep nesting (unlimited; find has no
# depth limit) and large trees. Folders, images, PDFs, text, videos
# are kept; audio is never copied.
#
# Usage:
#   ./copy_non_audio.zsh
#   ./copy_non_audio.zsh "/path/to/source" "/path/to/destination"
#   ./copy_non_audio.zsh --dry-run "/path/to/source" "/path/to/destination"

set -euo pipefail

# ---------------------------------------------------------------------------
# Audio extensions to exclude (case-insensitive)
# ---------------------------------------------------------------------------
AUDIO_EXTS=(
  mp3 flac wav aiff aif aifc m4a aac ogg opus wma ape alac
  dsf dff wv tta tak mpc mka ra ram mid midi kar amr 3ga
  caf m4b m4p m4r mp2 mp1 ac3 eac3 dts
  au snd voc gsm spx
)

DRY_RUN=0
SOURCE=""
DEST=""
BAR_WIDTH=36

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
die() {
  print -u2 -- "error: $*"
  exit 1
}

usage() {
  cat <<'EOF'
Usage:
  copy_non_audio.zsh [--dry-run] [SOURCE DEST]

Copy all non-audio files from SOURCE into DEST, preserving relative folder
structure at any depth (nested subdirectories are fully supported).

Options:
  --dry-run, -n   Show what would be copied without writing anything
  --help, -h      Show this help

Examples:
  ./copy_non_audio.zsh
  ./copy_non_audio.zsh "/Volumes/.../2011 - El Habitat 37" "/Volumes/.../lurssen mono masters/2011 - El Habitat 37"
  ./copy_non_audio.zsh --dry-run "$SRC" "$DST"
EOF
}

is_audio_file() {
  # Do not name locals `path` — in zsh $path is tied to $PATH.
  local file="$1"
  local ext="${file:e:l}"
  [[ -z "$ext" ]] && return 1
  local a
  for a in "${AUDIO_EXTS[@]}"; do
    [[ "$ext" == "$a" ]] && return 0
  done
  return 1
}

# Prompt on stderr; print final path on stdout (for capture).
prompt_path() {
  local label="$1"
  local value=""
  while true; do
    print -u2 -n -- "$label: "
    read -r value || die "cancelled"
    value="${value#\"}"
    value="${value%\"}"
    value="${value#\'}"
    value="${value%\'}"
    value="${value/#\~/$HOME}"
    if [[ -z "$value" ]]; then
      print -u2 -- "  (empty path — try again)"
      continue
    fi
    if [[ ! -d "$value" ]]; then
      print -u2 -- "  not a directory: $value"
      continue
    fi
    print -r -- "$value"
    return 0
  done
}

# Depth of a path relative to SOURCE (number of / components).
rel_depth() {
  local rel="$1"
  if [[ -z "$rel" || "$rel" != */* ]]; then
    print -- 1
  else
    # count slashes + 1
    local n=${rel//[^\/]/}
    print -- $(( ${#n} + 1 ))
  fi
}

# Human-readable size (bytes → KiB/MiB/GiB)
human_bytes() {
  local b=$1
  if (( b < 1024 )); then
    print -- "${b} B"
  elif (( b < 1048576 )); then
    print -- "$(( b / 1024 )) KiB"
  elif (( b < 1073741824 )); then
    printf '%d.%01d MiB\n' $(( b / 1048576 )) $(( (b % 1048576) * 10 / 1048576 ))
  else
    printf '%d.%02d GiB\n' $(( b / 1073741824 )) $(( (b % 1073741824) * 100 / 1073741824 ))
  fi
}

# Live progress bar on stderr (does not pollute logs if redirected).
# Args: current total [label]
draw_progress() {
  local current=$1
  local total=$2
  local label="${3:-}"
  local pct=0 filled=0 empty=0 i
  local bar=""

  if (( total <= 0 )); then
    pct=0
    filled=0
  else
    pct=$(( current * 100 / total ))
    filled=$(( current * BAR_WIDTH / total ))
    (( filled > BAR_WIDTH )) && filled=$BAR_WIDTH
  fi
  empty=$(( BAR_WIDTH - filled ))

  for (( i = 0; i < filled; i++ )); do bar+="█"; done
  for (( i = 0; i < empty; i++ )); do bar+="░"; done

  # Truncate label so the line stays readable
  if (( ${#label} > 48 )); then
    label="…${label: -47}"
  fi

printf '\r  [%s] %3d%% (%d/%d) %s' "$bar" "$pct" "$current" "$total" "$label" >&2
  # clear rest of terminal line
  printf '\033[K' >&2
}

clear_progress_line() {
  printf '\r\033[K' >&2
}

# Classify a raw error string into a short reason.
classify_error() {
  local msg="${1:l}"
  if [[ -z "$msg" ]]; then
    print -- "unknown error"
  elif [[ "$msg" == *"permission denied"* || "$msg" == *"operation not permitted"* ]]; then
    print -- "permission denied"
  elif [[ "$msg" == *"no space"* || "$msg" == *"disk full"* ]]; then
    print -- "disk full / no space left"
  elif [[ "$msg" == *"read-only"* ]]; then
    print -- "destination is read-only"
  elif [[ "$msg" == *"no such file"* ]]; then
    print -- "path missing (parent vanished or bad path)"
  elif [[ "$msg" == *"file exists"* ]]; then
    print -- "destination already exists and could not be replaced"
  elif [[ "$msg" == *"not a directory"* ]]; then
    print -- "expected a directory at destination (name clash with a file)"
  elif [[ "$msg" == *"is a directory"* ]]; then
    print -- "destination is a directory (name clash with a file)"
  elif [[ "$msg" == *"input/output"* || "$msg" == *"i/o error"* ]]; then
    print -- "I/O error (disk / network volume problem)"
  elif [[ "$msg" == *"resource busy"* || "$msg" == *"device busy"* ]]; then
    print -- "resource busy"
  elif [[ "$msg" == *"cross-device"* ]]; then
    print -- "cross-device link not permitted"
  else
    # Keep a compact version of the raw message
    local one="${1//$'\n'/; }"
    (( ${#one} > 120 )) && one="${one:0:117}…"
    print -- "$one"
  fi
}

# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run|-n)
      DRY_RUN=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      die "unknown option: $1 (try --help)"
      ;;
    *)
      break
      ;;
  esac
done

if [[ $# -eq 2 ]]; then
  SOURCE="$1"
  DEST="$2"
elif [[ $# -eq 0 ]]; then
  :
elif [[ $# -eq 1 ]]; then
  die "need both SOURCE and DEST, or neither (interactive mode)"
else
  die "too many arguments (try --help)"
fi

# ---------------------------------------------------------------------------
# Interactive prompts
# ---------------------------------------------------------------------------
if [[ -z "$SOURCE" ]]; then
  print -u2 -- ""
  print -u2 -- "Non-audio copy"
  print -u2 -- "=============="
  print -u2 -- "Source: folder that has audio + extras (images, PDFs, folders, …)"
  print -u2 -- "Dest:   matching folder (often audio-only) that should receive the extras"
  print -u2 -- "Depth:  unlimited (nested subfolders at any level are included)"
  print -u2 -- ""
  SOURCE="$(prompt_path "Source path")"
fi

if [[ -z "$DEST" ]]; then
  DEST="$(prompt_path "Destination path")"
fi

SOURCE="${SOURCE%/}"
DEST="${DEST%/}"

[[ -d "$SOURCE" ]] || die "source is not a directory: $SOURCE"
[[ -d "$DEST" ]]   || die "destination is not a directory: $DEST"

src_name="${SOURCE:t}"
dst_name="${DEST:t}"

print -- ""
print -- "Source:      $SOURCE"
print -- "Destination: $DEST"
print -- "Source name: $src_name"
print -- "Dest name:   $dst_name"

if [[ "$src_name" != "$dst_name" ]]; then
  print -- ""
  print -- "warning: directory titles differ."
  print -- "  source ends with: '$src_name'"
  print -- "  dest   ends with: '$dst_name'"
  print -n -- "Continue anyway? [y/N] "
  answer=""
  read -r answer || die "cancelled"
  case "${answer:l}" in
    y|yes) ;;
    *) die "aborted (directory titles do not match)" ;;
  esac
fi

if [[ "$SOURCE" == "$DEST" ]]; then
  die "source and destination are the same path"
fi

if (( DRY_RUN )); then
  print -- ""
  print -- "(dry-run mode — no files will be written)"
fi

# ---------------------------------------------------------------------------
# Scan (full recursion — no -maxdepth)
# ---------------------------------------------------------------------------
typeset -i total=0 skipped_audio=0 copied=0 dirs_made=0 errors=0
typeset -i scanned=0 max_depth=0 file_count=0 dir_count=0
typeset -i bytes_planned=0 bytes_copied=0
typeset -a to_copy_relpaths=()
typeset -a to_copy_srcpaths=()
typeset -a to_copy_kinds=()   # "dir" | "file"
typeset -a fail_lines=()     # "KIND|REL|REASON"

print -- ""
print -- "Scanning source (full tree, excluding audio)…"

# NOTE: never use a variable named `path` in zsh — it is tied to $PATH.
# find with no -maxdepth walks every nested subdirectory.
while IFS= read -r -d '' src_item; do
  (( scanned += 1 )) || true
  # Spin a lightweight scan indicator every 25 entries
  if (( scanned % 25 == 0 )); then
    printf '\r  scanning… %d entries seen (audio skipped so far: %d)\033[K' \
      "$scanned" "$skipped_audio" >&2
  fi

  rel="${src_item#$SOURCE/}"
  depth="$(rel_depth "$rel")"
  (( depth > max_depth )) && max_depth=$depth

  if [[ -d "$src_item" && ! -L "$src_item" ]]; then
    to_copy_relpaths+=("$rel")
    to_copy_srcpaths+=("$src_item")
    to_copy_kinds+=("dir")
    (( total += 1 )) || true
    (( dir_count += 1 )) || true
    continue
  fi

  if [[ -f "$src_item" || -L "$src_item" ]]; then
    if is_audio_file "$src_item"; then
      (( skipped_audio += 1 )) || true
      continue
    fi
    to_copy_relpaths+=("$rel")
    to_copy_srcpaths+=("$src_item")
    to_copy_kinds+=("file")
    (( total += 1 )) || true
    (( file_count += 1 )) || true
    if [[ -f "$src_item" ]]; then
      # zsh: size in bytes via stat if available
      if size=$(stat -f%z "$src_item" 2>/dev/null); then
        (( bytes_planned += size )) || true
      fi
    fi
    continue
  fi
done < <(find "$SOURCE" -mindepth 1 -print0)

clear_progress_line

print -- "  entries scanned:         $scanned"
print -- "  deepest nesting level:   $max_depth"
print -- "  directories to create:   $dir_count"
print -- "  non-audio files:         $file_count"
print -- "  non-audio items total:   $total"
print -- "  audio files skipped:     $skipped_audio"
if (( file_count > 0 )); then
  print -- "  non-audio data size:     $(human_bytes $bytes_planned)"
fi

if (( total == 0 )); then
  print -- ""
  print -- "Nothing to copy (only audio, or empty source)."
  exit 0
fi

print -- ""
if (( ! DRY_RUN )); then
  print -n -- "Copy $total item(s) into destination? [Y/n] "
  answer=""
  read -r answer || die "cancelled"
  case "${answer:l}" in
    ""|y|yes) ;;
    *) die "aborted" ;;
  esac
fi

# ---------------------------------------------------------------------------
# Copy with progress bar
# ---------------------------------------------------------------------------
print -- ""
if (( DRY_RUN )); then
  print -- "Simulating copy…"
else
  print -- "Copying…"
fi

typeset -F SECONDS=0
integer i
local_err=""
cp_err=""
mkdir_err=""

for (( i = 1; i <= total; i++ )); do
  src_path="${to_copy_srcpaths[i]}"
  rel="${to_copy_relpaths[i]}"
  kind="${to_copy_kinds[i]}"
  dest_path="$DEST/$rel"

  draw_progress "$i" "$total" "$rel"

  if [[ "$kind" == "dir" ]]; then
    if (( DRY_RUN )); then
      (( dirs_made += 1 )) || true
      continue
    fi
    mkdir_err=""
    if mkdir_err=$(mkdir -p "$dest_path" 2>&1); then
      (( dirs_made += 1 )) || true
    else
      (( errors += 1 )) || true
      fail_lines+=("dir|$rel|$(classify_error "$mkdir_err")")
    fi
    continue
  fi

  # File or symlink
  if (( DRY_RUN )); then
    (( copied += 1 )) || true
    continue
  fi

  dest_parent="${dest_path:h}"
  mkdir_err=""
  if ! mkdir_err=$(mkdir -p "$dest_parent" 2>&1); then
    (( errors += 1 )) || true
    fail_lines+=("file|$rel|parent dir: $(classify_error "$mkdir_err")")
    continue
  fi

  cp_err=""
  if cp_err=$(cp -pR "$src_path" "$dest_path" 2>&1); then
    (( copied += 1 )) || true
    if size=$(stat -f%z "$src_path" 2>/dev/null); then
      (( bytes_copied += size )) || true
    fi
  elif cp_err=$(cp -p "$src_path" "$dest_path" 2>&1); then
    (( copied += 1 )) || true
    if size=$(stat -f%z "$src_path" 2>/dev/null); then
      (( bytes_copied += size )) || true
    fi
  else
    (( errors += 1 )) || true
    fail_lines+=("file|$rel|$(classify_error "$cp_err")")
  fi
done

clear_progress_line
elapsed=$SECONDS

# ---------------------------------------------------------------------------
# Ending report
# ---------------------------------------------------------------------------
print -- ""
print -- "════════════════════════════════════════════════════════════"
if (( DRY_RUN )); then
  print -- "  DRY-RUN REPORT"
else
  print -- "  COPY REPORT"
fi
print -- "════════════════════════════════════════════════════════════"
print -- "  Source:              $SOURCE"
print -- "  Destination:         $DEST"
print -- "  Max nesting depth:   $max_depth level(s)"
print -- "  Time elapsed:        ${elapsed}s"
print -- "────────────────────────────────────────────────────────────"
print -- "  Audio skipped:       $skipped_audio"
if (( DRY_RUN )); then
  print -- "  Dirs would create:   $dirs_made"
  print -- "  Files would copy:    $copied"
  print -- "  Planned data size:   $(human_bytes $bytes_planned)"
  print -- "  Failures:            0 (dry-run)"
else
  print -- "  Directories created: $dirs_made / $dir_count"
  print -- "  Files copied:        $copied / $file_count"
  print -- "  Data copied:         $(human_bytes $bytes_copied)"
  print -- "  Failures:            $errors"
fi
print -- "────────────────────────────────────────────────────────────"

if (( errors == 0 )); then
  if (( DRY_RUN )); then
    print -- "  Result: SUCCESS (simulation only — nothing was written)"
  else
    print -- "  Result: SUCCESS — all non-audio items copied"
  fi
  print -- "════════════════════════════════════════════════════════════"
  print -- ""
  exit 0
fi

print -- "  Result: PARTIAL / FAILED — $errors item(s) could not be copied"
print -- ""
print -- "  Failed items (why):"
print -- "  ──────────────────────────────────────────────────────────"
integer fi
for (( fi = 1; fi <= ${#fail_lines[@]}; fi++ )); do
  line="${fail_lines[fi]}"
  # kind|rel|reason
  f_kind="${line%%|*}"
  rest="${line#*|}"
  f_rel="${rest%%|*}"
  f_reason="${rest#*|}"
  printf '  %3d. [%s] %s\n' "$fi" "$f_kind" "$f_rel"
  print -- "       → $f_reason"
done
print -- "════════════════════════════════════════════════════════════"
print -- ""
print -- "Tip: common causes are permissions, a full disk, a read-only"
print -- "volume, or a name clash (file vs folder) at the destination."
print -- ""
exit 1
