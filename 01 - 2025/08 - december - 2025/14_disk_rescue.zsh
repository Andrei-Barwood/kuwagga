#!/bin/zsh
set -euo pipefail

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH"

REPORT_DIR=$(mktemp -d "/tmp/disk_rescue_XXXXXX")
LOG="$REPORT_DIR/disk_rescue.log"

COMMAND="doctor"
ASSUME_YES=0
DRY_RUN=0
WATCH_AFTER=0
WATCH_SECONDS="${WATCH_SECONDS:-120}"
SAMPLE_INTERVAL="${SAMPLE_INTERVAL:-5}"
DROP_TRIGGER_MB="${DROP_TRIGGER_MB:-1024}"
FS_CAPTURE_SECONDS="${FS_CAPTURE_SECONDS:-15}"
LOG_HORIZON="${HORIZON:-1h}"
SUDO_READY=0
COLOR_ENABLED=0

C_RESET=""
C_BOLD=""
C_DIM=""
C_BORDER=""
C_TITLE=""
C_SECTION=""
C_LABEL=""
C_VALUE=""
C_SAFE=""
C_CAUTION=""
C_DANGER=""
C_HINT=""
C_OPTION=""
C_MUTED=""
C_TOGGLE_ON=""
C_TOGGLE_OFF=""

typeset -ga CANDIDATE_ORDER
typeset -gA CANDIDATE_LABEL
typeset -gA CANDIDATE_PATH
typeset -gA CANDIDATE_LEVEL
typeset -gA CANDIDATE_NOTE
typeset -gA CANDIDATE_ROOT
typeset -gA CANDIDATE_ACTION
typeset -gA CANDIDATE_SIZE_KB

log_msg() {
  print -r -- "[$(date '+%F %T')] $*" | tee -a "$LOG"
}

log_only_msg() {
  print -r -- "[$(date '+%F %T')] $*" >> "$LOG"
}

ui_print_and_log() {
  local plain="$1"
  local styled="${2:-$1}"
  print -r -- "$styled"
  log_only_msg "$plain"
}

section() {
  print -r -- ""
  print -r -- "" >> "$LOG"

  print -r -- "$(colorize "$C_BORDER" "╔══════════════════════════════════════════════════════════════╗")"
  print -r -- "$(colorize "$C_BORDER" "║") $(colorize "$C_TITLE" "$*")"
  print -r -- "$(colorize "$C_BORDER" "╚══════════════════════════════════════════════════════════════╝")"
  log_only_msg "== $* =="
}

usage() {
  cat <<'EOF'
Uso:
  14_disk_rescue.zsh [menu|doctor|report|cleanup|watch|emergency|resume] [opciones]

Sin argumentos:
  Si lo ejecutas en una terminal interactiva, abre un menu.
  Si lo ejecutas desde scripts/no interactivo, corre `doctor`.

Comandos:
  menu        Abre el menu interactivo
  doctor      Informe + caceria de directorios grandes + menu de limpieza segura
  report      Solo diagnostico
  cleanup     Solo menu de limpieza guiada
  watch       Monitorea caidas bruscas y captura culpables
  emergency   Pausa Spotlight/Time Machine y aplica mitigacion inmediata
  resume      Reactiva Spotlight/Time Machine

Opciones:
  --yes               Acepta automaticamente solo las acciones SAFE
  --dry-run           No borra nada; solo muestra lo que haria
  --watch             Ejecuta monitoreo al final de doctor/report/cleanup
  --watch-seconds N   Duracion del monitoreo (default: 120)
  --interval N        Intervalo de muestreo en segundos (default: 5)
  --drop-mb N         Disparo por caida acumulada en MB (default: 1024)
  --fs-seconds N      Segundos de captura con fs_usage (default: 15)
  --log-horizon 1h    Ventana para revisar unified logs (default: 1h)
  --help              Muestra esta ayuda
EOF
}

require_cmds() {
  local missing=0
  local cmd
  for cmd in awk df du sort head tail grep sed tmutil diskutil mdutil log lsof fs_usage rm find ps; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      print -r -- "Falta el comando requerido: $cmd" >&2
      missing=1
    fi
  done
  (( missing == 0 )) || exit 1
}

init_colors() {
  if [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-}" != "dumb" ]]; then
    COLOR_ENABLED=1
  else
    COLOR_ENABLED=0
  fi

  (( COLOR_ENABLED == 1 )) || return 0

  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_BORDER=$'\033[38;5;65m'
  C_TITLE=$'\033[1;38;5;156m'
  C_SECTION=$'\033[1;38;5;79m'
  C_LABEL=$'\033[38;5;71m'
  C_VALUE=$'\033[1;38;5;192m'
  C_SAFE=$'\033[1;38;5;156m'
  C_CAUTION=$'\033[1;38;5;192m'
  C_DANGER=$'\033[1;38;5;79m'
  C_HINT=$'\033[38;5;79m'
  C_OPTION=$'\033[1;38;5;156m'
  C_MUTED=$'\033[38;5;65m'
  C_TOGGLE_ON=$'\033[1;38;5;156m'
  C_TOGGLE_OFF=$'\033[1;38;5;65m'
}

colorize() {
  local style="${1:-}"
  shift || true

  if (( COLOR_ENABLED == 1 )) && [[ -n "$style" ]]; then
    printf '%b' "${style}$*${C_RESET}"
  else
    printf '%s' "$*"
  fi
}

colorize_toggle() {
  local state="${1:-OFF}"
  if [[ "$state" == "ON" ]]; then
    colorize "$C_TOGGLE_ON" "$state"
  else
    colorize "$C_TOGGLE_OFF" "$state"
  fi
}

append_log_plain() {
  print -r -- "$*" >> "$LOG"
}

colorize_by_level() {
  local level="${1:-info}"
  shift || true

  case "$level" in
    safe)
      colorize "$C_SAFE" "$*"
      ;;
    caution)
      colorize "$C_CAUTION" "$*"
      ;;
    danger)
      colorize "$C_DANGER" "$*"
      ;;
    *)
      colorize "$C_MUTED" "$*"
      ;;
  esac
}

styled_level_badge() {
  local level="${1:-info}"

  case "$level" in
    safe)
      colorize "$C_SAFE" "SAFE"
      ;;
    caution)
      colorize "$C_CAUTION" "CAUTION"
      ;;
    danger)
      colorize "$C_DANGER" "DANGER"
      ;;
    *)
      colorize "$C_MUTED" "INFO"
      ;;
  esac
}

ui_status_chip() {
  local level="${1:-info}"
  local text="${2:-INFO}"
  colorize_by_level "$level" "[$text]"
}

ui_event() {
  local level="$1"
  local chip="$2"
  local message="$3"
  ui_print_and_log "[$chip] $message" "$(ui_status_chip "$level" "$chip") $(colorize_by_level "$level" "$message")"
}

ensure_sudo() {
  if (( EUID == 0 )); then
    SUDO_READY=1
    return 0
  fi

  if (( SUDO_READY == 1 )); then
    return 0
  fi

  log_msg "Solicitando permisos de administrador..."
  sudo -v
  SUDO_READY=1
}

run_cmd() {
  if (( DRY_RUN == 1 )); then
    log_msg "[dry-run] $*"
    return 0
  fi
  "$@"
}

bytes_free() {
  df -k / | awk 'NR==2 {print $4 * 1024}'
}

pretty_free() {
  df -H / | awk 'NR==2 {print $4}'
}

human_from_kb() {
  local kb="${1:-0}"
  awk -v value="$kb" '
    BEGIN {
      split("KB MB GB TB PB", unit, " ")
      idx = 1
      while (value >= 1024 && idx < 5) {
        value /= 1024
        idx++
      }
      if (idx == 1) {
        printf("%.0f %s", value, unit[idx])
      } else {
        printf("%.2f %s", value, unit[idx])
      }
    }
  '
}

