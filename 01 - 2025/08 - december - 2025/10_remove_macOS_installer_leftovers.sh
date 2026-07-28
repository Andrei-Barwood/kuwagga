#!/bin/zsh
set -euo pipefail

# Script para eliminar archivos residuales del instalador de macOS
# Típicamente libera 5-15GB de espacio
# Requiere permisos de administrador

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH"

# macOS often blocks writes to /tmp ("Operation not permitted") under TCC/sandbox.
# zsh here-docs/here-strings (<<<) use TMPPREFIX, which defaults to /tmp/zsh.
if [[ -z "${TMPDIR:-}" || ! -w "${TMPDIR}" ]]; then
  if command -v getconf >/dev/null 2>&1; then
    TMPDIR="$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null || true)"
  fi
fi
if [[ -z "${TMPDIR:-}" || ! -w "${TMPDIR}" ]]; then
  TMPDIR="${HOME}/Library/Caches"
  mkdir -p "${TMPDIR}" 2>/dev/null || TMPDIR="${HOME}"
fi
TMPDIR="${TMPDIR%/}"
export TMPDIR
export TMPPREFIX="${TMPDIR}/zsh"
mkdir -p "${TMPPREFIX}" 2>/dev/null || true

LOG="${TMPDIR}/cleanup_installer_data_$(date +%Y%m%d_%H%M%S).log"
if ! : >>"$LOG" 2>/dev/null; then
  LOG="${HOME}/cleanup_installer_data_$(date +%Y%m%d_%H%M%S).log"
  : >>"$LOG" || {
    print -r -- "No pude crear el log (TMPDIR=${TMPDIR} y HOME bloqueados)." >&2
    exit 1
  }
fi

log() { print -r -- "[$(date '+%F %T')] $*" | /usr/bin/tee -a "$LOG"; }

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