#!/bin/zsh
set -euo pipefail

# Disk Guardian Reforzado - Monitoreo avanzado de disco con bloqueo de red
# Requiere permisos de administrador y Full Disk Access

# --- 1) Forzamos un PATH completo para root en sudo/zsh ---
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# Verificar dependencias
for cmd in df awk tee date afplay fs_usage grep pfctl; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "Error: $cmd no está disponible." >&2
    exit 1
  fi
done

# Verificar permisos de administrador
if [[ $EUID -ne 0 ]]; then
  echo "Advertencia: Este script requiere permisos de administrador." >&2
  echo "También necesita Full Disk Access en Preferencias del Sistema." >&2
fi

# --- 2) Configuración ---
MIN_FREE_GB=15
WATCH_PATHS=(
  "/usr/local"
  "/private/var"
  "$HOME/Documents"
)
LOGFILE="$HOME/Public/disk_guardian_log_$(date +%Y%m%d_%H%M%S).log"
ALERT_SOUND="/System/Library/Sounds/Funk.aiff"
PF_BLOCK_RULES="/etc/pf.anchors/guardian_block"
CHILD_PIDS=()

# Crear directorio de logs si no existe
mkdir -p "$(dirname "$LOGFILE")" 2>/dev/null || true

# Verificar que el archivo de sonido existe, usar fallback si no
if [[ ! -f "$ALERT_SOUND" ]]; then
  ALERT_SOUND="/System/Library/Sounds/Glass.aiff"  # Fallback
  [[ ! -f "$ALERT_SOUND" ]] && ALERT_SOUND=""  # Desactivar si no existe
fi

# --- 3) Funciones ---

check_free_space() {
  local free
  free=$(/bin/df -g / | /usr/bin/awk 'NR==2 {print $(NF-2)}')
  if (( free < MIN_FREE_GB )); then
    echo "$(/usr/bin/date) ⚠️ Low disk space: ${free}GB" | /usr/bin/tee -a "$LOGFILE"
    [[ -n "$ALERT_SOUND" && -f "$ALERT_SOUND" ]] && /usr/bin/afplay "$ALERT_SOUND" 2>/dev/null || true
  fi
}

block_network() {
  echo "$(/usr/bin/date) 🌐 Blocking network via pfctl..." | /usr/bin/tee -a "$LOGFILE"
  sudo /usr/bin/tee "$PF_BLOCK_RULES" > /dev/null <<EOF
block drop out quick on en0 all
block drop out quick on en1 all
EOF

  if ! /usr/bin/grep -q "anchor \"guardian_block\"" /etc/pf.conf; then
    echo "anchor \"guardian_block\"" | sudo /usr/bin/tee -a /etc/pf.conf > /dev/null
    echo "load anchor \"guardian_block\" from \"$PF_BLOCK_RULES\"" | sudo /usr/bin/tee -a /etc/pf.conf > /dev/null
  fi

  sudo /sbin/pfctl -f /etc/pf.conf
  sudo /sbin/pfctl -e
  echo "$(/usr/bin/date) ✅ Network blocked." | /usr/bin/tee -a "$LOGFILE"
}

watch_paths() {
  for path in "${WATCH_PATHS[@]}"; do
    if [[ -d "$path" ]]; then
      (
        /usr/bin/fs_usage -w -f filesys "$path" 2>/dev/null | /usr/bin/grep --line-buffered 'WRITING' |
        while IFS= read -r line || [[ -n "$line" ]]; do
          echo "$(/usr/bin/date) 🛑 WRITE attempt in $path" | /usr/bin/tee -a "$LOGFILE"
          [[ -f "$ALERT_SOUND" ]] && /usr/bin/afplay "$ALERT_SOUND" 2>/dev/null || true
          block_network
          break
        done
      ) &
      CHILD_PIDS+=($!)
    fi
  done
}

cleanup() {
  echo "\n⏹️ Exiting cleanly. Killing watchers..." | /usr/bin/tee -a "$LOGFILE"
  for pid in "${CHILD_PIDS[@]}"; do
    [[ -n "$pid" ]] && /bin/kill "$pid" 2>/dev/null || true
  done
  # Esperar un momento para que los procesos terminen
  sleep 1
  # Forzar kill si aún están corriendo
  for pid in "${CHILD_PIDS[@]}"; do
    [[ -n "$pid" ]] && /bin/kill -9 "$pid" 2>/dev/null || true
  done
  echo "🧹 Cleanup complete. Log saved at: $LOGFILE" | /usr/bin/tee -a "$LOGFILE"
  exit 0
}

# --- 4) Capturar Ctrl+C para limpieza ---
trap cleanup SIGINT SIGTERM EXIT

# --- 5) Inicio ---
echo "🛡️ Disk Guardian started: $(/usr/bin/date)" | /usr/bin/tee "$LOGFILE"
check_free_space
watch_paths

# --- 6) Loop principal ---
while true; do
  /bin/sleep 30
  check_free_space
done