human_from_bytes() {
  local bytes="${1:-0}"
  awk -v value="$bytes" '
    BEGIN {
      split("B KB MB GB TB PB", unit, " ")
      idx = 1
      while (value >= 1024 && idx < 6) {
        value /= 1024
        idx++
      }
      if (idx <= 2) {
        printf("%.0f %s", value, unit[idx])
      } else {
        printf("%.2f %s", value, unit[idx])
      }
    }
  '
}

size_kb_path() {
  local target="$1"
  [[ -e "$target" ]] || {
    print -r -- "0"
    return 0
  }

  {
    du -sk "$target" 2>/dev/null || true
  } | awk '
    NR == 1 {print $1 + 0; found = 1}
    END {if (!found) print 0}
  '
}

confirm_yes_no() {
  local prompt="$1"
  local answer=""

  if (( ASSUME_YES == 1 )); then
    return 0
  fi

  read "answer?$prompt " || {
    print
    return 1
  }
  print
  [[ "$answer" == [Yy] ]]
}

confirm_token() {
  local prompt="$1"
  local expected="$2"
  local answer=""

  read "answer?$prompt " || {
    print
    return 1
  }
  print
  [[ "$answer" == "$expected" ]]
}

level_badge() {
  case "${1:-}" in
    safe) print -r -- "SAFE" ;;
    caution) print -r -- "CAUTION" ;;
    danger) print -r -- "DANGER" ;;
    *) print -r -- "INFO" ;;
  esac
}

bool_label() {
  (( ${1:-0} == 1 )) && print -r -- "ON" || print -r -- "OFF"
}

mode_label() {
  (( DRY_RUN == 1 )) && print -r -- "dry-run" || print -r -- "real"
}

pause_for_enter() {
  local dummy=""
  read "dummy?Pulsa Enter para volver al menu... " || true
  print
}

ui_box_top() {
  print -r -- "$(colorize "$C_BORDER" "╔══════════════════════════════════════════════════════════════╗")"
}

ui_box_mid() {
  print -r -- "$(colorize "$C_BORDER" "╠══════════════════════════════════════════════════════════════╣")"
}

ui_box_bottom() {
  print -r -- "$(colorize "$C_BORDER" "╚══════════════════════════════════════════════════════════════╝")"
}

ui_box_line() {
  print -r -- "$(colorize "$C_BORDER" "║") $*"
}

ui_rule_soft() {
  print -r -- "$(colorize "$C_BORDER" "╟──────────────────────────────────────────────────────────────╢")"
}

ui_report_metric() {
  local label="$1"
  local value="$2"
  local target="${3:-}"
  local note="${4:-}"
  local level="${5:-info}"
  local plain_line="" styled_line="" plain_path="" plain_note=""

  plain_line="$label: $value"
  [[ -n "$target" ]] && plain_line="$plain_line  $target"
  styled_line="$(colorize "$C_LABEL" "$label:") $(colorize_by_level "$level" "$value")"
  [[ -n "$target" ]] && styled_line="$styled_line  $(colorize "$C_MUTED" "$target")"
  ui_print_and_log "$plain_line" "$styled_line"

  if [[ -n "$note" ]]; then
    plain_note="    $note"
    ui_print_and_log "$plain_note" "    $(colorize "$C_HINT" "$note")"
  fi
}

ui_report_item() {
  local level="$1"
  local main="$2"
  local note="${3:-}"

  ui_print_and_log "[$(level_badge "$level")] $main" "$(colorize "$C_MUTED" "•") [$(styled_level_badge "$level")] $(colorize_by_level "$level" "$main")"
  if [[ -n "$note" ]]; then
    ui_print_and_log "    $note" "    $(colorize "$C_HINT" "$note")"
  fi
}

categorize_path() {
  local target="$1"

  case "$target" in
    *"/Library/Developer/CommandLineTools")
      print -r -- "DANGER|Command Line Tools instaladas. Borrarlas desinstala clang, git y los SDKs."
      ;;
    *"odis_download_dest"*)
      print -r -- "CAUTION|Temporales del instalador de Autodesk/ODIS. Borralos solo cuando AutoCAD, Autodesk Access y el instalador ya esten cerrados."
      ;;
    *"/Library/Developer/Xcode/DerivedData"*)
      print -r -- "SAFE|Artefactos temporales de compilacion. Xcode los regenera."
      ;;
    *"/Library/Developer/Xcode/Archives"*)
      print -r -- "CAUTION|Archivos exportados por Xcode. Borralos solo si ya no los necesitas."
      ;;
    *"/Library/Developer/Xcode/iOS DeviceSupport"*)
      print -r -- "CAUTION|Soporte para depurar versiones viejas de iOS. Se puede regenerar, pero volvera a descargarse."
      ;;
    *"/Library/Developer/CoreSimulator/Devices"*)
      print -r -- "CAUTION|Datos de simuladores. Puede liberar mucho espacio, pero perderas estados y apps de simulacion."
      ;;
    *"/Library/Developer/CoreSimulator/Caches"*)
      print -r -- "SAFE|Caches de simuladores. Se regeneran."
      ;;
    *"/Library/Caches/com.apple.dt.Xcode"*)
      print -r -- "SAFE|Cache de Xcode. Se regenera."
      ;;
    *"/Library/Caches/Homebrew"*)
      print -r -- "SAFE|Cache descargada por Homebrew. Se puede borrar sin romper Homebrew."
      ;;
    *"/Library/Caches/org.swift.swiftpm"*)
      print -r -- "SAFE|Cache de Swift Package Manager. Se regenera."
      ;;
    *"/Library/Logs/CoreSimulator"*)
      print -r -- "SAFE|Logs viejos de simuladores."
      ;;
    *"/Library/Logs/DiagnosticReports"*)
      print -r -- "SAFE|Crash reports y diagnosticos viejos."
      ;;
    *"macOS Install Data"*)
      print -r -- "SAFE|Residuo del instalador/actualizacion de macOS. Suele ser reclamable."
      ;;
    *"/Library/Updates"*)
      print -r -- "CAUTION|Descargas de actualizacion de macOS. Evita tocarlo si softwareupdated sigue trabajando."
      ;;
    *)
      print -r -- "INFO|Revisar manualmente antes de borrar."
      ;;
  esac
}

report_path_size() {
  local label="$1"
  local target="$2"
  local note="$3"
  local kb

  if [[ ! -e "$target" ]]; then
    return 0
  fi

  kb=$(size_kb_path "$target")
  ui_report_metric "$label" "$(human_from_kb "$kb")" "$target" "$note" "info"
}

autodesk_process_list() {
  ps ax -o pid= -o command= | awk '
    {
      line = tolower($0)
      if (line ~ /(autodesk|autocad|adodis|adskaccess|adsklicensing|identity manager|odis)/ && line !~ /^ *[0-9]+ +awk /) {
        print
      }
    }
  '
}

autodesk_cleanup_guard_processes() {
  ps ax -o pid= -o command= | awk '
    {
      line = tolower($0)
      if (line ~ /(autocad|autodesk identity manager|adodis|adskaccess|accessservicehost|install_manager|downloadmanager|adskupdatecheck|adskinstallerupdatecheck|ui-launcher)/ && line !~ /^ *[0-9]+ +awk /) {
        print
      }
    }
  '
}

autodesk_cleanup_busy() {
  [[ -n "$(autodesk_cleanup_guard_processes)" ]]
}

find_autodesk_odis_dirs() {
  {
    find /private/var/folders -maxdepth 4 -type d -name odis_download_dest 2>/dev/null || true
  } | sort -u
  return 0
}

