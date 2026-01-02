#!/bin/zsh

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOGFILE="$HOME/Public/liberar_snapshot_log_$TIMESTAMP.log"

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
for snap in $(tmutil listlocalsnapshots / | grep com.apple.os.update | awk -F. '{print $NF}')
do
  echo "➤ Eliminando snapshot: $snap" | tee -a "$LOGFILE"
  sudo /usr/bin/tmutil deletelocalsnapshots "$snap" >> "$LOGFILE" 2>&1
done

# Paso 4: Verificar si el volumen aún está en modo read-only
echo "\n🔍 Verificando si el volumen sigue montado como solo lectura..." | tee -a "$LOGFILE"
/sbin/mount | grep " / " | tee -a "$LOGFILE"

# Final
echo "\n✅ Proceso terminado. Reinicia para aplicar los cambios." | tee -a "$LOGFILE"
echo "📄 Log guardado en: $LOGFILE"

