#!/bin/zsh

# Umbral en bytes (87 GiB) en la siguiente linea remplaza el valor 87 por un valor razonable de disco libre que debieras tener disponible
THRESHOLD_BYTES=$((87 * 1024 * 1024 * 1024))

# Intervalo entre chequeos (en segundos)
INTERVAL=10

check_disk_usage() {
  # Obtiene espacio libre en bytes
  FREE_BYTES=$(df -k / | tail -1 | awk '{print $4 * 1024}')
  
  echo "Espacio libre actual: $((FREE_BYTES / 1024 / 1024)) MiB"

  if (( FREE_BYTES < THRESHOLD_BYTES )); then
    echo "⚠️  Espacio libre por debajo de 87 GiB. Tomando acciones..."
    
    # Lista los procesos que más escriben en disco (10 principales)
    echo "Procesos sospechosos por escritura en disco:"
    sudo lsof -n | grep REG | awk '{print $1, $2, $7, $9}' | sort -k3 -n | tail -10

    # Opcional: Matar procesos sospechosos manualmente
    # Ejemplo para cerrar Dropbox o Safari (quita comentario si quieres usar):
    # pkill -f "Dropbox"
    # pkill -f "Safari"

    # También puedes enviar notificación
    osascript -e 'display notification "Espacio en disco crítico" with title "Disk Guard" sound name "Submarine"'

  fi
}

echo "🛡️ Iniciando monitoreo de disco. Umbral: 87 GiB..."
while true; do
  check_disk_usage
  sleep $INTERVAL
done