autodesk_temp_total_kb() {
  local total=0
  local kb=0
  local target=""
  local -a odis_dirs=()
  odis_dirs=("${(@f)$(find_autodesk_odis_dirs)}")

  for target in "${odis_dirs[@]}"; do
    kb=$(size_kb_path "$target")
    total=$((total + kb))
  done

  print -r -- "$total"
}

menu_status_snapshot_count() {
  count_tm_snapshots
}

render_main_menu() {
  local free_text="" clt_text="" odis_text="" tm_count="" watch_after_text=""
  local clt_kb=0 odis_kb=0
  local free_render="" clt_render="" odis_render="" snapshot_render=""
  local mode_render="" auto_safe_render="" watch_after_render=""
  local title="" subtitle="" hint=""

  free_text=$(pretty_free)
  clt_kb=$(size_kb_path "/Library/Developer/CommandLineTools")
  clt_text=$(human_from_kb "$clt_kb")
  odis_kb=$(autodesk_temp_total_kb)
  tm_count=$(menu_status_snapshot_count)
  watch_after_text=$(bool_label "$WATCH_AFTER")

  if (( odis_kb > 0 )); then
    if autodesk_cleanup_busy; then
      odis_text="$(human_from_kb "$odis_kb") (activo)"
    else
      odis_text="$(human_from_kb "$odis_kb") (listo para limpiar)"
    fi
  else
    odis_text="no detectado"
  fi

  free_render=$(colorize "$C_VALUE" "$free_text")
  clt_render=$(colorize "$C_SECTION" "$clt_text")
  snapshot_render=$(colorize "$C_SECTION" "$tm_count")
  mode_render=$(colorize "$C_SECTION" "$(mode_label)")
  auto_safe_render=$(colorize_toggle "$(bool_label "$ASSUME_YES")")
  watch_after_render=$(colorize_toggle "$watch_after_text")

  if (( odis_kb > 0 )) && autodesk_cleanup_busy; then
    odis_render=$(colorize "$C_CAUTION" "$odis_text")
    hint=$(colorize "$C_CAUTION" "Sugerencia: cierra AutoCAD y Autodesk Access antes de limpiar ODIS.")
  elif (( odis_kb > 0 )); then
    odis_render=$(colorize "$C_SAFE" "$odis_text")
    hint=$(colorize "$C_SAFE" "Sugerencia: la opcion 3 puede recuperar temporales ODIS.")
  else
    odis_render=$(colorize "$C_MUTED" "$odis_text")
    hint=$(colorize "$C_HINT" "Sugerencia: la opcion 1 es la mejor forma de empezar.")
  fi

  title=$(colorize "$C_TITLE" "Disk Rescue")
  subtitle=$(colorize "$C_HINT" "Centro de diagnostico, vigilancia y limpieza para macOS")

  print -r -- ""
  ui_box_top
  ui_box_line "$title"
  ui_box_line "$subtitle"
  ui_box_mid
  ui_box_line "$(colorize "$C_LABEL" "Libre ahora :") $free_render"
  ui_box_line "$(colorize "$C_LABEL" "CLT         :") $clt_render"
  ui_box_line "$(colorize "$C_LABEL" "ODIS temp   :") $odis_render"
  ui_box_line "$(colorize "$C_LABEL" "TM snapshots:") $snapshot_render"
  ui_box_line "$(colorize "$C_LABEL" "Modo        :") $mode_render | $(colorize "$C_LABEL" "auto-safe:") $auto_safe_render | $(colorize "$C_LABEL" "watch-after:") $watch_after_render"
  ui_box_line "$(colorize "$C_LABEL" "Watch       :") $(colorize "$C_SECTION" "${WATCH_SECONDS}s") | $(colorize "$C_LABEL" "trigger") $(colorize "$C_SECTION" "${DROP_TRIGGER_MB} MB") | $(colorize "$C_LABEL" "intervalo") $(colorize "$C_SECTION" "${SAMPLE_INTERVAL}s")"
  ui_rule_soft
  ui_box_line "$hint"
  ui_rule_soft
  ui_box_line "$(colorize "$C_OPTION" "1.") $(colorize "$C_TITLE" "Doctor recomendado")"
  ui_box_line "   $(colorize "$C_HINT" "Diagnostica, encuentra focos grandes y abre limpieza guiada.")"
  ui_box_line "$(colorize "$C_OPTION" "2.") $(colorize "$C_SECTION" "Reporte")"
  ui_box_line "   $(colorize "$C_HINT" "Solo analiza; no intenta limpiar nada.")"
  ui_box_line "$(colorize "$C_OPTION" "3.") $(colorize "$C_SECTION" "Limpieza guiada")"
  ui_box_line "   $(colorize "$C_HINT" "Muestra opciones SAFE/CAUTION/DANGER para liberar espacio.")"
  ui_box_line "$(colorize "$C_OPTION" "4.") $(colorize "$C_SECTION" "Watch")"
  ui_box_line "   $(colorize "$C_HINT" "Vigila si el disco sigue cayendo y captura a los culpables.")"
  ui_box_line "$(colorize "$C_OPTION" "5.") $(colorize "$C_CAUTION" "Emergency")"
  ui_box_line "   $(colorize "$C_HINT" "Pausa Spotlight/Time Machine y aplica mitigacion inmediata.")"
  ui_box_line "$(colorize "$C_OPTION" "6.") $(colorize "$C_SECTION" "Resume")"
  ui_box_line "   $(colorize "$C_HINT" "Reactiva Spotlight y Time Machine.")"
  ui_box_line "$(colorize "$C_OPTION" "7.") $(colorize "$C_SECTION" "Alternar dry-run")"
  ui_box_line "   $(colorize "$C_LABEL" "Actual:") $(colorize_toggle "$(bool_label "$DRY_RUN")")"
  ui_box_line "$(colorize "$C_OPTION" "8.") $(colorize "$C_SECTION" "Alternar auto-safe (--yes)")"
  ui_box_line "   $(colorize "$C_LABEL" "Actual:") $(colorize_toggle "$(bool_label "$ASSUME_YES")")"
  ui_box_line "$(colorize "$C_OPTION" "9.") $(colorize "$C_SECTION" "Ajustes de watch")"
  ui_box_line "   $(colorize "$C_HINT" "Cambia presets y si quieres ejecutarlo al final.")"
  ui_box_line "$(colorize "$C_OPTION" "H.") $(colorize "$C_SECTION" "Ayuda")"
  ui_box_line "$(colorize "$C_OPTION" "0.") $(colorize "$C_MUTED" "Salir")"
  ui_box_bottom
}

