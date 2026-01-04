#!/bin/zsh
set -euo pipefail

# Rastreador de Cambios en Disco - Monitorea cambios de tamaño en rutas específicas
# Requiere permisos de administrador para algunas rutas

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BASE_LOG="${HOME}/Public/rastreador_espacio_${TIMESTAMP}.log"
INTERVAL=60  # Intervalo en segundos entre chequeos
CICLOS=30    # Cuántas veces observar (30 ciclos de 60s = 30 minutos)

# Verificar dependencias
for cmd in du date; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "Error: $cmd no está disponible." >&2
    exit 1
  fi
done

# Crear directorio si no existe
mkdir -p "$(dirname "$BASE_LOG")" 2>/dev/null || true

# Rutas que vamos a monitorear
RUTAS=(
  "/private/var"
  "/System/Volumes/VM"
  "/Users"
  "/Library/Logs"
  "/Library/Caches"
)

echo "📡 Iniciando rastreo a $(date)" | tee "$BASE_LOG"

for ((i = 1; i <= CICLOS; i++)); do
  echo "\n🕐 $(date)" | tee -a "$BASE_LOG"
  for ruta in "${RUTAS[@]}"; do
    if [[ -d "$ruta" ]]; then
      tamano=$(sudo du -d 0 -h "$ruta" 2>/dev/null | cut -f1)
      echo "📂 $ruta: $tamano" | tee -a "$BASE_LOG"
    fi
  done
  sleep $INTERVAL
done

echo "\n✅ Rastreo finalizado a $(date)" | tee -a "$BASE_LOG"

