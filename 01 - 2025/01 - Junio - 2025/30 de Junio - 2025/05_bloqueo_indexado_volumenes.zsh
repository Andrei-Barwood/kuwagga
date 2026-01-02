#!/bin/zsh

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG="$HOME/Public/bloqueo_indexado_volumenes_$TIMESTAMP.log"

echo "🛡️ Inicio de bloqueo automático de Spotlight para discos externos – $TIMESTAMP" | tee "$LOG"

# Detectar discos externos montados en /Volumes
for volumen in /Volumes/*; do
  if [[ -d "$volumen" && ! "$volumen" =~ "Macintosh HD" ]]; then
    echo "\n📀 Detectado: $volumen" | tee -a "$LOG"

    # Desactivar Spotlight para este volumen
    echo "⛔ Desactivando indexado..." | tee -a "$LOG"
    sudo mdutil -i off "$volumen" >> "$LOG" 2>&1

    # Borrar índices creados
    echo "🧹 Eliminando índices..." | tee -a "$LOG"
    sudo mdutil -E "$volumen" >> "$LOG" 2>&1

    # Verificar si ya está en la lista de privacidad
    PRIVACY_FILE="$volumen/.metadata_never_index"
    if [[ -f "$PRIVACY_FILE" ]]; then
      echo "✅ Ya bloqueado permanentemente." | tee -a "$LOG"
    else
      echo "🔒 Añadiendo bloqueo persistente..." | tee -a "$LOG"
	sudo touch "$PRIVACY_FILE"

	# Mostrar notificación visual
	osascript -e "display notification \"Spotlight ha sido bloqueado\" with title \"Volumen protegido: $(basename "$volumen")\""

    fi
  fi
done

echo "\n✅ Proceso completo. Log guardado en: $LOG"

