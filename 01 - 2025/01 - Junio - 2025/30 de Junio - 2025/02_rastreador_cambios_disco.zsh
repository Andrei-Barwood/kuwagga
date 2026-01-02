#!/bin/zsh

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BASE_LOG="$HOME/Public/rastreador_espacio_$TIMESTAMP.log"
INTERVAL=60  # Intervalo en segundos entre chequeos
CICLOS=30    # Cuántas veces observar (30 ciclos de 60s = 30 minutos)

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

