#!/bin/zsh
set -euo pipefail

# Script para recuperar archivos de la papelera usando fzf

# Verificar que fzf esté instalado
if ! command -v fzf &> /dev/null; then
  echo "Error: fzf no está instalado." >&2
  echo "Instálalo con: brew install fzf" >&2
  exit 1
fi

recovered_folder=~/Desktop/recovered
trash_folder=~/.Trash

# Verificar que la papelera existe
if [[ ! -d "$trash_folder" ]]; then
  echo "Error: La carpeta de papelera no existe: $trash_folder" >&2
  exit 1
fi

# Create recovered folder if does not exist
mkdir -p "$recovered_folder"

# List files in trash (including hidden) and pipe to fzf for interactive search
selected_files=$(find "$trash_folder" -mindepth 1 -maxdepth 1 2>/dev/null | fzf --multi --prompt="Search Trash: " || true)

if [[ -z "$selected_files" ]]; then
  echo "No files selected."
  exit 0
fi

# Move selected files to recovered folder
moved_count=0
while IFS= read -r file; do
  if [[ -n "$file" && -e "$file" ]]; then
    if mv "$file" "$recovered_folder" 2>/dev/null; then
      ((moved_count++))
    else
      echo "Warning: No se pudo mover: $file" >&2
    fi
  fi
done <<< "$selected_files"

if [[ $moved_count -gt 0 ]]; then
  echo "Moved $moved_count file(s) to $recovered_folder"
else
  echo "No files were moved."
  exit 1
fi
