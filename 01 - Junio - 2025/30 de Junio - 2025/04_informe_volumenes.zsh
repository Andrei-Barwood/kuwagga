#!/bin/zsh

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOGFILE="$HOME/Public/informe_volumenes_$TIMESTAMP.log"

echo "📦 Informe de volúmenes y uso de espacio – $TIMESTAMP" | tee "$LOGFILE"
echo "======================================================" >> "$LOGFILE"

# 1. Volúmenes APFS
echo "\n🔍 Volúmenes APFS:" | tee -a "$LOGFILE"
/usr/sbin/diskutil apfs list >> "$LOGFILE"

# 2. Puntos de montaje y uso de disco
echo "\n📂 Montajes actuales y uso general:" | tee -a "$LOGFILE"
/bin/df -h >> "$LOGFILE"

# 3. Uso por carpeta en /System/Volumes/Data
echo "\n📁 Uso de espacio en /System/Volumes/Data/* :" | tee -a "$LOGFILE"
sudo /usr/bin/du -sh /System/Volumes/Data/* 2>/dev/null | sort -hr >> "$LOGFILE"

# 4. Uso por carpeta en /private
echo "\n🗂️ Uso de espacio en /private/* :" | tee -a "$LOGFILE"
sudo /usr/bin/du -sh /private/* 2>/dev/null | sort -hr >> "$LOGFILE"

# 5. Final
echo "\n✅ Log generado en: $LOGFILE"

