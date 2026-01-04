#!/bin/zsh
set -euo pipefail

# Memory monitoring script with Notification Center integration
# Envía notificaciones al Notification Center de macOS cuando la memoria es baja

THRESHOLD=20

# Verificar que memory_pressure esté disponible
if ! command -v memory_pressure &> /dev/null; then
  echo "Error: memory_pressure no está disponible en este sistema." >&2
  exit 1
fi

# Verificar que osascript esté disponible
if ! command -v osascript &> /dev/null; then
  echo "Error: osascript no está disponible." >&2
  exit 1
fi

check_memory() {
    local memory_info free_percentage
    
    memory_info=$(memory_pressure 2>/dev/null || echo "")
    if [[ -z "$memory_info" ]]; then
      echo "Error: No se pudo obtener información de memoria" >&2
      return 1
    fi
    
    free_percentage=$(echo "$memory_info" | grep "System-wide memory free percentage" | grep -o '[0-9]\+' || echo "")
    
    if [[ -n "$free_percentage" && "$free_percentage" -lt "$THRESHOLD" ]]; then
        osascript -e "display notification \"Free memory: ${free_percentage}% (below ${THRESHOLD}% threshold)\" with title \"Memory Alert\" subtitle \"Low Memory Warning\" sound name \"Ping\"" 2>/dev/null || true
        echo "Alert sent: Free memory is ${free_percentage}% (below ${THRESHOLD}% threshold)"
        return 0
    else
        echo "Memory OK: ${free_percentage:-N/A}% free (threshold: ${THRESHOLD}%)"
        return 0
    fi
}

check_memory
