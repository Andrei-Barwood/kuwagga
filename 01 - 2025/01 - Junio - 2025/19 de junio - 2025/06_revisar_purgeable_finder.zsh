#!/bin/zsh
set -euo pipefail

# Script para revisar espacio purgeable y reiniciar Spotlight
# Requiere permisos de administrador para algunas operaciones

LOGFILE="$HOME/Desktop/informe_finder_$(date +%Y%m%d_%H%M%S).log"

# Verificar dependencias
for cmd in diskutil df mdutil du; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "Error: $cmd no está disponible." >&2
    exit 1
  fi
done

echo "📋 Iniciando auditoría Finder y espacio purgeable" | tee "$LOGFILE"
echo "🕒 Fecha: $(date)" | tee -a "$LOGFILE"
echo "---------------------------------------------" | tee -a "$LOGFILE"

# 1. Mostrar espacio libre, usado y purgeable
echo "\n📊 Espacio del sistema (diskutil):" | tee -a "$LOGFILE"
diskutil info / | grep -E 'Volume Free Space|Purgeable Space|Used Space' | tee -a "$LOGFILE"

# 2. Mostrar info detallada con df
echo "\n💾 Detalles de uso con df -h:" | tee -a "$LOGFILE"
df -h / | tee -a "$LOGFILE"

# 3. Carpetas ocultas que podrían estar ocupando espacio
echo "\n🕵️ Carpetas ocultas y su tamaño (mayores a 500MB):" | tee -a "$LOGFILE"
sudo find /System/Volumes/Data -type d -name ".*" -prune -exec du -sh {} + 2>/dev/null | awk '$1 ~ /G|M/ && $1+0 > 500' | tee -a "$LOGFILE"

# 4. Subcarpetas ocultas de /private
echo "\n📁 Revisando /private y subdirectorios ocultos:" | tee -a "$LOGFILE"
sudo du -sh /private/* 2>/dev/null | sort -hr | tee -a "$LOGFILE"

# 5. Reiniciar Spotlight y reindexar todo
echo "\n🔄 Reiniciando Spotlight (mds):" | tee -a "$LOGFILE"
sudo mdutil -i off /
sudo mdutil -E /
sudo mdutil -i on /
echo "✅ Spotlight reiniciado y reindexación forzada." | tee -a "$LOGFILE"

# 6. Final
echo "\n📂 Informe guardado en: $LOGFILE" | tee -a "$LOGFILE"

