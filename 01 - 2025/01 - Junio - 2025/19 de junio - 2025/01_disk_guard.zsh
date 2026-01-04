#!/bin/zsh
set -euo pipefail

# Script para monitorear el espacio en disco y alertar cuando está bajo
# Umbral en bytes (87 GiB) - ajusta el valor 87 según tus necesidades
THRESHOLD_BYTES=$((87 * 1024 * 1024 * 1024))

# Intervalo entre chequeos (en segundos)
INTERVAL=10

# Verificar dependencias
for cmd in df awk lsof osascript; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "Error: $cmd no está instalado." >&2
    exit 1
  fi
done

# Función para obtener espacio libre
get_free_bytes() {
  df -k / 2>/dev/null | tail -1 | awk '{print $4 * 1024}' || echo "0"
}

# Función para formatear bytes
format_bytes() {
  local bytes=$1
  if (( bytes >= 1024 * 1024 * 1024 )); then
    printf "%.2f GiB" $(( bytes / 1024 / 1024 / 1024 ))
  elif (( bytes >= 1024 * 1024 )); then
    printf "%.2f MiB" $(( bytes / 1024 / 1024 ))
  else
    printf "%.2f KiB" $(( bytes / 1024 ))
  fi
}

check_disk_usage() {
  local free_bytes threshold_gib
  
  # Obtiene espacio libre en bytes
  free_bytes=$(get_free_bytes)
  threshold_gib=$((THRESHOLD_BYTES / 1024 / 1024 / 1024))
  
  if [[ -z "$free_bytes" || "$free_bytes" -eq 0 ]]; then
    echo "Error: No se pudo obtener información del disco" >&2
    return 1
  fi
  
  echo "Espacio libre actual: $(format_bytes "$free_bytes") (umbral: ${threshold_gib} GiB)"

  if (( free_bytes < THRESHOLD_BYTES )); then
    echo "⚠️  Espacio libre por debajo de ${threshold_gib} GiB. Tomando acciones..."
    
    # Lista los procesos que más escriben en disco (10 principales)
    echo "Procesos sospechosos por escritura en disco:"
    if sudo -n true 2>/dev/null; then
      sudo lsof -n 2>/dev/null | grep REG | awk '{print $1, $2, $7, $9}' | sort -k3 -n | tail -10 || echo "No se pudieron obtener procesos"
    else
      echo "Se requieren permisos de administrador para listar procesos"
    fi

    # Enviar notificación
    if command -v osascript &> /dev/null; then
      osascript -e "display notification \"Espacio en disco crítico: $(format_bytes "$free_bytes") libre\" with title \"Disk Guard\" sound name \"Submarine\"" 2>/dev/null || true
    fi
  fi
}

# Manejo de señales para salida limpia
cleanup() {
  echo ""
  echo "🛡️ Deteniendo monitoreo de disco..."
  exit 0
}

trap cleanup INT TERM

echo "🛡️ Iniciando monitoreo de disco. Umbral: $((THRESHOLD_BYTES / 1024 / 1024 / 1024)) GiB..."
echo "Presiona Ctrl+C para detener"
echo ""

while true; do
  check_disk_usage
  sleep "$INTERVAL"
done
