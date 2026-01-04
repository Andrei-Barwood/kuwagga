#!/bin/zsh
set -euo pipefail

# Script para monitorear memoria con notificaciones avanzadas usando terminal-notifier
# Requiere: terminal-notifier (instalar con: brew install terminal-notifier)

THRESHOLD=20

# Verificar que terminal-notifier esté instalado
if ! command -v terminal-notifier &> /dev/null; then
  echo "Error: terminal-notifier no está instalado." >&2
  echo "Instálalo con: brew install terminal-notifier" >&2
  exit 1
fi

# Verificar que memory_pressure esté disponible
if ! command -v memory_pressure &> /dev/null; then
  echo "Error: memory_pressure no está disponible en este sistema." >&2
  exit 1
fi

send_advanced_notification() {
    local free_mem="$1"
    terminal-notifier \
        -title "Memory Alert" \
        -subtitle "System Memory Low" \
        -message "Available memory: ${free_mem}%" \
        -sound "Ping" \
        -appIcon "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns" \
        -group "memory-monitor" 2>/dev/null || true
}

# Obtener información de memoria
memory_info=$(memory_pressure 2>/dev/null || echo "")
if [[ -z "$memory_info" ]]; then
  echo "Error: No se pudo obtener información de memoria" >&2
  exit 1
fi

# Extraer porcentaje de memoria libre
free_percentage=$(echo "$memory_info" | grep "System-wide memory free percentage" | grep -o '[0-9]\+' || echo "")

if [[ -n "$free_percentage" && "$free_percentage" -lt "$THRESHOLD" ]]; then
    send_advanced_notification "$free_percentage"
    echo "Alert sent: Free memory is ${free_percentage}% (below ${THRESHOLD}% threshold)"
    exit 0
else
    echo "Memory OK: ${free_percentage:-N/A}% free (threshold: ${THRESHOLD}%)"
    exit 0
fi
