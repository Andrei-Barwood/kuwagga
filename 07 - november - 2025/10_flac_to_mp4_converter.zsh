#!/bin/zsh

# Script para convertir FLAC a MP4 con metadatos e imagen

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # Sin color

# Solicitar ruta de la carpeta
echo "${YELLOW}Pega la ruta de la carpeta con archivos FLAC desde Finder:${NC}"
read -r FOLDER_PATH

# Validar que la carpeta existe
if [[ ! -d "$FOLDER_PATH" ]]; then
    echo "${RED}Error: La carpeta no existe${NC}"
    exit 1
fi

# Crear carpeta de salida
OUTPUT_FOLDER="$FOLDER_PATH/MP4_Output"
mkdir -p "$OUTPUT_FOLDER"

echo "${GREEN}Iniciando conversión en: $FOLDER_PATH${NC}"
echo "${YELLOW}Archivos de salida en: $OUTPUT_FOLDER${NC}"

# Contador
total=0
converted=0
failed=0

# Iterar sobre archivos FLAC
for flac_file in "$FOLDER_PATH"/*.flac; do
    # Verificar si existe al menos un archivo .flac
    if [[ ! -e "$flac_file" ]]; then
        echo "${RED}No se encontraron archivos FLAC${NC}"
        exit 1
    fi
    
    ((total++))
    
    # Obtener nombre base sin extensión
    filename=$(basename "$flac_file" .flac)
    output_file="$OUTPUT_FOLDER/${filename}.mp4"
    
    echo "${YELLOW}Procesando: $filename${NC}"
    
    # Extraer artwork (si existe)
    artwork_file="/tmp/${filename}_artwork.png"
    ffmpeg -i "$flac_file" -an -vcodec copy "$artwork_file" 2>/dev/null
    
    # Comando principal para conversión
    if [[ -f "$artwork_file" ]]; then
        # Con artwork
        ffmpeg -i "$flac_file" \
            -i "$artwork_file" \
            -c:a aac \
            -b:a 320k \
            -c:v copy \
            -map 0:a:0 \
            -map 1:v:0 \
            -movflags +faststart \
            -metadata:s:v title="Album cover" \
            -metadata:s:v comment="Cover (front)" \
            "$output_file" -y 2>/dev/null
        
        rm -f "$artwork_file"
    else
        # Sin artwork - crear imagen negra estática
        ffmpeg -f lavfi -i color=c=black:s=1920x1080:d=0.1 \
            -i "$flac_file" \
            -c:v libx264 \
            -c:a aac \
            -b:a 320k \
            -shortest \
            -movflags +faststart \
            "$output_file" -y 2>/dev/null
    fi
    
    # Verificar si la conversión fue exitosa
    if [[ -f "$output_file" ]]; then
        ((converted++))
        echo "${GREEN}✓ Convertido: $filename${NC}"
    else
        ((failed++))
        echo "${RED}✗ Error en: $filename${NC}"
    fi
done

# Resumen
echo ""
echo "${GREEN}═══════════════════════════════════${NC}"
echo "Total procesados: $total"
echo "${GREEN}Exitosos: $converted${NC}"
echo "${RED}Fallidos: $failed${NC}"
echo "${GREEN}═══════════════════════════════════${NC}"
