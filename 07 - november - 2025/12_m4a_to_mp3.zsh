#!/bin/zsh

# Script para convertir M4A a MP3 - Versión corregida para espacios en nombres

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
command -v ffmpeg &> /dev/null || error "ffmpeg no está instalado. Instálalo con: brew install ffmpeg"

# Verificar permisos de ffmpeg
if [[ ! -x "$(command -v ffmpeg)" ]]; then
    warn "ffmpeg no tiene permisos de ejecución. Ejecuta: sudo chmod +x $(command -v ffmpeg)"
    exit 1
fi

echo "Ingresa la ruta del directorio con archivos M4A:"
read -r directorio

# IMPORTANTE: Usar comillas dobles para manejar espacios
[[ -d "$directorio" ]] || error "El directorio '$directorio' no existe"

# Crear directorio de salida
output_dir="${directorio}/MP3_Convertidos"
mkdir -p "$output_dir" || error "No se pudo crear el directorio de salida"

# Buscar archivos M4A con comillas apropiadas
m4a_files=()
while IFS= read -r file; do
    m4a_files+=("$file")
done < <(find "$directorio" -name "*.m4a" -type f 2>/dev/null)

if [[ ${#m4a_files[@]} -eq 0 ]]; then
    error "No se encontraron archivos .m4a en '$directorio'"
fi

info "Se encontraron ${#m4a_files[@]} archivo(s) M4A"
info "Los MP3 se guardarán en: $output_dir"
echo ""

total=${#m4a_files[@]}
actual=0

for m4a_file in "${m4a_files[@]}"; do
    ((actual++))
    
    filename=$(basename "$m4a_file" .m4a)
    mp3_file="${output_dir}/${filename}.mp3"
    
    echo "Procesando [$actual/$total]: ${filename}"
    echo "Archivo de entrada: ${m4a_file}"
    
    # CORRECCIÓN PRINCIPAL: Usar comillas para TODOS los parámetros
    ffmpeg -i "${m4a_file}" \
        -q:a 2 \
        -map_metadata 0 \
        -id3v2_version 3 \
        -write_id3v1 1 \
        "${mp3_file}" 2>&1
    
    if [[ $? -eq 0 && -f "${mp3_file}" ]]; then
        info "Convertido: ${filename}.mp3"
        
        # Copiar carátula
        temp_cover="/tmp/cover_$$_${actual}.jpg"
        ffmpeg -i "${m4a_file}" -an -vcodec copy "${temp_cover}" 2>/dev/null
        
        if [[ -s "${temp_cover}" ]]; then
            ffmpeg -i "${mp3_file}" -i "${temp_cover}" -c copy -map 0:0 -map 1:0 -id3v2_version 3 -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)" "${mp3_file}.tmp" 2>/dev/null
            [[ $? -eq 0 ]] && mv "${mp3_file}.tmp" "${mp3_file}"
            rm -f "${temp_cover}"
        fi
    else
        warn "Error al convertir: ${filename}"
        echo "Verifica que el archivo no esté protegido o dañado"
    fi
    
    echo ""
done

echo -e "${GREEN}═══════════════════════════════════════${NC}"
info "Conversión completada"
echo "Total de archivos procesados: $total"
echo "Ubicación de salida: $output_dir"
ls -la "$output_dir"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