run_watch_settings_menu() {
  local selection="" custom=""

  while true; do
    print -r -- ""
    ui_box_top
    ui_box_line "$(colorize "$C_TITLE" "Ajustes Watch")"
    ui_rule_soft
    ui_box_line "$(colorize "$C_LABEL" "Actual:") $(colorize "$C_SECTION" "${WATCH_SECONDS}s") | $(colorize "$C_LABEL" "trigger") $(colorize "$C_SECTION" "${DROP_TRIGGER_MB} MB") | $(colorize "$C_LABEL" "intervalo") $(colorize "$C_SECTION" "${SAMPLE_INTERVAL}s") | $(colorize "$C_LABEL" "watch-after") $(colorize_toggle "$(bool_label "$WATCH_AFTER")")"
    ui_rule_soft
    ui_box_line "$(colorize "$C_OPTION" "1.") $(colorize "$C_SECTION" "Rapido")"
    ui_box_line "   $(colorize "$C_HINT" "60s | trigger 512 MB | intervalo 5s")"
    ui_box_line "$(colorize "$C_OPTION" "2.") $(colorize "$C_SECTION" "Balanceado")"
    ui_box_line "   $(colorize "$C_HINT" "120s | trigger 1024 MB | intervalo 5s")"
    ui_box_line "$(colorize "$C_OPTION" "3.") $(colorize "$C_SECTION" "Extendido")"
    ui_box_line "   $(colorize "$C_HINT" "300s | trigger 1024 MB | intervalo 5s")"
    ui_box_line "$(colorize "$C_OPTION" "4.") $(colorize "$C_SECTION" "Alternar watch-after")"
    ui_box_line "$(colorize "$C_OPTION" "5.") $(colorize "$C_SECTION" "Personalizado")"
    ui_box_line "$(colorize "$C_OPTION" "0.") $(colorize "$C_MUTED" "Volver")"
    ui_box_bottom

    read "selection?Ajuste [2]: " || {
      print
      return 0
    }
    print
    selection="${selection:-2}"

    case "${selection:l}" in
      1|rapido)
        WATCH_SECONDS=60
        DROP_TRIGGER_MB=512
        SAMPLE_INTERVAL=5
        log_msg "Watch configurado en modo rapido."
        return 0
        ;;
      2|balanceado)
        WATCH_SECONDS=120
        DROP_TRIGGER_MB=1024
        SAMPLE_INTERVAL=5
        log_msg "Watch configurado en modo balanceado."
        return 0
        ;;
      3|extendido)
        WATCH_SECONDS=300
        DROP_TRIGGER_MB=1024
        SAMPLE_INTERVAL=5
        log_msg "Watch configurado en modo extendido."
        return 0
        ;;
      4|toggle|watch-after)
        WATCH_AFTER=$((1 - WATCH_AFTER))
        log_msg "watch-after ahora esta en $(bool_label "$WATCH_AFTER")."
        ;;
      5|custom|personalizado)
        read "custom?Duracion en segundos [${WATCH_SECONDS}]: " || true
        print
        [[ -n "${custom:-}" ]] && [[ "$custom" =~ '^[0-9]+$' ]] && WATCH_SECONDS="$custom"

        read "custom?Trigger en MB [${DROP_TRIGGER_MB}]: " || true
        print
        [[ -n "${custom:-}" ]] && [[ "$custom" =~ '^[0-9]+$' ]] && DROP_TRIGGER_MB="$custom"

        read "custom?Intervalo en segundos [${SAMPLE_INTERVAL}]: " || true
        print
        [[ -n "${custom:-}" ]] && [[ "$custom" =~ '^[0-9]+$' ]] && SAMPLE_INTERVAL="$custom"

        log_msg "Watch configurado manualmente."
        return 0
        ;;
      0|volver|back)
        return 0
        ;;
      *)
        print -r -- "Opcion no valida."
        ;;
    esac
  done
}

run_interactive_menu() {
  local selection=""

  while true; do
    render_main_menu

    read "selection?Seleccion [1]: " || {
      print
      COMMAND=""
      return 0
    }
    print
    selection="${selection:-1}"

    case "${selection:l}" in
      1|doctor)
        COMMAND="doctor"
        log_msg "Menu: seleccion doctor."
        return 0
        ;;
      2|report)
        COMMAND="report"
        log_msg "Menu: seleccion report."
        return 0
        ;;
      3|cleanup|limpieza)
        COMMAND="cleanup"
        log_msg "Menu: seleccion cleanup."
        return 0
        ;;
      4|watch|monitor)
        COMMAND="watch"
        log_msg "Menu: seleccion watch."
        return 0
        ;;
      5|emergency|emergencia)
        COMMAND="emergency"
        log_msg "Menu: seleccion emergency."
        return 0
        ;;
      6|resume|reanudar)
        COMMAND="resume"
        log_msg "Menu: seleccion resume."
        return 0
        ;;
      7|dry|dry-run)
        DRY_RUN=$((1 - DRY_RUN))
        log_msg "Menu: dry-run ahora esta en $(bool_label "$DRY_RUN")."
        ;;
      8|yes|auto-safe)
        ASSUME_YES=$((1 - ASSUME_YES))
        log_msg "Menu: auto-safe ahora esta en $(bool_label "$ASSUME_YES")."
        ;;
      9|settings|watch-settings)
        run_watch_settings_menu
        ;;
      h|help|ayuda|\?)
        usage
        pause_for_enter
        ;;
      0|q|quit|exit|salir)
        COMMAND=""
        log_msg "Menu: salida sin ejecutar acciones."
        return 0
        ;;
      *)
        print -r -- "Opcion no valida."
        pause_for_enter
        ;;
    esac
  done
}

