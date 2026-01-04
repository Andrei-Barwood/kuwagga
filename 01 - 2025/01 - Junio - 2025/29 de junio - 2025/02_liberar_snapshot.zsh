#!/bin/zsh
set -euo pipefail

# Script para liberar snapshots de actualización de macOS
# Requiere permisos de administrador

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOGFILE="$HOME/Public/liberar_snapshot_log_$TIMESTAMP.log"

# Verificar permisos de administrador
if [[ $EUID -ne 0 ]]; then
  echo "Error: Este script requiere permisos de administrador." >&2
  echo "Ejecuta con: sudo $0" >&2
  exit 1
fi

# Verificar dependencias
for cmd in mount tmutil; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "Error: $cmd no está disponible." >&2
    exit 1
  fi
done

echo "🧹 Eliminación automática de snapshot de actualización – $(date)" | tee "$LOGFILE"
echo "==============================================================" >> "$LOGFILE"

# Paso 1: Mostrar snapshot activa
echo "\n📋 Snapshot activa montada:" | tee -a "$LOGFILE"
/sbin/mount | grep "snapshot" | tee -a "$LOGFILE"

# Paso 2: Listar todas las snapshots locales
echo "\n🕰️ Snapshots locales en el volumen raíz:" | tee -a "$LOGFILE"
/usr/bin/tmutil listlocalsnapshots / | tee -a "$LOGFILE"

# Paso 3: Eliminar snapshots com.apple.os.update
echo "\n🔥 Eliminando snapshots de actualización com.apple.os.update..." | tee -a "$LOGFILE"
snapshots=$(tmutil listlocalsnapshots / 2>/dev/null | grep com.apple.os.update | awk -F. '{print $NF}' || echo "")
if [[ -z "$snapshots" ]]; then
  echo "✅ No se encontraron snapshots de actualización para eliminar." | tee -a "$LOGFILE"
else
  for snap in ${(f)snapshots}; do
    if [[ -n "$snap" ]]; then
      echo "➤ Eliminando snapshot: $snap" | tee -a "$LOGFILE"
      if /usr/bin/tmutil deletelocalsnapshots "$snap" >> "$LOGFILE" 2>&1; then
        echo "  ✓ Snapshot eliminado: $snap" | tee -a "$LOGFILE"
      else
        echo "  ✗ Error al eliminar snapshot: $snap" | tee -a "$LOGFILE"
      fi
    fi
  done
fi

# Paso 4: Verificar si el volumen aún está en modo read-only
echo "\n🔍 Verificando si el volumen sigue montado como solo lectura..." | tee -a "$LOGFILE"
/sbin/mount | grep " / " | tee -a "$LOGFILE"

# Final
echo "\n✅ Proceso terminado. Reinicia para aplicar los cambios." | tee -a "$LOGFILE"
echo "📄 Log guardado en: $LOGFILE"

