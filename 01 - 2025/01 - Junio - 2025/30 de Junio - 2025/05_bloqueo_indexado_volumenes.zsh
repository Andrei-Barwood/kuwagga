#!/bin/zsh
set -euo pipefail

# Bloqueo de Indexado de Volúmenes - Desactiva Spotlight en discos externos
# Requiere permisos de administrador

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG="${HOME}/Public/bloqueo_indexado_volumenes_${TIMESTAMP}.log"

# Verificar dependencias
for cmd in mdutil osascript date; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "Error: $cmd no está disponible." >&2
    exit 1
  fi
done

# Verificar permisos de administrador
if [[ $EUID -ne 0 ]]; then
  echo "Advertencia: Este script requiere permisos de administrador." >&2
  echo "El script solicitará sudo cuando sea necesario." >&2
fi

# Crear directorio si no existe
mkdir -p "$(dirname "$LOG")" 2>/dev/null || true

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
    PRIVACY_FILE="${volumen}/.metadata_never_index"
    if [[ -f "$PRIVACY_FILE" ]]; then
      echo "✅ Ya bloqueado permanentemente." | tee -a "$LOG"
    else
      echo "🔒 Añadiendo bloqueo persistente..." | tee -a "$LOG"
      if sudo touch "$PRIVACY_FILE" 2>/dev/null; then
        # Mostrar notificación visual
        osascript -e "display notification \"Spotlight ha sido bloqueado\" with title \"Volumen protegido: $(basename "$volumen")\"" 2>/dev/null || true
      else
        echo "⚠️  No se pudo crear el archivo de bloqueo persistente." | tee -a "$LOG"
      fi
    fi
  fi
done

echo "\n✅ Proceso completo. Log guardado en: $LOG"

