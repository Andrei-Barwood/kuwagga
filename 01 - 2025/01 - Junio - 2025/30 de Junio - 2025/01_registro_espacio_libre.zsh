#!/bin/zsh
set -euo pipefail

# Registro de Espacio Libre - Registra el espacio disponible diariamente
# Archivo log (en carpeta Pública)

LOGFILE="${HOME}/Public/espacio_disco_$(date +%Y%m%d).log"

# Verificar dependencias
if ! command -v df &> /dev/null; then
  echo "Error: df no está disponible." >&2
  exit 1
fi

# Crear directorio si no existe
mkdir -p "$(dirname "$LOGFILE")" 2>/dev/null || true

# Obtener espacio disponible actual
timestamp=$(date "+%Y-%m-%d %H:%M:%S")
disk_info=$(df -h / | tail -1 | awk '{print $4}')
used_info=$(df -h / | tail -1 | awk '{print $3}')

# Registrar en el log
echo "$timestamp - Disponible: $disk_info - Usado: $used_info" >> "$LOGFILE"

# Mostrar resultado en consola
echo "📊 Registro actualizado: $timestamp"
echo "💾 Espacio disponible: $disk_info"
echo "📄 Log diario: $LOGFILE"

