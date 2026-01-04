#!/bin/zsh
set -euo pipefail

# Script para limpiar archivos duplicados en el directorio Preboot
# ADVERTENCIA: Requiere permisos de administrador y puede afectar el sistema

PREBOOT_DIR="/System/Volumes/Preboot"
LOGFILE="$HOME/Desktop/limpieza_cryptex_$(date +%Y%m%d_%H%M%S).log"

# Verificar permisos de administrador
if [[ $EUID -ne 0 ]]; then
  echo "Error: Este script requiere permisos de administrador." >&2
  echo "Ejecuta con: sudo $0" >&2
  exit 1
fi

# Verificar que el directorio existe
if [[ ! -d "$PREBOOT_DIR" ]]; then
  echo "Error: El directorio Preboot no existe: $PREBOOT_DIR" >&2
  exit 1
fi

echo "🧼 Iniciando limpieza de duplicados en $PREBOOT_DIR" | tee "$LOGFILE"

# Buscar archivos duplicados por nombre en subcarpetas
print_duplicates() {
  find "$PREBOOT_DIR" -type f -size +500M -print0 | xargs -0 -n1 basename | sort | uniq -d
}

delete_duplicates() {
  local count=0
  for name in ${(f)1}; do
    matches=($(find "$PREBOOT_DIR" -type f -name "$name"))
    if (( ${#matches} > 1 )); then
      echo "\n🗑️ Encontrado duplicado: $name (${#matches} copias)" | tee -a "$LOGFILE"
      for (( i=1; i<${#matches[@]}; i++ )); do
        echo "   → Eliminando: ${matches[$i]}" | tee -a "$LOGFILE"
        sudo rm -f "${matches[$i]}"
        ((count++))
      done
    fi
  done
  echo "\n✅ Limpieza completa. Archivos eliminados: $count" | tee -a "$LOGFILE"
}

# Buscar duplicados
echo "\n🔍 Buscando duplicados grandes..." | tee -a "$LOGFILE"
DUPS=$(print_duplicates)

if [[ -z "$DUPS" ]]; then
  echo "✅ No se encontraron duplicados." | tee -a "$LOGFILE"
else
  echo "$DUPS" | tee -a "$LOGFILE"
  delete_duplicates "$DUPS"
fi

echo "\n🗂️ Log de limpieza guardado en: $LOGFILE"

