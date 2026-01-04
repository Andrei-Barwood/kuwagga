#!/bin/zsh
set -euo pipefail

# Vigía de Escritura Física - Monitorea escrituras al disco
# Requiere permisos de administrador y Full Disk Access

LOGFILE="${HOME}/Public/vigia_escritura_fisica_$(date +%Y%m%d_%H%M%S).log"
DURACION=600  # 10 minutos = 600 segundos

# Verificar dependencias
for cmd in fs_usage grep tee; do
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

# Crear directorio si no existe
mkdir -p "$(dirname "$LOGFILE")" 2>/dev/null || true

echo "📡 Monitoreando escritura física al disco por $DURACION segundos..." | tee "$LOGFILE"

# Capturar PID del proceso en background
PID=""
trap '[[ -n "$PID" ]] && kill "$PID" 2>/dev/null || true' EXIT INT TERM

sudo fs_usage -w -f filesys 2>/dev/null | grep --line-buffered "WRITING" | tee -a "$LOGFILE" &
PID=$!

sleep "$DURACION"

echo "\n🛑 Finalizando monitoreo..." | tee -a "$LOGFILE"
[[ -n "$PID" ]] && kill "$PID" 2>/dev/null || true
wait "$PID" 2>/dev/null || true

