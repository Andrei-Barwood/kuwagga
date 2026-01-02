#!/bin/zsh

LOGFILE="$HOME/Public/vigia_escritura_fisica_$(date +%Y%m%d_%H%M%S).log"
DURACION=600  # 10 minutos = 600 segundos

echo "📡 Monitoreando escritura física al disco por $DURACION segundos..." | tee "$LOGFILE"

sudo fs_usage -w -f filesys 2>/dev/null | grep --line-buffered "WRITING" | tee -a "$LOGFILE" &
PID=$!

sleep $DURACION

echo "\n🛑 Finalizando monitoreo..." | tee -a "$LOGFILE"
kill $PID

