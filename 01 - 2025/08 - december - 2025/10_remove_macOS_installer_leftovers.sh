#!/bin/zsh
set -euo pipefail

# Script para eliminar archivos residuales del instalador de macOS
# Típicamente libera 5-15GB de espacio
# Requiere permisos de administrador

LOG="/tmp/cleanup_installer_data_$(date +%Y%m%d_%H%M%S).log"

log() { print -r -- "[$(date '+%F %T')] $*" | tee -a "$LOG"; }

if [[ $EUID -ne 0 ]]; then
  echo "Este script requiere permisos de administrador." >&2
  echo "Ejecuta con: sudo $0" >&2
  exit 1
fi

# Verificar dependencias
for cmd in du df rm; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "Error: $cmd no está disponible." >&2
    exit 1
  fi
done

INSTALL_DATA="/System/Volumes/Data/macOS Install Data"

log "Buscando archivos residuales del instalador de macOS..."

if [[ -d "$INSTALL_DATA" ]]; then
  size=$(du -sh "$INSTALL_DATA" 2>/dev/null | awk '{print $1}' || echo "desconocido")
  log "Encontrado directorio: $INSTALL_DATA"
  log "Tamaño: $size"
  log "Eliminando..."
  if sudo rm -rf "$INSTALL_DATA" 2>&1; then
    log "✓ Eliminado exitosamente"
  else
    log "✗ Error al eliminar (puede requerir reinicio o permisos adicionales)"
    exit 1
  fi
else
  log "No se encontró el directorio: $INSTALL_DATA"
  log "Puede que ya haya sido eliminado o no exista en este sistema"
fi

log "Espacio libre actual:"
df -H / | tee -a "$LOG"

log "Proceso completado. Log guardado en: $LOG"