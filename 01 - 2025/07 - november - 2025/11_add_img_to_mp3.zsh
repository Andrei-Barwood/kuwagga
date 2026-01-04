#!/usr/bin/env zsh
set -euo pipefail

# Script para agregar imágenes de portada a archivos MP3
# Requiere: eyeD3 (instalar con: brew install eye-d3)

setopt null_glob

# Verificar dependencias
if ! command -v eyeD3 &> /dev/null; then
    echo "Error: eyeD3 no está instalado." >&2
    echo "Instálalo con: brew install eye-d3" >&2
    echo "O con pip: pip install eyeD3" >&2
    exit 1
fi

# 0. Pedir ruta al usuario (pegada desde Finder)
echo "Pega la RUTA del directorio (copiada desde Finder con 'Copiar como nombre de ruta') y pulsa Enter:"
read -r dir_path_raw

# El flag (Q) de zsh quita comillas exteriores y backslashes de escape
dir_path=${(Q)dir_path_raw}

# Si el usuario no escribe nada, usar el directorio actual
if [[ -z "$dir_path" ]]; then
  dir_path=$PWD
fi

if [[ ! -d "$dir_path" ]]; then
  echo "La ruta no es un directorio válido: $dir_path"
  exit 1
fi

cd "$dir_path" || {
  echo "No se pudo entrar en el directorio: $dir_path"
  exit 1
}

echo "Trabajando en el directorio: $PWD"
echo

# 1. Buscar una imagen JPG primero, si no, PNG
artwork=""

jpg_candidates=(*.jpg *.jpeg *.JPG *.JPEG)
png_candidates=(*.png *.PNG)

if (( ${#jpg_candidates} > 0 )); then
  artwork=${jpg_candidates[1]}
elif (( ${#png_candidates} > 0 )); then
  artwork=${png_candidates[1]}
fi

if [[ -z "$artwork" ]]; then
  echo "No se encontró ninguna imagen JPG/PNG en el directorio actual."
  exit 1
fi

echo "Usando imagen: $artwork"
echo

# 2. Aplicar la portada a todos los MP3 del directorio
mp3_files=(*.mp3)

if (( ${#mp3_files} == 0 )); then
  echo "No se encontraron archivos MP3 en este directorio."
  exit 0
fi

success_count=0
failed_count=0

for mp3 in "${mp3_files[@]}"; do
  echo "Añadiendo portada a: $mp3"
  if eyeD3 --add-image "${artwork}:FRONT_COVER:" "$mp3" 2>/dev/null; then
    echo "  ✓ Portada agregada exitosamente"
    ((success_count++))
  else
    echo "  ✗ Error al agregar portada" >&2
    ((failed_count++))
  fi
done

echo
if [[ $failed_count -eq 0 ]]; then
  echo "✓ Proceso completado exitosamente. $success_count archivos procesados."
else
  echo "⚠️  Proceso completado con errores: $success_count exitosos, $failed_count fallidos." >&2
  exit 1
fi
