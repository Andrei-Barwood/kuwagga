#!/bin/zsh
set -euo pipefail

# Script corregido - Limpia comillas de Finder automáticamente
# Convierte archivos M4A a MP3 con preservación de metadatos y carátulas

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

error() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

info() {
    echo -e "${GREEN}✓ $1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Verificar ffmpeg
command -v ffmpeg &> /dev/null || error "ffmpeg no está instalado: brew install ffmpeg"

echo "Ingresa la ruta del directorio con archivos M4A (copia desde Finder):"
read -r directorio

# LIMPIEZA AUTOMÁTICA: Remover comillas de Finder con (Q)
directorio="${(Q)directorio}"

# Trim espacios leading/trailing
directorio="${directorio#[[:space:]]#}"
directorio="${directorio%%[[:space:]]#}"

echo "Ruta limpia: $directorio"

[[ -d "$directorio" ]] || error "El directorio '$directorio' no existe"

output_dir="${directorio}/MP3_Convertidos"
mkdir -p "$output_dir" || error "No se pudo crear: $output_dir"

m4a_files=()
while IFS= read -r file; do
    m4a_files+=("$file")
done < <(find "$directorio" -name "*.m4a" -type f 2>/dev/null)

[[ ${#m4a_files[@]} -eq 0 ]] && error "No hay archivos M4A en '$directorio'"

info "Encontrados ${#m4a_files[@]} archivos M4A"
info "Salida: $output_dir"
echo

total=${#m4a_files[@]}
actual=0

for m4a_file in "${m4a_files[@]}"; do
    ((actual++))
    filename=$(basename "${m4a_file}" .m4a)
    mp3_file="${output_dir}/${filename}.mp3"
    
    echo "[$actual/$total] ${filename}"
    
    if ffmpeg -i "${m4a_file}" -q:a 2 -map_metadata 0 -id3v2_version 3 -write_id3v1 1 "${mp3_file}" -y -hide_banner -loglevel error 2>&1; then
        if [[ -f "${mp3_file}" && -s "${mp3_file}" ]]; then
        info "✓ ${filename}.mp3 creado"
        
        # Carátula
        temp_cover="/tmp/cover_$$_${actual}.jpg"
        ffmpeg -i "${m4a_file}" -an -vcodec copy "${temp_cover}" 2>/dev/null
        if [[ -s "${temp_cover}" ]]; then
            ffmpeg -i "${mp3_file}" -i "${temp_cover}" -c copy -map 0:0 -map 1:0 \
                -id3v2_version 3 -metadata:s:v title="Album cover" "${mp3_file}.tmp"
            [[ $? -eq 0 ]] && mv "${mp3_file}.tmp" "${mp3_file}"
            rm -f "${temp_cover}"
            info "  Carátula agregada"
        fi
        else
            warn "✗ Archivo MP3 creado pero está vacío: ${filename}"
        fi
    else
        warn "✗ Falló la conversión: ${filename}"
    fi
    echo
done

echo -e "${GREEN}═══════════════════════════════════════${NC}"
info "Completado. Archivos en: $output_dir ($(ls "$output_dir" | wc -l) MP3s)"
echo -e "${GREEN}═══════════════════════════════════════${NC}"

