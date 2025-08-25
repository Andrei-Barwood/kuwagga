#!/bin/zsh

# Configuración
THRESHOLD_BYTES=$((87 * 1024 * 1024 * 1024))  # 87 GiB
INTERVAL=60  # Intervalo de chequeo (segundos)
LOGFILE="$HOME/Library/Logs/disk_guard.log"
PIDFILE="$HOME/.disk_guard.pid"

# Evita ejecución duplicada
if [[ -f "$PIDFILE" ]]; then
  if kill -0 $(cat "$PIDFILE") 2>/dev/null; then
    echo "⚠️ Disk Guard ya está corriendo en segundo plano (PID: $(cat $PIDFILE))"
    exit 1
  else
    echo "🗑️ Eliminando archivo PID obsoleto."
    rm "$PIDFILE"
  fi
fi

echo $$ > "$PIDFILE"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOGFILE"
}

notify_user() {
  osascript -e 'display notification "Espacio crítico en disco. Ejecutando limpieza." with title "Disk Guard" sound name "Submarine"'
}

stop_icloud() {
  log "⛔ Deteniendo iCloud Drive"
  launchctl unload -w /System/Library/LaunchAgents/com.apple.bird.plist 2>/dev/null
  killall bird 2>/dev/null
}

clean_caches() {
  log "🧹 Limpieza de cachés iniciada"

  rm -rf ~/Library/Caches/com.apple.Safari/* 2>/dev/null
  rm -rf ~/Library/Safari/History.db 2>/dev/null
  rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null
  rm -rf ~/Library/Developer/Xcode/Archives/* 2>/dev/null
  rm -rf ~/Library/Caches/* 2>/dev/null
  qlmanage -r cache &>/dev/null
  sudo purge
}

check_disk_usage() {
  FREE_BYTES=$(df -k / | tail -1 | awk '{print $4 * 1024}')
  log "📊 Espacio libre actual: $((FREE_BYTES / 1024 / 1024)) MiB"

  if (( FREE_BYTES < THRESHOLD_BYTES )); then
    log "⚠️ Espacio bajo umbral. Ejecutando medidas."
    notify_user
    stop_icloud
    clean_caches
    log "✅ Limpieza completa."
  fi
}

# Bucle principal
log "🛡️ Disk Guard iniciado como daemon. Monitoreando espacio libre..."
while true; do
  check_disk_usage
  sleep $INTERVAL
done