report_autodesk_temp_dirs() {
  section "Autodesk / ODIS"

  local process_report=""
  process_report=$(autodesk_process_list || true)

  if [[ -n "$process_report" ]]; then
    ui_print_and_log "Procesos Autodesk/ODIS detectados:" "$(colorize "$C_LABEL" "Procesos Autodesk/ODIS detectados:")"
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      ui_print_and_log "$line" "    $(colorize "$C_MUTED" "$line")"
    done <<< "$process_report"
  else
    ui_print_and_log "No detecte procesos Autodesk/ODIS activos." "$(colorize "$C_SAFE" "No detecte procesos Autodesk/ODIS activos.")"
  fi

  local -a odis_dirs=()
  odis_dirs=("${(@f)$(find_autodesk_odis_dirs)}")

  if (( ${#odis_dirs[@]} == 0 )); then
    log_msg "No encontre carpetas odis_download_dest en /private/var/folders."
    return 0
  fi

  local target="" kb=0
  for target in "${odis_dirs[@]}"; do
    kb=$(size_kb_path "$target")
    ui_report_metric "ODIS temp" "$(human_from_kb "$kb")" "$target" "" "$(autodesk_cleanup_busy && print caution || print safe)"
    if autodesk_cleanup_busy; then
      ui_print_and_log "    AutoCAD/Autodesk Access/ODIS parece activo; no conviene borrar esto todavia." "    $(colorize "$C_CAUTION" "AutoCAD/Autodesk Access/ODIS parece activo; no conviene borrar esto todavia.")"
    else
      ui_print_and_log "    No detecte AutoCAD ni Autodesk Access activos; este cache temporal suele ser reclamable." "    $(colorize "$C_SAFE" "No detecte AutoCAD ni Autodesk Access activos; este cache temporal suele ser reclamable.")"
    fi
    {
      du -sh "$target"/* 2>/dev/null || true
    } | sort -h | tail -n 5 | while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      ui_print_and_log "$line" "    $(colorize "$C_MUTED" "$line")"
    done
  done
}

top_directories() {
  local root="$1"
  local limit="${2:-8}"

  [[ -d "$root" ]] || return 0

  section "Top directorios en $root"

  {
    du -xhd 1 "$root" 2>/dev/null || true
  } | sort -h | tail -n "$limit" | while IFS=$'\t' read -r size target; do
    [[ -z "${target:-}" ]] && continue
    local result="" level="" note=""
    result=$(categorize_path "$target")
    level="${result%%|*}"
    note="${result#*|}"
    ui_report_item "${level:l}" "$size  $target" "$note"
  done
}

count_tm_snapshots() {
  tmutil listlocalsnapshots / 2>/dev/null | awk '/com\.apple\.TimeMachine\./ {count++} END {print count + 0}'
}

show_snapshot_summary() {
  section "Snapshots"

  local tm_count
  tm_count=$(count_tm_snapshots)
  ui_report_metric "Snapshots locales de Time Machine detectados" "$tm_count"

  if (( tm_count > 0 )); then
    tmutil listlocalsnapshots / 2>&1 | tee -a "$LOG"
  fi

  local apfs_report="$REPORT_DIR/apfs_snapshots.txt"
  diskutil apfs listSnapshots / >"$apfs_report" 2>&1 || true

  if grep -qi "No snapshots" "$apfs_report"; then
    ui_print_and_log "No se detectaron snapshots APFS en el volumen raiz." "$(colorize "$C_SAFE" "No se detectaron snapshots APFS en el volumen raiz.")"
  else
    ui_print_and_log "Resumen APFS guardado en: $apfs_report" "$(colorize "$C_LABEL" "Resumen APFS guardado en:") $(colorize "$C_MUTED" "$apfs_report")"
    sed -n '1,60p' "$apfs_report" | tee -a "$LOG"
  fi
}

show_open_deleted_files() {
  section "Archivos abiertos pero ya borrados"

  local out="$REPORT_DIR/open_deleted_files.txt"

  if (( EUID == 0 )) || sudo -n true 2>/dev/null; then
    if (( EUID == 0 )); then
      lsof -nP +L1 >"$out" 2>/dev/null || true
    else
      sudo lsof -nP +L1 >"$out" 2>/dev/null || true
    fi

    if [[ -s "$out" ]]; then
      head -n 40 "$out" | tee -a "$LOG"
      ui_print_and_log "Listado completo guardado en: $out" "$(colorize "$C_LABEL" "Listado completo guardado en:") $(colorize "$C_MUTED" "$out")"
    else
      ui_print_and_log "No se detectaron archivos abiertos-eliminados." "$(colorize "$C_SAFE" "No se detectaron archivos abiertos-eliminados.")"
    fi
  else
    ui_print_and_log "Sin sudo cacheado; omito esta parte para no interrumpir el flujo." "$(colorize "$C_CAUTION" "Sin sudo cacheado; omito esta parte para no interrumpir el flujo.")"
  fi
}

scan_recent_logs() {
  section "Unified logs recientes"

  local out="$REPORT_DIR/unified_logs.txt"

  {
    print -r -- "=== Spotlight / mds ==="
    /usr/bin/log show --last "$LOG_HORIZON" --info --predicate 'process == "mds" || process == "mds_stores" || process == "mdworker_shared"' 2>/dev/null | tail -n 80
    print -r -- ""
    print -r -- "=== Time Machine / backupd ==="
    /usr/bin/log show --last "$LOG_HORIZON" --info --predicate 'process == "backupd" || subsystem CONTAINS "backup"' 2>/dev/null | tail -n 80
    print -r -- ""
    print -r -- "=== APFS / snapshots / purge ==="
    /usr/bin/log show --last "$LOG_HORIZON" --info --predicate 'subsystem CONTAINS "apfs" OR eventMessage CONTAINS[c] "snapshot" OR eventMessage CONTAINS[c] "purge" OR eventMessage CONTAINS[c] "reclaim"' 2>/dev/null | tail -n 80
    print -r -- ""
    print -r -- "=== softwareupdated / installd ==="
    /usr/bin/log show --last "$LOG_HORIZON" --info --predicate 'process == "softwareupdated" || process == "installd"' 2>/dev/null | tail -n 80
  } >"$out"

  ui_print_and_log "Resumen de logs guardado en: $out" "$(colorize "$C_LABEL" "Resumen de logs guardado en:") $(colorize "$C_MUTED" "$out")"
  sed -n '1,40p' "$out" | tee -a "$LOG"
}

capture_fs_usage() {
  section "Captura de escrituras de disco"

  ensure_sudo

  local out="$REPORT_DIR/fs_usage.txt"
  local err="$REPORT_DIR/fs_usage.err"
  local summary="$REPORT_DIR/fs_usage_summary.txt"

  ui_event info "TRACE" "Capturando actividad de archivos durante ${FS_CAPTURE_SECONDS}s."

  if ! sudo fs_usage -w -f filesys "$FS_CAPTURE_SECONDS" >"$out" 2>"$err"; then
    ui_event caution "TRACE" "fs_usage devolvio error; revisa $err"
  fi

  if [[ ! -s "$out" ]]; then
    ui_event caution "TRACE" "fs_usage no entrego datos. Dale Full Disk Access a Terminal/Codex y vuelve a probar."
    [[ -s "$err" ]] && sed -n '1,20p' "$err" | tee -a "$LOG"
    return 0
  fi

  awk '
    /WRIT|WRITE|CREAT|RENAM|UNLNK|TRUNC|fsync/ {
      proc = $NF
      sub(/\.[0-9]+$/, "", proc)
      if (proc ~ /^[A-Za-z0-9._-]+$/) {
        print proc
      }
    }
  ' "$out" | sort | uniq -c | sort -nr | head -n 15 >"$summary"

  if [[ -s "$summary" ]]; then
    ui_event safe "TRACE" "Top procesos capturados."
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      ui_print_and_log "$line" "    $(colorize "$C_MUTED" "$line")"
    done < "$summary"
  else
    ui_event info "TRACE" "No pude resumir procesos a partir de fs_usage, pero deje la traza cruda en: $out"
  fi
}

pause_spotlight() {
  section "Pausando Spotlight"
  if (( DRY_RUN == 1 )); then
    ui_event info "DRY-RUN" "sudo mdutil -i off /"
    return 0
  fi
  ensure_sudo
  ui_event caution "SPOT" "Desactivando indexado en /"
  sudo mdutil -i off / 2>&1 | tee -a "$LOG" || true
}

resume_spotlight() {
  section "Reactivando Spotlight"
  if (( DRY_RUN == 1 )); then
    ui_event info "DRY-RUN" "sudo mdutil -i on /"
    return 0
  fi
  ensure_sudo
  ui_event safe "SPOT" "Reactivando indexado en /"
  sudo mdutil -i on / 2>&1 | tee -a "$LOG" || true
}

disable_time_machine() {
  section "Pausando Time Machine"
  if (( DRY_RUN == 1 )); then
    ui_event info "DRY-RUN" "sudo tmutil disable"
    return 0
  fi
  ensure_sudo
  ui_event caution "TM" "Pausando AutoBackup de Time Machine"
  sudo tmutil disable 2>&1 | tee -a "$LOG" || true
}

enable_time_machine() {
  section "Reactivando Time Machine"
  if (( DRY_RUN == 1 )); then
    ui_event info "DRY-RUN" "sudo tmutil enable"
    return 0
  fi
  ensure_sudo
  ui_event safe "TM" "Reactivando AutoBackup de Time Machine"
  sudo tmutil enable 2>&1 | tee -a "$LOG" || true
}

thin_tm_snapshots_now() {
  section "Adelgazando snapshots locales"
  if (( DRY_RUN == 1 )); then
    ui_event info "DRY-RUN" "sudo tmutil thinlocalsnapshots / 5000000000 4"
    return 0
  fi
  ensure_sudo
  ui_event caution "TM" "Intentando recuperar hasta ~5 GB de snapshots locales"
  sudo tmutil thinlocalsnapshots / 5000000000 4 2>&1 | tee -a "$LOG" || true
}

show_service_status() {
  section "Estado de Spotlight y Time Machine"
  ui_event info "STATUS" "Consultando estado de Spotlight"
  mdutil -s / 2>&1 | tee -a "$LOG" || true
  ui_event info "STATUS" "Consultando estado de AutoBackup de Time Machine"
  defaults read /Library/Preferences/com.apple.TimeMachine AutoBackup 2>/dev/null | tee -a "$LOG" || true
}

add_path_candidate() {
  local id="$1"
  local level="$2"
  local label="$3"
  local target="$4"
  local note="$5"
  local needs_root="$6"
  local action="${7:-delete_path}"
  local kb

  [[ -e "$target" ]] || return 0

  kb=$(size_kb_path "$target")
  (( kb > 0 )) || return 0

  CANDIDATE_ORDER+=("$id")
  CANDIDATE_LABEL[$id]="$label"
  CANDIDATE_PATH[$id]="$target"
  CANDIDATE_LEVEL[$id]="$level"
  CANDIDATE_NOTE[$id]="$note"
  CANDIDATE_ROOT[$id]="$needs_root"
  CANDIDATE_ACTION[$id]="$action"
  CANDIDATE_SIZE_KB[$id]="$kb"
}

add_action_candidate() {
  local id="$1"
  local level="$2"
  local label="$3"
  local note="$4"
  local action="$5"
  local needs_root="$6"
  local size_kb="${7:-0}"

  CANDIDATE_ORDER+=("$id")
  CANDIDATE_LABEL[$id]="$label"
  CANDIDATE_PATH[$id]=""
  CANDIDATE_LEVEL[$id]="$level"
  CANDIDATE_NOTE[$id]="$note"
  CANDIDATE_ROOT[$id]="$needs_root"
  CANDIDATE_ACTION[$id]="$action"
  CANDIDATE_SIZE_KB[$id]="$size_kb"
}

register_autodesk_cleanup_candidates() {
  local -a odis_dirs=()
  odis_dirs=("${(@f)$(find_autodesk_odis_dirs)}")

  (( ${#odis_dirs[@]} > 0 )) || return 0

  local idx=1
  local target="" level="" note="" label=""

  for target in "${odis_dirs[@]}"; do
    if autodesk_cleanup_busy; then
      level="caution"
      note="Detecte AutoCAD, Autodesk Access u ODIS activos. Cierra esas apps antes de borrar este cache temporal."
    else
      level="safe"
      note="No detecte AutoCAD ni Autodesk Access activos. Este cache temporal de ODIS suele ser seguro de borrar."
    fi

    label="Limpiar temporales Autodesk ODIS #$idx"
    add_path_candidate "autodesk-odis-$idx" "$level" "$label" "$target" "$note" 0 "delete_autodesk_temp"
    idx=$((idx + 1))
  done
}

register_cleanup_candidates() {
  CANDIDATE_ORDER=()
  CANDIDATE_LABEL=()
  CANDIDATE_PATH=()
  CANDIDATE_LEVEL=()
  CANDIDATE_NOTE=()
  CANDIDATE_ROOT=()
  CANDIDATE_ACTION=()
  CANDIDATE_SIZE_KB=()

  register_autodesk_cleanup_candidates

  add_path_candidate "installer-data" "safe" "Borrar macOS Install Data" "/System/Volumes/Data/macOS Install Data" "Residuo comun del instalador de macOS." 1
  add_path_candidate "xcode-derived" "safe" "Borrar DerivedData" "$HOME/Library/Developer/Xcode/DerivedData" "Artefactos temporales de compilacion." 0
  add_path_candidate "xcode-cache" "safe" "Borrar cache de Xcode" "$HOME/Library/Caches/com.apple.dt.Xcode" "Cache descargada por Xcode." 0
  add_path_candidate "xcode-doc-cache" "safe" "Borrar DocumentationCache" "$HOME/Library/Developer/Xcode/DocumentationCache" "Cache de documentacion de Xcode." 0
  add_path_candidate "swiftpm-cache" "safe" "Borrar cache de SwiftPM" "$HOME/Library/Caches/org.swift.swiftpm" "Cache de Swift Package Manager." 0
  add_path_candidate "homebrew-cache" "safe" "Borrar cache de Homebrew" "$HOME/Library/Caches/Homebrew" "Paquetes descargados por Homebrew." 0
  add_path_candidate "coresim-cache" "safe" "Borrar cache de CoreSimulator" "$HOME/Library/Developer/CoreSimulator/Caches" "Caches temporales de simuladores." 0
  add_path_candidate "coresim-logs" "safe" "Borrar logs de CoreSimulator" "$HOME/Library/Logs/CoreSimulator" "Logs viejos de simuladores." 0
  add_path_candidate "diagnostic-reports" "safe" "Borrar DiagnosticReports" "$HOME/Library/Logs/DiagnosticReports" "Crash reports y diagnosticos viejos." 0

  local tm_count
  tm_count=$(count_tm_snapshots)
  if (( tm_count > 0 )); then
    add_action_candidate "tm-thin" "safe" "Adelgazar snapshots locales de Time Machine" "Se detectaron $tm_count snapshots locales; intentare recuperar hasta ~5 GB." "thin_snapshots" 1
  fi

  add_path_candidate "xcode-archives" "caution" "Borrar Archives de Xcode" "$HOME/Library/Developer/Xcode/Archives" "Guardan builds exportados; borralos solo si ya no los necesitas." 0
  add_path_candidate "ios-device-support" "caution" "Borrar iOS DeviceSupport" "$HOME/Library/Developer/Xcode/iOS DeviceSupport" "Se puede regenerar al conectar dispositivos o depurar versiones viejas." 0
  add_path_candidate "simulator-devices" "caution" "Borrar Devices de CoreSimulator" "$HOME/Library/Developer/CoreSimulator/Devices" "Libera mucho espacio, pero perderas datos de simuladores." 0
  add_path_candidate "library-updates" "caution" "Vaciar /Library/Updates" "/Library/Updates" "Hazlo solo si softwareupdated ya termino; se borran descargas temporales de actualizacion." 1 "delete_contents"

  add_path_candidate "clt-uninstall" "danger" "Desinstalar Command Line Tools" "/Library/Developer/CommandLineTools" "Solo si ya no necesitas clang, git ni los SDKs. Luego puedes reinstalarlas con xcode-select --install." 1
}

append_selected_by_level() {
  local level="$1"
  local id=""
  for id in "${CANDIDATE_ORDER[@]}"; do
    [[ "${CANDIDATE_LEVEL[$id]}" == "$level" ]] && print -r -- "$id"
  done
  return 0
}

perform_delete_path() {
  local target="$1"
  local needs_root="$2"

  if (( DRY_RUN == 1 )); then
    if [[ "$needs_root" == "1" ]]; then
      log_msg "[dry-run] sudo rm -rf -- $target"
    else
      log_msg "[dry-run] rm -rf -- $target"
    fi
    return 0
  fi

  if [[ "$needs_root" == "1" ]]; then
    ensure_sudo
    run_cmd sudo rm -rf -- "$target"
  else
    run_cmd rm -rf -- "$target"
  fi
}

perform_delete_contents() {
  local target="$1"
  local needs_root="$2"

  [[ -d "$target" ]] || return 0

  if (( DRY_RUN == 1 )); then
    if [[ "$needs_root" == "1" ]]; then
      log_msg "[dry-run] sudo find $target -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +"
    else
      log_msg "[dry-run] find $target -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +"
    fi
    return 0
  fi

  if [[ "$needs_root" == "1" ]]; then
    ensure_sudo
    run_cmd sudo find "$target" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
  else
    run_cmd find "$target" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
  fi
}

perform_candidate() {
  local id="$1"
  local action="${CANDIDATE_ACTION[$id]}"
  local target="${CANDIDATE_PATH[$id]}"
  local needs_root="${CANDIDATE_ROOT[$id]}"

  case "$action" in
    delete_path)
      perform_delete_path "$target" "$needs_root"
      ;;
    delete_autodesk_temp)
      if autodesk_cleanup_busy; then
        log_msg "Autodesk/ODIS sigue activo; no borrare $target todavia."
        log_msg "Cierra AutoCAD y Autodesk Access, luego vuelve a ejecutar cleanup."
        return 1
      fi
      perform_delete_path "$target" "$needs_root"
      ;;
    delete_contents)
      perform_delete_contents "$target" "$needs_root"
      ;;
    thin_snapshots)
      thin_tm_snapshots_now
      ;;
    *)
      log_msg "Accion no reconocida para $id: $action"
      return 1
      ;;
  esac
}

confirm_candidate() {
  local id="$1"
  local level="${CANDIDATE_LEVEL[$id]}"
  local label="${CANDIDATE_LABEL[$id]}"
  local target="${CANDIDATE_PATH[$id]}"

  case "$level" in
    safe)
      if (( ASSUME_YES == 1 )); then
        return 0
      fi
      confirm_yes_no "Limpiar '$label' ahora? [y/N]"
      ;;
    caution)
      log_msg "CAUTION: $label"
      [[ -n "$target" ]] && log_msg "Ruta: $target"
      log_msg "${CANDIDATE_NOTE[$id]}"
      confirm_token "Escribe BORRAR para continuar, o Enter para omitir: " "BORRAR"
      ;;
    danger)
      log_msg "DANGER: $label"
      [[ -n "$target" ]] && log_msg "Ruta: $target"
      log_msg "${CANDIDATE_NOTE[$id]}"
      confirm_token "Escribe UNINSTALL para continuar, o Enter para omitir: " "UNINSTALL"
      ;;
    *)
      return 1
      ;;
  esac
}

run_cleanup_menu() {
  register_cleanup_candidates

  if (( ${#CANDIDATE_ORDER[@]} == 0 )); then
    section "Limpieza"
    log_msg "No encontre objetivos claros de limpieza en las rutas conocidas."
    return 0
  fi

  section "Objetivos de limpieza"
  if (( COLOR_ENABLED == 1 )); then
    print -r -- "$(colorize "$C_TITLE" "Objetivos de limpieza")"
    print -r -- "$(colorize "$C_HINT" "SAFE limpia caches o residuos regenerables; CAUTION requiere revisar; DANGER desinstala o toca componentes pesados.")"
  fi

  typeset -A INDEX_TO_ID=()
  local idx=1
  local id=""
  for id in "${CANDIDATE_ORDER[@]}"; do
    INDEX_TO_ID[$idx]="$id"
    local size_text="" badge="" plain_line="" styled_line="" plain_path="" styled_path="" plain_note="" styled_note=""
    size_text=$(human_from_kb "${CANDIDATE_SIZE_KB[$id]}")
    badge=$(level_badge "${CANDIDATE_LEVEL[$id]}")
    plain_line=$(printf '%2d. [%-7s] %-9s %s' "$idx" "$badge" "$size_text" "${CANDIDATE_LABEL[$id]}")
    styled_line="$(printf '%2d. ' "$idx")[$(styled_level_badge "${CANDIDATE_LEVEL[$id]}")] $(colorize_by_level "${CANDIDATE_LEVEL[$id]}" "$size_text") $(colorize "$C_SECTION" "${CANDIDATE_LABEL[$id]}")"
    print -r -- "$styled_line"
    append_log_plain "$plain_line"

    if [[ -n "${CANDIDATE_PATH[$id]}" ]]; then
      plain_path="    ${CANDIDATE_PATH[$id]}"
      styled_path="    $(colorize "$C_MUTED" "${CANDIDATE_PATH[$id]}")"
      print -r -- "$styled_path"
      append_log_plain "$plain_path"
    fi

    plain_note="    ${CANDIDATE_NOTE[$id]}"
    styled_note="    $(colorize "$C_HINT" "${CANDIDATE_NOTE[$id]}")"
    print -r -- "$styled_note"
    append_log_plain "$plain_note"
    idx=$((idx + 1))
  done

  local selection=""
  local -a selected_ids

  if (( ASSUME_YES == 1 )); then
    selected_ids=("${(@f)$(append_selected_by_level safe)}")
    selected_ids=("${(@)selected_ids:#}")
    log_msg "Seleccion automatica: solo opciones SAFE."
  else
    print -r -- ""
    print -r -- "$(colorize "$C_HINT" "Pulsa Enter para limpiar solo SAFE, escribe numeros separados por comas, 'all' para todo o 0 para omitir.")"
    append_log_plain ""
    append_log_plain "Pulsa Enter para limpiar solo SAFE, escribe numeros separados por comas, 'all' para todo o 0 para omitir."
    read "selection?Seleccion [safe]: " || {
      print
      selection="0"
    }
    print
    selection="${selection:-safe}"

    case "$selection" in
      0|none|NONE)
        log_msg "Limpieza omitida por el usuario."
        return 0
        ;;
      safe|SAFE)
        selected_ids=("${(@f)$(append_selected_by_level safe)}")
        selected_ids=("${(@)selected_ids:#}")
        ;;
      all|ALL)
        selected_ids=("${CANDIDATE_ORDER[@]}")
        ;;
      *)
        local -a raw_numbers=()
        IFS=',' read -rA raw_numbers <<< "$selection"
        local raw="" num=""
        for raw in "${raw_numbers[@]}"; do
          num="${raw//[[:space:]]/}"
          [[ "$num" =~ '^[0-9]+$' ]] || continue
          [[ -n "${INDEX_TO_ID[$num]:-}" ]] || continue
          selected_ids+=("${INDEX_TO_ID[$num]}")
        done
        ;;
    esac
  fi

  selected_ids=("${(@)selected_ids:#}")

  if (( ${#selected_ids[@]} == 0 )); then
    log_msg "No hay elementos seleccionados para limpiar."
    return 0
  fi

  local before=0 after=0 freed=0 total_freed=0
  before=$(bytes_free)

  section "Ejecucion de limpieza"

  for id in "${selected_ids[@]}"; do
    local target="" size_text=""
    target="${CANDIDATE_PATH[$id]}"
    size_text=$(human_from_kb "${CANDIDATE_SIZE_KB[$id]}")
    log_msg "Objetivo: ${CANDIDATE_LABEL[$id]} (${size_text})"
    [[ -n "$target" ]] && log_msg "Ruta: $target"

    if ! confirm_candidate "$id"; then
      log_msg "Omitido: ${CANDIDATE_LABEL[$id]}"
      continue
    fi

    if perform_candidate "$id"; then
      log_msg "Completado: ${CANDIDATE_LABEL[$id]}"
    else
      log_msg "Fallo: ${CANDIDATE_LABEL[$id]}"
    fi
  done

  after=$(bytes_free)
  freed=$((after - before))
  (( freed < 0 )) && freed=0
  total_freed=$freed

  section "Resultado de limpieza"
  log_msg "Espacio libre antes: $(human_from_bytes "$before")"
  log_msg "Espacio libre despues: $(human_from_bytes "$after")"
  log_msg "Espacio recuperado ahora: $(human_from_bytes "$total_freed")"
  df -H / | tee -a "$LOG"
}

report_disk_state() {
  section "Estado actual del disco"
  df -H / | tee -a "$LOG"
  ui_report_metric "Espacio libre actual" "$(pretty_free)" "" "Disponibilidad visible en el volumen raiz." "safe"
}

report_known_growth_paths() {
  section "Rutas que suelen crecer tras reinstalar macOS o herramientas de desarrollo"

  report_path_size "CommandLineTools" "/Library/Developer/CommandLineTools" "Las CLT reales viven aqui. Si esto pesa poco y el disco igual cae, el problema es otro proceso."
  report_path_size "Library/Developer" "/Library/Developer" "Raiz comun de CLT, simuladores y otros assets de desarrollo."
  report_path_size "macOS Install Data" "/System/Volumes/Data/macOS Install Data" "Residuo habitual de instaladores de macOS."
  report_path_size "User Developer" "$HOME/Library/Developer" "DerivedData, simuladores, archives y otros artefactos del usuario."
  report_path_size "User Caches" "$HOME/Library/Caches" "Caches generales del usuario; aqui suele esconderse crecimiento rapido."
  report_path_size "User Logs" "$HOME/Library/Logs" "Logs grandes o runaway logs terminan aqui."
  report_path_size "Library/Updates" "/Library/Updates" "Descargas temporales de actualizaciones de macOS."
  report_path_size "var/folders" "/private/var/folders" "Temporales de apps e instaladores; Autodesk/ODIS suele crecer aqui."
}

hunt_large_directories() {
  top_directories "/Library/Developer" 8
  top_directories "$HOME/Library/Developer" 8
  top_directories "$HOME/Library/Caches" 10
  top_directories "$HOME/Library/Logs" 10
  top_directories "/private/var/folders" 10
}

maybe_offer_mitigations() {
  local summary="$REPORT_DIR/fs_usage_summary.txt"
  [[ -s "$summary" ]] || return 0

  if grep -Eiq '(^|[[:space:]])mds(_stores)?([[:space:]]|$)|mdworker_shared' "$summary"; then
    log_msg "Pista: Spotlight parece estar escribiendo con fuerza."
    if confirm_yes_no "Pausar Spotlight temporalmente en / ? [y/N]"; then
      pause_spotlight
    fi
  fi

  if grep -Eiq '(^|[[:space:]])backupd([[:space:]]|$)|MobileTimeMachine' "$summary"; then
    log_msg "Pista: Time Machine aparece entre los escritores."
    if confirm_yes_no "Pausar AutoBackup de Time Machine temporalmente? [y/N]"; then
      disable_time_machine
    fi
    if confirm_yes_no "Intentar adelgazar snapshots locales ahora? [y/N]"; then
      thin_tm_snapshots_now
    fi
  fi

  if grep -Eiq 'softwareupdated|installd' "$summary"; then
    log_msg "Pista: softwareupdated/installd aparece activo. Eso puede ser normal justo despues de reinstalar macOS."
  fi
}

watch_disk_drain() {
  section "Monitoreo de caida de espacio libre"

  local threshold_bytes=$((DROP_TRIGGER_MB * 1024 * 1024))
  local start_free current_free prev_free delta total_drop elapsed=0
  local delta_text="" trend="" tick_level=""

  start_free=$(bytes_free)
  prev_free="$start_free"

  ui_event info "WATCH" "Libre inicial $(human_from_bytes "$start_free") | duracion ${WATCH_SECONDS}s | intervalo ${SAMPLE_INTERVAL}s | disparo ${DROP_TRIGGER_MB} MB"

  while (( elapsed < WATCH_SECONDS )); do
    sleep "$SAMPLE_INTERVAL"
    elapsed=$((elapsed + SAMPLE_INTERVAL))
    current_free=$(bytes_free)
    delta=$((current_free - prev_free))
    total_drop=$((start_free - current_free))

    delta_text=$(human_from_bytes "${delta#-}")
    if (( delta < 0 )); then
      trend="menos"
      tick_level="caution"
    elif (( delta > 0 )); then
      trend="mas"
      tick_level="safe"
    else
      trend="sin cambio"
      tick_level="info"
    fi

    ui_event "$tick_level" "T+${elapsed}s" "delta=${delta_text} ${trend} | libre=$(human_from_bytes "$current_free") | caida=$(human_from_bytes "${total_drop#-}")"

    if (( total_drop >= threshold_bytes )); then
      ui_event danger "ALERTA" "Se detecto una caida acumulada de al menos ${DROP_TRIGGER_MB} MB."
      ui_event info "WATCH" "Reuniendo evidencia: fs_usage, snapshots, archivos abiertos y logs recientes."
      capture_fs_usage
      show_snapshot_summary
      show_open_deleted_files
      scan_recent_logs
      maybe_offer_mitigations
      return 0
    fi

    prev_free="$current_free"
  done

  ui_event safe "OK" "No se detecto una caida brusca dentro de la ventana de monitoreo."
}

run_report() {
  report_disk_state
  report_known_growth_paths
  report_autodesk_temp_dirs
  show_snapshot_summary
  show_open_deleted_files
  hunt_large_directories
}

run_doctor() {
  run_report
  run_cleanup_menu

  if (( WATCH_AFTER == 1 )); then
    watch_disk_drain
  fi
}

run_emergency() {
  section "Mitigacion de emergencia"
  ui_event caution "EMERGENCY" "Se pausaran Spotlight y Time Machine temporalmente, se adelgazaran snapshots y se revisaran residuos grandes."

  if (( ASSUME_YES == 0 )); then
    confirm_yes_no "Esto pausara Spotlight y Time Machine temporalmente. Continuar? [y/N]" || {
      ui_event info "CANCELADO" "Mitigacion cancelada."
      return 0
    }
  fi

  pause_spotlight
  disable_time_machine
  thin_tm_snapshots_now

  if [[ -d "/System/Volumes/Data/macOS Install Data" ]]; then
    ui_event caution "CLEAN" "Tambien intentare limpiar macOS Install Data."
    perform_delete_path "/System/Volumes/Data/macOS Install Data" 1 || true
  fi

  show_service_status
  show_snapshot_summary
  report_disk_state
  ui_event safe "EMERGENCY" "Mitigacion completada. Revisa el estado actual arriba."
}

run_resume() {
  section "Reanudando servicios"
  ui_event safe "RESUME" "Intentando restaurar Spotlight y Time Machine a su estado normal."
  resume_spotlight
  enable_time_machine
  show_service_status
  ui_event safe "RESUME" "Servicios reactivados."
}

parse_args() {
  local arg
  while (( $# > 0 )); do
    arg="$1"
    case "$arg" in
      menu|doctor|report|cleanup|watch|emergency|resume)
        COMMAND="$arg"
        ;;
      --yes)
        ASSUME_YES=1
        ;;
      --dry-run)
        DRY_RUN=1
        ;;
      --watch)
        WATCH_AFTER=1
        ;;
      --watch-seconds)
        WATCH_SECONDS="$2"
        shift
        ;;
      --interval)
        SAMPLE_INTERVAL="$2"
        shift
        ;;
      --drop-mb)
        DROP_TRIGGER_MB="$2"
        shift
        ;;
      --fs-seconds)
        FS_CAPTURE_SECONDS="$2"
        shift
        ;;
      --log-horizon)
        LOG_HORIZON="$2"
        shift
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        print -r -- "Argumento no reconocido: $arg" >&2
        usage >&2
        exit 1
        ;;
    esac
    shift
  done
}

main() {
  require_cmds
  init_colors

  if (( $# == 0 )) && [[ -t 0 && -t 1 ]]; then
    COMMAND="menu"
  fi

  parse_args "$@"

  log_msg "Disk rescue iniciado. Reporte: $REPORT_DIR"

  if [[ "$COMMAND" == "menu" ]]; then
    run_interactive_menu
    if [[ -z "$COMMAND" ]]; then
      log_msg "Listo. Log principal: $LOG"
      return 0
    fi
  fi

  log_msg "Comando: $COMMAND"

  case "$COMMAND" in
    menu)
      run_interactive_menu
      ;;
    doctor)
      run_doctor
      ;;
    report)
      run_report
      (( WATCH_AFTER == 1 )) && watch_disk_drain
      ;;
    cleanup)
      run_cleanup_menu
      (( WATCH_AFTER == 1 )) && watch_disk_drain
      ;;
    watch)
      watch_disk_drain
      ;;
    emergency)
      run_emergency
      ;;
    resume)
      run_resume
      ;;
  esac

  log_msg "Listo. Log principal: $LOG"
}

main "$@"
