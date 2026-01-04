#!/bin/zsh
set -euo pipefail

# Script para encontrar y eliminar archivos duplicados
# Requiere: shasum, bc (para cálculos de tamaño)

# Verificar dependencias
for cmd in shasum bc; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "Error: $cmd no está instalado." >&2
    echo "Instálalo con: brew install $cmd" >&2
    exit 1
  fi
done

SEARCH_DIR="${1:-$HOME}"

# Validar directorio de búsqueda
if [[ ! -d "$SEARCH_DIR" ]]; then
  echo "Error: El directorio no existe: $SEARCH_DIR" >&2
  exit 1
fi

extensions=(
  "aif" "caf" "wav" "mp3" "mov" "mp4" "m4a" "flac" "bwf" "logicx" "fcpbundle" "fcpxml" "midi" "proj" "xml"
  "jpg" "jpeg" "png" "gif" "tiff" "bmp" "heic" "webp" "raw" "cr2" "nef" "dng"
)
tmpfile=$(mktemp)
dupfile=$(mktemp)
trap "rm -f $tmpfile $dupfile" EXIT

print_header() {
    echo "🖼️🎞️ BUSCADOR DE ARCHIVOS DUPLICADOS (MULTIMEDIA + IMAGEN) 🎧📷"
    echo "Buscando duplicados en: $SEARCH_DIR"
    echo "------------------------------------------------------------"
}

draw_progress_bar() {
    local progress=$1
    local total=$2
    local percent=$(( progress * 100 / total ))
    local bar_length=40
    local filled=$(( percent * bar_length / 100 ))
    local empty=$(( bar_length - filled ))
    local bar="["
    bar+=$(printf "%0.s#" $(seq 1 $filled))
    bar+=$(printf "%0.s-" $(seq 1 $empty))
    bar+="]"
    echo -ne "\r🔍 Procesando archivos: $bar $percent%"
}

should_exclude() {
    local path="$1"
    [[ "$path" == *"/System/"* ]] ||
    [[ "$path" == *"/Library/"* ]] ||
    [[ "$path" == *"/Applications/"* ]] ||
    [[ "$path" == *"/Backups.backupdb/"* ]] ||
    [[ "$path" == *"/.Trash/"* ]] ||
    [[ "$path" == *"/Volumes/"* ]] ||
    [[ "$path" == *"/private/"* ]] ||
    [[ "$path" == "$HOME/Library/"* ]]
}

find_duplicates() {
    print_header
    echo ""
    echo "📂 Escaneando archivos..."

    file_list=()
    for ext in $extensions; do
        while IFS= read -r file; do
            if ! should_exclude "$file"; then
                file_list+=("$file")
            fi
        done < <(find "$SEARCH_DIR" -type f -iname "*.${ext}" 2>/dev/null)
    done

    total_files=${#file_list[@]}
    processed=0

    echo ""
    for file in "${file_list[@]}"; do
        hash=$(shasum "$file" | awk '{print $1}')
        echo "$hash $file" >> "$tmpfile"
        ((processed++))
        draw_progress_bar $processed $total_files
    done
    echo -e "\n✅ Escaneo completado."

    echo ""
    echo "🔎 Agrupando duplicados..."

    sort "$tmpfile" | awk -F '\t' '
    {
        hash=$1
        file=$2
        gsub(/^ +/, "", file)
        group[hash] = group[hash] ? group[hash] "\n" file : file
        count[hash]++
    }
    END {
        for (h in count) {
            if (count[h] > 1) {
                print "HASH:" h
                print group[h]
                print "===="
            }
        }
    }' > "$dupfile"

    echo "🔁 Procesando duplicados interactivos..."

    current_group=()
    hash_actual=""
    while IFS= read -r line; do
        if [[ "$line" == HASH:* ]]; then
            hash_actual="$line"
            current_group=()
        elif [[ "$line" == "====" ]]; then
            if (( ${#current_group[@]} > 1 )); then
                archivo="${current_group[0]}"
                base_name=$(basename "$archivo")
                hash_short=$(echo "$hash_actual" | cut -c6-13)

                sizes=()
                all_same_size=true

                for f in "${current_group[@]}"; do
                    if [[ -f "$f" ]]; then
                        size=$(stat -f%z "$f" 2>/dev/null)
                        if [[ -z "$size" || "$size" -eq 0 ]]; then
                            size=$(du -k "$f" | awk '{print $1}')
                            size=$((size * 1024))
                        fi
                        sizes+=("$size")
                    else
                        sizes+=("0")
                    fi
                done

                ref_size="${sizes[1]}"
                for s in "${sizes[@]}"; do
                    if [[ "$s" != "$ref_size" ]]; then
                        all_same_size=false
                        break
                    fi
                done

                echo ""
                echo "🔁 ${#current_group[@]} duplicados encontrados:"
                echo "📄 Archivo: $base_name"
                echo "🧬 Hash: $hash_short"

                if $all_same_size; then
                    size_mb=$(printf "%.1f" "$(echo "$ref_size / 1048576" | bc -l)")
                    echo "📦 Tamaño (todos iguales): $size_mb MB"
                else
                    echo "⚠️ Los archivos tienen diferentes tamaños:"
                    for i in "${!current_group[@]}"; do
                        file_name=$(basename "${current_group[$i]}")
                        size_i="${sizes[$i]}"
                        size_mb=$(printf "%.1f" "$(echo "$size_i / 1048576" | bc -l)")
                        echo "   📄 $file_name → $size_mb MB"
                    done
                fi

                for f in "${current_group[@]}"; do echo "$f"; done
                echo -n "¿Eliminar todos menos uno? (y/n): " > /dev/tty
                read -r confirm < /dev/tty
                if [[ "$confirm" == "y" ]]; then
                    for ((i=1; i<${#current_group[@]}; i++)); do
                        echo "🗑️ Moviendo a Papelera: ${current_group[$i]}"
                        mv "${current_group[$i]}" ~/.Trash/
                    done
                fi
            fi
        else
            current_group+=("$line")
        fi
    done < "$dupfile"
}

find_duplicates
