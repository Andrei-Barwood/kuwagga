#!/bin/zsh

# Script para convertir FLAC a MP4 con metadatos e imagen - Versión Verbosa

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # Sin color

# Función para mostrar barra de progreso
show_progress() {
    local current=$1
    local total=$2
    local width=40
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r${CYAN}["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] ${MAGENTA}%3d%%${NC} (${BLUE}%d${NC}/${BLUE}%d${NC})" "$percentage" "$current" "$total"
}

# Función para mostrar banner
show_banner() {
    clear
    echo "${MAGENTA}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║                                                      ║"
    echo "║          🎵 FLAC → MP4 CONVERTER v1.0 🎵           ║"
    echo "║          High Resolution Audio to Video             ║"
    echo "║                                                      ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo "${NC}"
}

# Función de log verboso
log_verbose() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%H:%M:%S')
    
    case $level in
        "INFO")
            echo "${BLUE}[${timestamp}]${NC} ℹ️  ${message}"
            ;;
        "SUCCESS")
            echo "${GREEN}[${timestamp}]${NC} ✅ ${message}"
            ;;
        "WARNING")
            echo "${YELLOW}[${timestamp}]${NC} ⚠️  ${message}"
            ;;
        "ERROR")
            echo "${RED}[${timestamp}]${NC} ❌ ${message}"
            ;;
        "DEBUG")
            echo "${CYAN}[${timestamp}]${NC} 🔧 ${message}"
            ;;
    esac
}

# Mostrar banner
show_banner

# Solicitar ruta de la carpeta
echo "${YELLOW}┌────────────────────────────────────────────────────┐${NC}"
echo "${YELLOW}│${NC} Pega la ruta de la carpeta con archivos FLAC:  ${YELLOW}│${NC}"
echo "${YELLOW}└────────────────────────────────────────────────────┘${NC}"
read -r FOLDER_PATH

# NO escaper la ruta - zsh la lee correctamente entre comillas
log_verbose "INFO" "Validando ruta: $FOLDER_PATH"

# Validar que la carpeta existe
if [[ ! -d "$FOLDER_PATH" ]]; then
    log_verbose "ERROR" "La carpeta no existe"
    log_verbose "DEBUG" "Ruta recibida: '$FOLDER_PATH'"
    exit 1
fi

# Crear carpeta de salida
OUTPUT_FOLDER="$FOLDER_PATH/MP4_Output"
mkdir -p "$OUTPUT_FOLDER"
log_verbose "SUCCESS" "Carpeta de salida creada: $OUTPUT_FOLDER"

echo ""
echo "${MAGENTA}╔══════════════════════════════════════════════════════╗${NC}"
echo "${MAGENTA}║${NC}                 📊 ANÁLISIS PREVIO                 ${MAGENTA}║${NC}"
echo "${MAGENTA}╚══════════════════════════════════════════════════════╝${NC}"

# Contar archivos FLAC
total=$(ls "$FOLDER_PATH"/*.flac 2>/dev/null | wc -l)

if [[ $total -eq 0 ]]; then
    log_verbose "ERROR" "No se encontraron archivos FLAC en la carpeta"
    exit 1
fi

log_verbose "INFO" "Se encontraron ${BLUE}$total${NC} archivos FLAC"
log_verbose "DEBUG" "Ruta origen: ${BLUE}$FOLDER_PATH${NC}"
log_verbose "DEBUG" "Ruta destino: ${BLUE}$OUTPUT_FOLDER${NC}"

# Mostrar lista de archivos a convertir
echo ""
echo "${CYAN}📁 Archivos a procesar:${NC}"
local_count=1
for flac_file in "$FOLDER_PATH"/*.flac; do
    filename=$(basename "$flac_file")
    echo "  ${BLUE}$local_count.${NC} $filename"
    ((local_count++))
done

echo ""
echo "${YELLOW}¿Deseas continuar con la conversión? (s/n)${NC}"
read -r confirm
if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
    log_verbose "WARNING" "Conversión cancelada por el usuario"
    exit 0
fi

echo ""
echo "${MAGENTA}╔══════════════════════════════════════════════════════╗${NC}"
echo "${MAGENTA}║${NC}              🎬 INICIANDO CONVERSIÓN               ${MAGENTA}║${NC}"
echo "${MAGENTA}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# Contadores
converted=0
failed=0
current=0

# Iterar sobre archivos FLAC
for flac_file in "$FOLDER_PATH"/*.flac; do
    ((current++))
    
    # Obtener nombre base sin extensión
    filename=$(basename "$flac_file" .flac)
    output_file="$OUTPUT_FOLDER/${filename}.mp4"
    
    # Mostrar progreso
    show_progress "$current" "$total"
    
    # Extraer información del archivo FLAC
    log_verbose "DEBUG" "Extrayendo metadatos de: $filename"
    
    # Extraer artwork (si existe)
    artwork_file="/tmp/${filename}_artwork.png"
    ffmpeg -i "$flac_file" -an -vcodec copy "$artwork_file" 2>/dev/null
    
    # Comando principal para conversión
    if [[ -f "$artwork_file" ]]; then
        log_verbose "DEBUG" "Artwork encontrado, procesando con imagen embebida"
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
        log_verbose "DEBUG" "Sin artwork, generando imagen negra estática"
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
        file_size=$(du -h "$output_file" | cut -f1)
        log_verbose "SUCCESS" "$filename → ${BLUE}${file_size}${NC}"
    else
        ((failed++))
        log_verbose "ERROR" "No se pudo convertir: $filename"
    fi
done

echo ""
echo ""
echo "${MAGENTA}╔══════════════════════════════════════════════════════╗${NC}"
echo "${MAGENTA}║${NC}              📈 RESUMEN DE CONVERSIÓN              ${MAGENTA}║${NC}"
echo "${MAGENTA}╚══════════════════════════════════════════════════════╝${NC}"

echo ""
echo "${CYAN}Total procesados:${NC}  ${BLUE}$total${NC}"
echo "${GREEN}✅ Exitosos:${NC}       ${GREEN}$converted${NC}"
echo "${RED}❌ Fallidos:${NC}        ${RED}$failed${NC}"
echo ""

# Mostrar espacio utilizado
output_size=$(du -sh "$OUTPUT_FOLDER" | cut -f1)
echo "${CYAN}📊 Tamaño total de salida:${NC} ${BLUE}$output_size${NC}"
echo "${CYAN}📁 Ubicación:${NC} ${BLUE}$OUTPUT_FOLDER${NC}"

if [[ $failed -eq 0 ]]; then
    echo ""
    echo "${GREEN}🎉 ¡Conversión completada exitosamente!${NC}"
else
    echo ""
    echo "${YELLOW}⚠️  Se completó con algunos errores${NC}"
fi

echo ""
echo "${MAGENTA}╔══════════════════════════════════════════════════════╗${NC}"
echo "${MAGENTA}╚══════════════════════════════════════════════════════╝${NC}"
