#!/bin/zsh

# Archivo log (en carpeta Pública)
LOGFILE="$HOME/Public/espacio_disco_$(date +%Y%m%d).log"

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

