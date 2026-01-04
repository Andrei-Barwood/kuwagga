#!/bin/zsh
set -euo pipefail

# Disk Guard Plus - Monitoreo avanzado de espacio en disco
# Umbral en bytes (87 GiB)
THRESHOLD_BYTES=$((87 * 1024 * 1024 * 1024))
INTERVAL=30  # Intervalo de monitoreo (segundos)

# Verificar dependencias
for cmd in df osascript launchctl killall qlmanage; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "Error: $cmd no está disponible." >&2
    exit 1
  fi
done

check_disk_usage() {
  FREE_BYTES=$(df -k / | tail -1 | awk '{print $4 * 1024}')
  echo "💽 Espacio libre actual: $((FREE_BYTES / 1024 / 1024)) MiB"

  if (( FREE_BYTES < THRESHOLD_BYTES )); then
    echo "⚠️ Espacio libre por debajo de 87 GiB. Activando protocolo de limpieza..."
    
    notify_user
    stop_icloud
    clean_caches
    # clean_mail_and_messages  # Descomenta si lo necesitas

    echo "✅ Protocolo de emergencia ejecutado."
  fi
}

notify_user() {
  osascript -e 'display notification "Espacio crítico en disco. Ejecutando limpieza." with title "Disk Guard" sound name "Submarine"'
}

stop_icloud() {
  echo "📤 Desactivando iCloud Drive temporalmente..."
  launchctl unload -w /System/Library/LaunchAgents/com.apple.bird.plist 2>/dev/null
  killall bird 2>/dev/null
}

clean_caches() {
  echo "🧹 Limpiando cachés de usuario..."

  # Safari
  [[ -d ~/Library/Caches/com.apple.Safari ]] && rm -rf ~/Library/Caches/com.apple.Safari/* 2>/dev/null || true
  [[ -f ~/Library/Safari/History.db ]] && rm -rf ~/Library/Safari/History.db 2>/dev/null || true

  # Xcode (si está instalado)
  [[ -d ~/Library/Developer/Xcode/DerivedData ]] && rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null || true
  [[ -d ~/Library/Developer/Xcode/Archives ]] && rm -rf ~/Library/Developer/Xcode/Archives/* 2>/dev/null || true

  # System caches
  [[ -d ~/Library/Caches ]] && rm -rf ~/Library/Caches/* 2>/dev/null || true
  [[ -d /Library/Caches ]] && sudo rm -rf /Library/Caches/* 2>/dev/null || true

  # QuickLook
  qlmanage -r cache 2>/dev/null || true

  # Flush inactive memory (requiere sudo)
  if command -v sudo &> /dev/null; then
    sudo purge 2>/dev/null || true
  fi
}

clean_mail_and_messages() {
  echo "📧 Liberando caché de Mail y Mensajes (iMessage)..."

  rm -rf ~/Library/Containers/com.apple.mail/Data/Library/Caches/*
  rm -rf ~/Library/Messages/Attachments/*
  rm -rf ~/Library/Messages/Archive/*
}

# Inicio del monitoreo
echo "🛡️ Iniciando monitoreo de disco con limpieza automática..."
while true; do
  check_disk_usage
  sleep $INTERVAL
done

