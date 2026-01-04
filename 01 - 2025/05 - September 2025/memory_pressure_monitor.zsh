#!/bin/zsh
set -euo pipefail

# Script para monitorear la presión de memoria en macOS
# Envía notificaciones cuando la memoria libre cae por debajo del umbral

# Set memory threshold (percentage)
THRESHOLD=20  # Alert when free memory drops below 20%

# Verificar que memory_pressure esté disponible
if ! command -v memory_pressure &> /dev/null; then
  echo "Error: memory_pressure no está disponible en este sistema." >&2
  exit 1
fi

# Function to send notification
send_notification() {
    local title="$1"
    local message="$2"
    if command -v osascript &> /dev/null; then
      osascript -e "display notification \"$message\" with title \"$title\" sound name \"Ping\"" 2>/dev/null || true
    fi
}

# Get memory pressure information
memory_info=$(memory_pressure 2>/dev/null || echo "")
if [[ -n "$memory_info" ]]; then
    # Extract free memory percentage
    free_percentage=$(echo "$memory_info" | grep "System-wide memory free percentage" | grep -o '[0-9]\+' || echo "")
    
    if [[ -n "$free_percentage" && "$free_percentage" -lt "$THRESHOLD" ]]; then
        send_notification "Low Memory Warning" "Free memory: ${free_percentage}% (below ${THRESHOLD}% threshold)"
        log_file=~/memory_alerts.log
        echo "$(date '+%Y-%m-%d %H:%M:%S'): Low memory detected - ${free_percentage}% free" >> "$log_file"
        echo "Warning: Low memory detected - ${free_percentage}% free (threshold: ${THRESHOLD}%)"
    else
        echo "Memory OK: ${free_percentage:-N/A}% free (threshold: ${THRESHOLD}%)"
    fi
else
    echo "Error: No se pudo obtener información de memoria" >&2
    exit 1
fi
