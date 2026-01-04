#!/bin/zsh
set -euo pipefail

# Auditor de Disco macOS - Análisis completo del uso de espacio
# Requiere permisos de administrador para algunas operaciones

LOGFILE="${HOME}/Desktop/auditoria_disco_$(date +%Y%m%d_%H%M%S).log"
DISCO="/"

# Verificar dependencias
for cmd in df du tmutil diskutil fs_usage find awk sort grep; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "Error: $cmd no está disponible." >&2
    exit 1
  fi
done

# Verificar permisos de administrador para operaciones que lo requieren
if [[ $EUID -ne 0 ]]; then
  echo "Advertencia: Algunas operaciones requieren permisos de administrador." >&2
  echo "El script solicitará sudo cuando sea necesario." >&2
fi

echo "📋 Iniciando auditoría de disco: $DISCO" | tee -a "$LOGFILE"
echo "🕒 Fecha: $(date)" | tee -a "$LOGFILE"
echo "🔍 Guardando resultados en: $LOGFILE"
echo "---------------------------------------------" | tee -a "$LOGFILE"

# Espacio libre real
echo "\n📊 Espacio disponible reportado:" | tee -a "$LOGFILE"
df -h "$DISCO" | tee -a "$LOGFILE"

# Uso por carpetas principales
echo "\n📁 Uso por carpetas del sistema y usuario (mayores a 500MB):" | tee -a "$LOGFILE"
sudo du -sh /System /Library /private /Users/* 2>/dev/null | sort -hr | awk '$1 ~ /G|M/ && $1+0 > 500' | tee -a "$LOGFILE"

# Snapshots locales (Time Machine)
echo "\n📸 Snapshots locales de Time Machine:" | tee -a "$LOGFILE"
tmutil listlocalsnapshots / | tee -a "$LOGFILE"

# Tamaño total de snapshots (si existen)
echo "\n📦 Estimación de uso de snapshots ocultos (dentro de /Volumes/Macintosh HD - Data/.DocumentRevisions-V100 o /.MobileBackups):" | tee -a "$LOGFILE"
sudo du -sh /.MobileBackups* /System/Volumes/Data/.DocumentRevisions-V100 2>/dev/null | tee -a "$LOGFILE"

# Procesos que están escribiendo al disco (top 10)
echo "\n🚨 Procesos escribiendo al disco (fs_usage muestra actividad por segundos):" | tee -a "$LOGFILE"
sudo fs_usage -w -f filesys 2>/dev/null | grep -v CACHE_HIT | head -n 30 | tee -a "$LOGFILE"

# Archivos grandes (+500 MB) en todo el sistema (puede tardar)
echo "\n🔎 Archivos mayores a 500 MB en el sistema:" | tee -a "$LOGFILE"
sudo find / -type f -size +500M -exec ls -lh {} \; 2>/dev/null | awk '{ print $9 ": " $5 }' | tee -a "$LOGFILE"

# Estado S.M.A.R.T. del disco
echo "\n🧠 Estado S.M.A.R.T. del disco:" | tee -a "$LOGFILE"
diskutil info / | grep -i "SMART" | tee -a "$LOGFILE"

# Conclusión
echo "\n✅ Auditoría completada. Log generado: $LOGFILE" | tee -a "$LOGFILE"

