#!/bin/zsh
# ============================================================================
# Audio/Video Conversion Script
# ============================================================================
# Convierte archivos de audio entre formatos:
#   - M4A → MP4 (video con imagen estática para YouTube)
#   - WAV → M4A (compresión AAC de alta calidad)
#   - FLAC → M4A (opcional)
#
# Uso:
#   ./06_m4a_to_mp4.zsh                    # Modo interactivo
#   ./06_m4a_to_mp4.zsh -h                 # Mostrar ayuda
#   ./06_m4a_to_mp4.zsh -f archivo.m4a     # Convertir archivo individual
#   ./06_m4a_to_mp4.zsh -o /ruta/origen    # Carpeta origen (sin ranger)
#   ./06_m4a_to_mp4.zsh -d /ruta/destino   # Carpeta destino
#   ./06_m4a_to_mp4.zsh --dry-run          # Simular sin convertir
#
# Requisitos:
#   - ffmpeg (requerido)
#   - ranger (opcional, para selección visual de carpeta)
# ============================================================================

set -o pipefail

# ============================================================================
# COLORES Y FORMATO (Paleta: Forest Green) - Con detección de terminal
# ============================================================================
# Paleta personalizada: #3E7352, #529B6F, #67C294, #AAF797, #DCFF93, #0E1C0F, #1C3121, #2B4D33

# Detectar capacidades de color del terminal
detect_color_support() {
    # True Color (24-bit): iTerm2, Cursor IDE, VS Code, Kitty, Alacritty
    if [[ "$COLORTERM" == "truecolor" || "$COLORTERM" == "24bit" ]]; then
        echo "truecolor"
    # 256 colores: xterm-256color, screen-256color
    elif [[ "$TERM" == *"256color"* || "$TERM" == "xterm-kitty" ]]; then
        echo "256"
    # Terminal.app de macOS (detectar por TERM_PROGRAM)
    elif [[ "$TERM_PROGRAM" == "Apple_Terminal" ]]; then
        echo "256"
    # Básico (16 colores)
    else
        echo "basic"
    fi
}

COLOR_MODE=$(detect_color_support)

# Configurar colores según capacidad del terminal
if [[ "$COLOR_MODE" == "truecolor" ]]; then
    # ═══ True Color (24-bit) - Colores exactos de la paleta ═══
    C_DARK_GREEN='\033[38;2;62;115;82m'       # #3E7352
    C_MEDIUM_GREEN='\033[38;2;82;155;111m'    # #529B6F
    C_LIGHT_GREEN='\033[38;2;103;194;148m'    # #67C294
    C_LIME='\033[38;2;170;247;151m'           # #AAF797
    C_YELLOW_GREEN='\033[38;2;220;255;147m'   # #DCFF93
    C_VERY_DARK='\033[38;2;14;28;15m'         # #0E1C0F
    C_FOREST='\033[38;2;28;49;33m'            # #1C3121
    C_DARK_FOREST='\033[38;2;43;77;51m'       # #2B4D33
    
elif [[ "$COLOR_MODE" == "256" ]]; then
    # ═══ 256 colores - Aproximaciones para Terminal.app macOS ═══
    C_DARK_GREEN='\033[38;5;65m'      # Aproximación a #3E7352
    C_MEDIUM_GREEN='\033[38;5;71m'    # Aproximación a #529B6F
    C_LIGHT_GREEN='\033[38;5;79m'     # Aproximación a #67C294
    C_LIME='\033[38;5;156m'           # Aproximación a #AAF797
    C_YELLOW_GREEN='\033[38;5;192m'   # Aproximación a #DCFF93
    C_VERY_DARK='\033[38;5;234m'      # Aproximación a #0E1C0F
    C_FOREST='\033[38;5;236m'         # Aproximación a #1C3121
    C_DARK_FOREST='\033[38;5;22m'     # Aproximación a #2B4D33
    
else
    # ═══ ANSI básico (16 colores) - Máxima compatibilidad ═══
    C_DARK_GREEN='\033[32m'           # Verde estándar
    C_MEDIUM_GREEN='\033[32m'         # Verde estándar
    C_LIGHT_GREEN='\033[92m'          # Verde brillante
    C_LIME='\033[92m'                 # Verde brillante
    C_YELLOW_GREEN='\033[93m'         # Amarillo brillante
    C_VERY_DARK='\033[90m'            # Gris oscuro
    C_FOREST='\033[90m'               # Gris oscuro
    C_DARK_FOREST='\033[32m'          # Verde estándar
fi

# Alias semánticos (mapeo a la paleta)
GREEN="${C_LIGHT_GREEN}"      # Éxito, confirmaciones
YELLOW="${C_YELLOW_GREEN}"    # Advertencias, preguntas
RED="${C_DARK_GREEN}"         # Errores (verde oscuro para mantener paleta)
BLUE="${C_MEDIUM_GREEN}"      # Información
CYAN="${C_LIME}"              # Destacados, títulos
ACCENT="${C_LIME}"            # Acentos brillantes
MUTED="${C_DARK_FOREST}"      # Texto secundario

# Formato
BOLD='\033[1m'
DIM='\033[2m'
ITALIC='\033[3m'
UNDERLINE='\033[4m'
NC='\033[0m'                  # Reset / Sin color

# ============================================================================
# CONFIGURACIÓN
# ============================================================================
QUALITY_MODE="vbr"      # "vbr" o "cbr"
VBR_QUALITY=0           # VBR quality (0=máxima calidad)
CBR_BITRATE="320k"      # CBR bitrate
VIDEO_CRF=18            # Calidad de video (menor = mejor, 18 es muy bueno)
VIDEO_PRESET="slow"     # Preset de codificación (slower = mejor compresión)
VIDEO_RESOLUTION="1920:1080"  # Resolución de salida para MP4

# Configuración para álbum unificado (modo 4)
SILENCE_DURATION=2      # Segundos de silencio entre pistas
MP3_BITRATE="320k"      # Bitrate del MP3 final
ALBUM_NAME=""           # Nombre personalizado para el archivo de salida

# Configuración para FLAC de alta resolución (modo 5)
FLAC_SAMPLE_RATE=96000  # Sample rate: 96000 (96kHz), 48000 (48kHz), 44100 (44.1kHz)
FLAC_BIT_DEPTH=24       # Bit depth: 24 o 16
FLAC_COMPRESSION=8      # Nivel de compresión FLAC: 0 (rápido) - 12 (máxima compresión)

# Variables globales
DRY_RUN=0
SINGLE_FILE=""
SOURCE_DIR=""      # -o / --origen: carpeta donde están los archivos
DEST_DIR=""        # -d / --destino: carpeta donde guardar los convertidos
VERBOSE=0

# ============================================================================
# FUNCIONES DE UTILIDAD
# ============================================================================

# Mostrar ayuda
show_help() {
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                    SCRIPT DE CONVERSIÓN DE AUDIO/VIDEO                       ║
╚══════════════════════════════════════════════════════════════════════════════╝

USO:
    ./06_m4a_to_mp4.zsh [opciones]

OPCIONES:
    -h, --help          Mostrar esta ayuda
    -f, --file FILE     Convertir un archivo específico
    -o, --origen DIR    Carpeta ORIGEN donde están los archivos (sin ranger)
    -d, --destino DIR   Carpeta DESTINO donde guardar los convertidos
    -m, --mode MODE     Modo de conversión: 1, 2, 3, 4 o 5 (ver abajo)
    --dry-run           Simular conversión sin ejecutar
    -v, --verbose       Mostrar información detallada
    --cbr BITRATE       Usar CBR con bitrate específico (ej: 256k)
    --vbr QUALITY       Usar VBR con calidad 0-5 (0=mejor)
    
    Opciones para modo 4 (Álbum unificado):
    --silence SECS      Segundos de silencio entre pistas (default: 2)
    --album NOMBRE      Nombre del archivo MP3 de salida
    --mp3-bitrate RATE  Bitrate del MP3 final (default: 320k)
    
    Opciones para modo 5 (FLAC alta resolución):
    --sample-rate RATE  Sample rate: 96000, 48000, 44100 (default: 96000)
    --bit-depth BITS    Bit depth: 24 o 16 (default: 24)
    --flac-level LEVEL  Nivel de compresión: 0-12 (default: 8)

MODOS DE CONVERSIÓN:
    1) M4A → MP4        Crea video con imagen estática (requiere cover.png)
    2) WAV → M4A        Comprime WAV a AAC de alta calidad
    3) FLAC → M4A       Convierte FLAC a AAC
    4) ÁLBUM → MP3      Une todos los FLAC/WAV/M4A en UN SOLO MP3
                        (Para registro de derechos de autor)
    5) AUDIO → FLAC     Convierte cualquier audio a FLAC 96kHz/24-bit
                        (Alta resolución para producción/archivo)

EJEMPLOS:
    # Modo interactivo con selección visual
    ./06_m4a_to_mp4.zsh

    # Convertir archivo individual
    ./06_m4a_to_mp4.zsh -f cancion.m4a -m 1

    # Convertir carpeta específica (origen y destino)
    ./06_m4a_to_mp4.zsh -o ~/Music/Album -d ~/Music/Convertidos -m 2

    # Solo especificar origen (destino = subcarpeta 'converted')
    ./06_m4a_to_mp4.zsh -o ~/Music/Album -m 2

    # Simular sin convertir
    ./06_m4a_to_mp4.zsh -o ~/Music --dry-run -m 1

    # CBR a 256kbps
    ./06_m4a_to_mp4.zsh -o ~/Music -m 2 --cbr 256k

    # MODO 4: Unir álbum FLAC en un solo MP3 para registro de derechos
    ./06_m4a_to_mp4.zsh -o ~/Music/MiAlbum -m 4 --album "MiAlbum_Completo"
    
    # Con 3 segundos de silencio entre pistas
    ./06_m4a_to_mp4.zsh -o ~/Music/MiAlbum -m 4 --silence 3 --mp3-bitrate 256k

    # MODO 5: Convertir audio a FLAC 96kHz/24-bit (alta resolución)
    ./06_m4a_to_mp4.zsh -o ~/Music/Album -m 5
    
    # FLAC 48kHz/16-bit (calidad CD)
    ./06_m4a_to_mp4.zsh -o ~/Music/Album -m 5 --sample-rate 48000 --bit-depth 16

EOF
}

# ============================================================================
# MANEJO DE INTERRUPCIONES (Ctrl+C)
# ============================================================================

# Variable para rastrear si se interrumpió el script
INTERRUPTED=0

# Limpiar archivos temporales al salir
cleanup() {
    # Limpiar archivos temporales individuales
    [[ -n "$TMP_FILE" && -f "$TMP_FILE" ]] && rm -f "$TMP_FILE"
    [[ -n "$TMP_LOG" && -f "$TMP_LOG" ]] && rm -f "$TMP_LOG"
    
    # Limpiar directorio temporal del álbum si existe
    [[ -n "$TMP_ALBUM_DIR" && -d "$TMP_ALBUM_DIR" ]] && rm -rf "$TMP_ALBUM_DIR"
}

# Manejador de señal SIGINT (Ctrl+C)
handle_interrupt() {
    INTERRUPTED=1
    echo ""
    echo ""
    echo "${C_DARK_GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo "${C_DARK_GREEN}║  ${C_YELLOW_GREEN}⚠️  INTERRUPCIÓN DETECTADA (Ctrl+C)${C_DARK_GREEN}                        ║${NC}"
    echo "${C_DARK_GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    print_msg warning "Limpiando archivos temporales..."
    cleanup
    print_msg info "Operación cancelada por el usuario."
    echo ""
    exit 130  # Código de salida estándar para SIGINT
}

# Registrar manejadores de señales
trap handle_interrupt SIGINT SIGTERM
trap cleanup EXIT

# Imprimir mensaje con formato
print_msg() {
    local type="$1"
    shift
    case "$type" in
        info)    echo "${C_MEDIUM_GREEN}ℹ${NC}  $*" ;;
        success) echo "${C_LIGHT_GREEN}✓${NC}  $*" ;;
        warning) echo "${C_YELLOW_GREEN}⚠${NC}  $*" ;;
        error)   echo "${C_DARK_GREEN}✗${NC}  $*" >&2 ;;
        header)  echo "\n${BOLD}${C_LIME}═══ $* ═══${NC}\n" ;;
        title)   echo "${BOLD}${C_LIME}$*${NC}" ;;
        muted)   echo "${C_DARK_FOREST}$*${NC}" ;;
    esac
}

# Pedir confirmación al usuario (más amigable)
# Uso: if confirmar "¿Continuar?"; then ... fi
# Retorna: 0 = sí, 1 = no
confirmar() {
    local mensaje="${1:-¿Continuar?}"
    local respuesta
    
    while true; do
        echo -n "${C_YELLOW_GREEN}${mensaje} (s/n): ${NC}"
        read -r respuesta
        
        case "$respuesta" in
            [SsYy])
                return 0
                ;;
            [Nn])
                return 1
                ;;
            "")
                echo "    ${C_DARK_GREEN}⚠ Debes escribir 's' para sí o 'n' para no${NC}"
                ;;
            *)
                echo "    ${C_DARK_GREEN}⚠ Opción no válida: '${respuesta}'${NC}"
                echo "    ${C_MEDIUM_GREEN}Escribe 's' (sí) o 'n' (no)${NC}"
                ;;
        esac
    done
}

# Barra de progreso simple
progress_bar() {
    local current="$1"
    local total="$2"
    local width=40
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r${C_DARK_FOREST}[${NC}"
    printf "${C_LIGHT_GREEN}%${filled}s${NC}" | tr ' ' '█'
    printf "${C_DARK_FOREST}%${empty}s${NC}" | tr ' ' '░'
    printf "${C_DARK_FOREST}]${NC} ${C_LIME}%3d%%${NC} ${C_MEDIUM_GREEN}(%d/%d)${NC}" "$percent" "$current" "$total"
}

# ============================================================================
# BARRA DE PROGRESO ANIMADA DIVERTIDA 🎮
# ============================================================================

# Animación de spinner musical
SPINNER_FRAMES=('🎵' '🎶' '🎸' '🎹' '🎺' '🎷' '🥁' '🎻')
SPINNER_IDX=0

# Animación de barra con notas musicales
BAR_CHARS=('░' '▒' '▓' '█')
MUSIC_NOTES=('♪' '♫' '♬' '♩')

# Barra de progreso animada para el modo 4 (álbum unificado)
animated_progress_bar() {
    local current="$1"
    local total="$2"
    local label="${3:-Procesando}"
    local width=35
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    # Obtener siguiente frame del spinner
    local spinner="${SPINNER_FRAMES[$SPINNER_IDX]}"
    SPINNER_IDX=$(( (SPINNER_IDX + 1) % ${#SPINNER_FRAMES[@]} ))
    
    # Seleccionar nota musical para el indicador
    local note_idx=$((current % ${#MUSIC_NOTES[@]}))
    local note="${MUSIC_NOTES[$note_idx]}"
    
    # Construir la barra con efecto de onda
    local bar=""
    for ((i=0; i<filled; i++)); do
        local char_idx=$(( (i + SPINNER_IDX) % 4 ))
        if [[ $i -eq $((filled - 1)) && $filled -gt 0 ]]; then
            bar+="${C_LIME}${note}${NC}"
        else
            bar+="${C_LIGHT_GREEN}█${NC}"
        fi
    done
    
    for ((i=0; i<empty; i++)); do
        bar+="${C_DARK_FOREST}░${NC}"
    done
    
    # Imprimir la barra (a stderr para no interferir con ffmpeg)
    printf "\r    ${spinner} ${C_DARK_FOREST}[${NC}${bar}${C_DARK_FOREST}]${NC} " >&2
    printf "${C_LIME}%3d%%${NC} ${C_MEDIUM_GREEN}%s${NC} " "$percent" "$label" >&2
    printf "${C_YELLOW_GREEN}(%d/%d)${NC}  " "$current" "$total" >&2
}

# Animación de carga tipo "ecualizador"
equalizer_animation() {
    local frame="$1"
    local bars=8
    local output=""
    
    for ((i=0; i<bars; i++)); do
        local height=$(( (RANDOM % 5) + 1 ))
        local bar_char=""
        case $height in
            1) bar_char="▁" ;;
            2) bar_char="▃" ;;
            3) bar_char="▅" ;;
            4) bar_char="▆" ;;
            5) bar_char="█" ;;
        esac
        
        # Color gradient
        case $((i % 4)) in
            0) output+="${C_DARK_GREEN}${bar_char}${NC}" ;;
            1) output+="${C_MEDIUM_GREEN}${bar_char}${NC}" ;;
            2) output+="${C_LIGHT_GREEN}${bar_char}${NC}" ;;
            3) output+="${C_LIME}${bar_char}${NC}" ;;
        esac
    done
    
    printf "\r    ${C_YELLOW_GREEN}🎧${NC} ${output} " >&2
}

# Spinner de carga estilo retro gaming
retro_spinner() {
    local frame="$1"
    local message="${2:-Cargando...}"
    local spinners=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local idx=$((frame % ${#spinners[@]}))
    local spinner="${spinners[$idx]}"
    
    # Efecto de "puntos cargando"
    local dots_count=$((frame % 4))
    local dots=""
    for ((i=0; i<dots_count; i++)); do
        dots+="."
    done
    dots=$(printf "%-3s" "$dots")
    
    printf "\r    ${C_LIME}${spinner}${NC} ${C_LIGHT_GREEN}${message}${dots}${NC}  " >&2
}

# Barra de progreso con "tanque" móvil 🎮
tank_progress_bar() {
    local current="$1"
    local total="$2"
    local label="${3:-}"
    local width=30
    local percent=$((current * 100 / total))
    local position=$((current * width / total))
    
    # Seleccionar el tanque según la posición
    local tanks=('🚂' '🚃' '🚃' '🎵')
    local tank_idx=$((current % ${#tanks[@]}))
    
    printf "\r    " >&2
    
    # Pista recorrida
    for ((i=0; i<position; i++)); do
        printf "${C_LIGHT_GREEN}═${NC}" >&2
    done
    
    # El tanque/tren musical
    printf "${C_LIME}🎵${NC}" >&2
    
    # Pista por recorrer
    for ((i=position; i<width; i++)); do
        printf "${C_DARK_FOREST}─${NC}" >&2
    done
    
    printf " ${C_LIME}%3d%%${NC}" "$percent" >&2
    
    if [[ -n "$label" ]]; then
        printf " ${C_MEDIUM_GREEN}${label}${NC}" >&2
    fi
    
    printf "  " >&2
}

# Animación de "ondas de audio"
audio_wave_animation() {
    local frame="$1"
    local waves=()
    
    # Generar onda sinusoidal simulada
    for ((i=0; i<12; i++)); do
        local phase=$(( (frame + i) % 8 ))
        case $phase in
            0|7) waves+=("▁") ;;
            1|6) waves+=("▂") ;;
            2|5) waves+=("▄") ;;
            3|4) waves+=("▆") ;;
        esac
    done
    
    printf "\r    ${C_LIME}🎧${NC} " >&2
    for ((i=0; i<${#waves[@]}; i++)); do
        local color_idx=$((i % 4))
        case $color_idx in
            0) printf "${C_DARK_GREEN}${waves[$i]}${NC}" >&2 ;;
            1) printf "${C_MEDIUM_GREEN}${waves[$i]}${NC}" >&2 ;;
            2) printf "${C_LIGHT_GREEN}${waves[$i]}${NC}" >&2 ;;
            3) printf "${C_LIME}${waves[$i]}${NC}" >&2 ;;
        esac
    done
    printf " ${C_LIME}🎧${NC} " >&2
}

# Progreso estilo "loading de videojuego"
gaming_progress() {
    local current="$1"
    local total="$2"
    local label="${3:-CARGANDO}"
    local percent=$((current * 100 / total))
    
    # Frame de animación basado en el tiempo
    local frame=$((current % 4))
    local loading_chars=('◐' '◓' '◑' '◒')
    local loader="${loading_chars[$frame]}"
    
    # Barra pixelada estilo 8-bit
    local width=20
    local filled=$((current * width / total))
    local bar=""
    
    for ((i=0; i<width; i++)); do
        if [[ $i -lt $filled ]]; then
            bar+="■"
        else
            bar+="□"
        fi
    done
    
    printf "\r    ${C_LIME}${loader}${NC} ${C_DARK_FOREST}[${C_LIGHT_GREEN}${bar}${C_DARK_FOREST}]${NC} "
    printf "${C_YELLOW_GREEN}${label}${NC} ${C_LIME}%3d%%${NC}  " "$percent"
}

# Verificar dependencias
check_dependencies() {
    local missing=()
    
    if ! command -v ffmpeg &> /dev/null; then
        missing+=("ffmpeg")
    fi
    
    if ! command -v ffprobe &> /dev/null; then
        missing+=("ffprobe")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_msg error "Dependencias faltantes: ${missing[*]}"
        echo "  Instalar con: brew install ffmpeg"
        return 1
    fi
    
    # ranger es opcional
    if ! command -v ranger &> /dev/null; then
        print_msg warning "ranger no instalado. Usar -d para especificar carpeta directamente."
        return 0
    fi
    
    return 0
}

# Seleccionar carpeta con ranger o entrada manual
select_folder() {
    if [[ -n "$SOURCE_DIR" ]]; then
        # Ya especificado por línea de comandos
        if [[ ! -d "$SOURCE_DIR" ]]; then
            print_msg error "Carpeta no existe: $SOURCE_DIR"
            return 1
        fi
        return 0
    fi
    
    if command -v ranger &> /dev/null; then
        TMP_FILE="/tmp/choosedir_$$"
        print_msg info "Navega a la carpeta deseada en ranger."
        echo "    ${C_YELLOW_GREEN}→ Presiona Shift-G cuando estés en la carpeta, luego Enter${NC}"
        echo "    ${C_YELLOW_GREEN}→ Sal de ranger con 'q'${NC}"
        echo ""
        echo -n "${C_MEDIUM_GREEN}Presiona Enter para abrir ranger...${NC}"
        read -r
        echo ""
        
        ranger --choosedir="$TMP_FILE" "${HOME}"
        
        if [[ -f "$TMP_FILE" ]]; then
            SOURCE_DIR=$(cat "$TMP_FILE")
            rm -f "$TMP_FILE"
        fi
    else
        echo "${C_YELLOW_GREEN}Ingresa la ruta de la carpeta:${NC}"
        read -r SOURCE_DIR
        # Expandir ~ si se usa
        SOURCE_DIR="${SOURCE_DIR/#\~/$HOME}"
    fi
    
    if [[ -z "$SOURCE_DIR" || ! -d "$SOURCE_DIR" ]]; then
        print_msg error "No se seleccionó una carpeta válida."
        return 1
    fi
    
    print_msg success "Carpeta seleccionada: $SOURCE_DIR"
    return 0
}

# Obtener información del archivo de audio
get_audio_info() {
    local file="$1"
    local info
    
    info=$(ffprobe -v error -show_entries format=duration,bit_rate -show_entries stream=codec_name,sample_rate,channels -of json "$file" 2>/dev/null)
    echo "$info"
}

# Formatear duración en mm:ss
format_duration() {
    local seconds="$1"
    local mins=$((${seconds%.*} / 60))
    local secs=$((${seconds%.*} % 60))
    printf "%02d:%02d" "$mins" "$secs"
}

# ============================================================================
# FUNCIONES DE CONVERSIÓN
# ============================================================================

# Convertir M4A a MP4 (con imagen estática)
convert_m4a_to_mp4() {
    local audio_file="$1"
    local output_dir="$2"
    local cover_image="$3"
    
    local filename="${audio_file:t:r}"  # Nombre sin extensión
    local output_file="${output_dir}/${filename}.mp4"
    
    # Obtener duración del audio
    local duration
    duration=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$audio_file")
    
    if [[ -z "$duration" ]]; then
        print_msg error "No se pudo determinar la duración de: ${audio_file:t}"
        return 1
    fi
    
    # Detectar codec de audio para decidir si re-codificar
    local audio_codec
    audio_codec=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=nw=1:nk=1 "$audio_file")
    
    local audio_args=()
    if [[ "$audio_codec" == "aac" ]]; then
        # Copiar audio AAC sin re-codificar
        audio_args=(-c:a copy)
        [[ $VERBOSE -eq 1 ]] && print_msg info "Copiando audio AAC sin re-codificar"
    else
        # Re-codificar a AAC
        audio_args=(-c:a aac -b:a 192k -ar 48000)
        [[ $VERBOSE -eq 1 ]] && print_msg info "Re-codificando audio a AAC"
    fi
    
    if [[ $DRY_RUN -eq 1 ]]; then
        print_msg info "[DRY-RUN] Convertiría: ${audio_file:t} → ${output_file:t}"
        return 0
    fi
    
    local duration_fmt
    duration_fmt=$(format_duration "$duration")
    echo "    ${C_LIME}Duración:${NC} ${C_LIGHT_GREEN}${duration_fmt}${NC} | ${C_LIME}Codec:${NC} ${C_LIGHT_GREEN}${audio_codec}${NC}"
    
    TMP_LOG="/tmp/ffmpeg_$$_log.txt"
    
    ffmpeg -hide_banner -loglevel warning -stats \
        -loop 1 -framerate 30 -i "$cover_image" \
        -i "$audio_file" \
        -map 0:v:0 -map 1:a:0 \
        -t "$duration" -shortest \
        -c:v libx264 -preset "$VIDEO_PRESET" -crf "$VIDEO_CRF" -pix_fmt yuv420p \
        "${audio_args[@]}" \
        -vf "scale=${VIDEO_RESOLUTION}:force_original_aspect_ratio=decrease,pad=${VIDEO_RESOLUTION}:(ow-iw)/2:(oh-ih)/2" \
        -movflags +faststart \
        -metadata title="$filename" \
        -y "$output_file" 2>"$TMP_LOG"
    
    local exit_code=$?
    
    if [[ $exit_code -eq 0 && -f "$output_file" ]]; then
        # Verificar duración del archivo de salida
        local out_duration
        out_duration=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$output_file")
        
        if [[ -n "$out_duration" ]]; then
            local diff
            diff=$(echo "$duration - $out_duration" | bc 2>/dev/null | tr -d '-')
            diff=${diff:-0}
            
            # Advertir si la diferencia es mayor a 1 segundo
            if (( $(echo "$diff > 1" | bc -l 2>/dev/null || echo 0) )); then
                print_msg warning "Diferencia de duración: entrada=${duration}s, salida=${out_duration}s"
            fi
        fi
        
        local size
        size=$(du -h "$output_file" | cut -f1)
        print_msg success "Creado: ${output_file:t} (${size})"
        return 0
    else
        print_msg error "Falló la conversión de: ${audio_file:t}"
        [[ -f "$TMP_LOG" ]] && cat "$TMP_LOG" >&2
        return 1
    fi
}

# Convertir WAV/FLAC a M4A
convert_to_m4a() {
    local audio_file="$1"
    local output_dir="$2"
    
    local filename="${audio_file:t:r}"
    local output_file="${output_dir}/${filename}.m4a"
    
    if [[ $DRY_RUN -eq 1 ]]; then
        print_msg info "[DRY-RUN] Convertiría: ${audio_file:t} → ${output_file:t}"
        return 0
    fi
    
    local quality_args=()
    if [[ "$QUALITY_MODE" == "vbr" ]]; then
        quality_args=(-c:a aac -q:a "$VBR_QUALITY" -ar 48000)
    else
        quality_args=(-c:a aac -b:a "$CBR_BITRATE" -ar 48000)
    fi
    
    TMP_LOG="/tmp/ffmpeg_$$_log.txt"
    
    ffmpeg -hide_banner -loglevel warning -stats \
        -i "$audio_file" \
        "${quality_args[@]}" \
        -movflags +faststart \
        -y "$output_file" 2>"$TMP_LOG"
    
    local exit_code=$?
    
    if [[ $exit_code -eq 0 && -f "$output_file" ]]; then
        local orig_size out_size
        orig_size=$(du -h "$audio_file" | cut -f1)
        out_size=$(du -h "$output_file" | cut -f1)
        print_msg success "Creado: ${output_file:t} (${orig_size} → ${out_size})"
        return 0
    else
        print_msg error "Falló la conversión de: ${audio_file:t}"
        [[ -f "$TMP_LOG" ]] && cat "$TMP_LOG" >&2
        return 1
    fi
}

# ============================================================================
# PROCESAMIENTO PRINCIPAL
# ============================================================================

process_m4a_to_mp4() {
    local output_dirname="${1:-converted_videos}"
    
    cd "$SOURCE_DIR" || {
        print_msg error "No se puede acceder a: $SOURCE_DIR"
        return 1
    }
    
    # Buscar archivos M4A
    local m4a_files=()
    while IFS= read -r -d '' file; do
        m4a_files+=("$file")
    done < <(find . -maxdepth 1 -type f -iname "*.m4a" -print0 | sort -z)
    
    if [[ ${#m4a_files[@]} -eq 0 ]]; then
        print_msg error "No se encontraron archivos .m4a en esta carpeta."
        return 1
    fi
    
    print_msg header "Archivos M4A encontrados: ${#m4a_files[@]}"
    for f in "${m4a_files[@]}"; do
        echo "    📄 ${f:t}"
    done
    echo ""
    
    # Buscar imagen de portada
    local cover_image=""
    for img in cover.png cover.jpg Cover.png Cover.jpg artwork.png artwork.jpg; do
        if [[ -f "$img" ]]; then
            cover_image="$img"
            break
        fi
    done
    
    if [[ -z "$cover_image" ]]; then
        print_msg error "No se encontró imagen de portada (cover.png, cover.jpg, etc.)"
        echo "    Coloca una imagen llamada 'cover.png' en la carpeta."
        return 1
    fi
    
    print_msg info "Usando portada: $cover_image"
    
    if [[ $DRY_RUN -eq 0 ]]; then
        if ! confirmar "¿Convertir ${#m4a_files[@]} archivos a MP4?"; then
            print_msg warning "Conversión cancelada."
            return 0
        fi
    fi
    
    mkdir -p "$output_dirname"
    
    local success_count=0
    local fail_count=0
    local total=${#m4a_files[@]}
    local current=0
    
    print_msg header "Iniciando conversión M4A → MP4"
    echo "    ${C_MEDIUM_GREEN}💡 Presiona Ctrl+C en cualquier momento para cancelar${NC}"
    echo ""
    
    for audio_file in "${m4a_files[@]}"; do
        # Verificar interrupción
        if [[ $INTERRUPTED -eq 1 ]]; then
            print_msg warning "Conversión interrumpida por el usuario"
            break
        fi
        
        ((current++))
        echo "\n${BOLD}[${current}/${total}]${NC} ${audio_file:t}"
        
        if convert_m4a_to_mp4 "$audio_file" "$output_dirname" "$cover_image"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
    done
    
    echo ""
    print_msg header "Conversión MP4 Completada"
    echo "    ${C_LIGHT_GREEN}Exitosos:${NC} ${C_LIME}$success_count${NC}"
    [[ $fail_count -gt 0 ]] && echo "    ${C_DARK_GREEN}Fallidos:${NC} ${C_YELLOW_GREEN}$fail_count${NC}"
    echo "    ${C_LIME}Salida:${NC}   ${C_LIGHT_GREEN}${SOURCE_DIR}/${output_dirname}/${NC}"
}

process_audio_to_m4a() {
    local format="$1"  # "wav" o "flac"
    local output_dirname="${2:-converted}"
    
    cd "$SOURCE_DIR" || {
        print_msg error "No se puede acceder a: $SOURCE_DIR"
        return 1
    }
    
    # Buscar archivos del formato especificado
    local audio_files=()
    local pattern
    
    case "$format" in
        wav)  pattern="*.wav" ;;
        flac) pattern="*.flac" ;;
        *)    pattern="*.wav" ;;
    esac
    
    while IFS= read -r -d '' file; do
        audio_files+=("$file")
    done < <(find . -maxdepth 1 -type f \( -iname "$pattern" \) -print0 | sort -z)
    
    if [[ ${#audio_files[@]} -eq 0 ]]; then
        print_msg error "No se encontraron archivos .${format} en esta carpeta."
        return 1
    fi
    
    print_msg header "Archivos ${format:u} encontrados: ${#audio_files[@]}"
    for f in "${audio_files[@]}"; do
        echo "    📄 ${f:t}"
    done
    echo ""
    
    print_msg info "Modo: $QUALITY_MODE"
    if [[ "$QUALITY_MODE" == "vbr" ]]; then
        echo "    VBR Quality: $VBR_QUALITY (0=máxima)"
    else
        echo "    Bitrate: $CBR_BITRATE"
    fi
    
    if [[ $DRY_RUN -eq 0 ]]; then
        if ! confirmar "¿Convertir ${#audio_files[@]} archivos a M4A?"; then
            print_msg warning "Conversión cancelada."
            return 0
        fi
    fi
    
    mkdir -p "$output_dirname"
    
    local success_count=0
    local fail_count=0
    local total=${#audio_files[@]}
    local current=0
    
    print_msg header "Iniciando conversión ${format:u} → M4A"
    echo "    ${C_MEDIUM_GREEN}💡 Presiona Ctrl+C en cualquier momento para cancelar${NC}"
    echo ""
    
    for audio_file in "${audio_files[@]}"; do
        # Verificar interrupción
        if [[ $INTERRUPTED -eq 1 ]]; then
            print_msg warning "Conversión interrumpida por el usuario"
            break
        fi
        
        ((current++))
        echo "\n${BOLD}[${current}/${total}]${NC} ${audio_file:t}"
        
        if convert_to_m4a "$audio_file" "$output_dirname"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
    done
    
    echo ""
    print_msg header "Conversión M4A Completada"
    echo "    ${C_LIGHT_GREEN}Exitosos:${NC} ${C_LIME}$success_count${NC}"
    [[ $fail_count -gt 0 ]] && echo "    ${C_DARK_GREEN}Fallidos:${NC} ${C_YELLOW_GREEN}$fail_count${NC}"
    echo "    ${C_LIME}Salida:${NC}   ${C_LIGHT_GREEN}${SOURCE_DIR}/${output_dirname}/${NC}"
}

# ============================================================================
# MODO 4: ÁLBUM UNIFICADO → MP3 (Para registro de derechos de autor)
# ============================================================================

process_album_to_unified_mp3() {
    local output_dirname="${1:-unified}"
    
    cd "$SOURCE_DIR" || {
        print_msg error "No se puede acceder a: $SOURCE_DIR"
        return 1
    }
    
    # Buscar todos los archivos de audio soportados (FLAC, WAV, M4A)
    local audio_files=()
    while IFS= read -r -d '' file; do
        audio_files+=("$file")
    done < <(find . -maxdepth 1 -type f \( -iname "*.flac" -o -iname "*.wav" -o -iname "*.m4a" -o -iname "*.mp3" \) -print0 | sort -z)
    
    if [[ ${#audio_files[@]} -eq 0 ]]; then
        print_msg error "No se encontraron archivos de audio (FLAC/WAV/M4A/MP3) en esta carpeta."
        return 1
    fi
    
    if [[ ${#audio_files[@]} -lt 2 ]]; then
        print_msg warning "Solo se encontró 1 archivo. Este modo está diseñado para álbumes con múltiples pistas."
    fi
    
    print_msg header "Archivos de audio encontrados: ${#audio_files[@]}"
    
    local total_duration=0
    local track_num=1
    
    for f in "${audio_files[@]}"; do
        local dur
        dur=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$f" 2>/dev/null)
        dur=${dur:-0}
        local dur_fmt
        dur_fmt=$(format_duration "$dur")
        echo "    ${C_LIME}${track_num}.${NC} ${C_LIGHT_GREEN}${f:t}${NC} ${C_MEDIUM_GREEN}(${dur_fmt})${NC}"
        total_duration=$(echo "$total_duration + $dur" | bc 2>/dev/null || echo "$total_duration")
        ((track_num++))
    done
    
    # Calcular duración total con silencios
    local total_silence=$((SILENCE_DURATION * (${#audio_files[@]} - 1)))
    local final_duration=$(echo "$total_duration + $total_silence" | bc 2>/dev/null || echo "$total_duration")
    local total_fmt
    total_fmt=$(format_duration "$final_duration")
    
    echo ""
    print_msg info "Configuración:"
    echo "    ${C_LIME}Pistas:${NC}              ${C_LIGHT_GREEN}${#audio_files[@]}${NC}"
    echo "    ${C_LIME}Silencio entre pistas:${NC} ${C_LIGHT_GREEN}${SILENCE_DURATION} segundos${NC}"
    echo "    ${C_LIME}Duración total estimada:${NC} ${C_LIGHT_GREEN}${total_fmt}${NC}"
    echo "    ${C_LIME}Bitrate MP3:${NC}         ${C_LIGHT_GREEN}${MP3_BITRATE}${NC}"
    
    # Determinar nombre del archivo de salida
    local output_name
    if [[ -n "$ALBUM_NAME" ]]; then
        output_name="$ALBUM_NAME"
    else
        # Usar el nombre de la carpeta como nombre del álbum
        output_name=$(basename "$SOURCE_DIR")
        output_name="${output_name// /_}_completo"
    fi
    
    mkdir -p "$output_dirname"
    local output_file="${output_dirname}/${output_name}.mp3"
    
    echo "    ${C_LIME}Archivo de salida:${NC}   ${C_LIGHT_GREEN}${output_file}${NC}"
    echo ""
    
    if [[ $DRY_RUN -eq 1 ]]; then
        print_msg info "[DRY-RUN] Se crearía: $output_file"
        print_msg info "[DRY-RUN] Con ${#audio_files[@]} pistas y ${SILENCE_DURATION}s de silencio entre cada una"
        return 0
    fi
    
    if ! confirmar "¿Crear MP3 unificado con ${#audio_files[@]} pistas?"; then
        print_msg warning "Operación cancelada."
        return 0
    fi
    
    print_msg header "Creando MP3 unificado para registro de derechos de autor"
    echo "    ${C_MEDIUM_GREEN}💡 Presiona Ctrl+C en cualquier momento para cancelar${NC}"
    echo ""
    
    # Crear directorio temporal para archivos intermedios (variable global para cleanup)
    TMP_ALBUM_DIR=$(mktemp -d -t album_concat.XXXXXX)
    
    # Generar archivo de silencio
    print_msg info "Generando silencio de ${SILENCE_DURATION} segundos..."
    local silence_file="${TMP_ALBUM_DIR}/silence.wav"
    ffmpeg -hide_banner -loglevel error \
        -f lavfi -i anullsrc=r=48000:cl=stereo \
        -t "$SILENCE_DURATION" \
        -y "$silence_file"
    
    if [[ ! -f "$silence_file" ]]; then
        print_msg error "No se pudo crear el archivo de silencio"
        [[ -d "$TMP_ALBUM_DIR" ]] && rm -rf "$TMP_ALBUM_DIR"
        return 1
    fi
    
    # Verificar si se interrumpió
    [[ $INTERRUPTED -eq 1 ]] && return 1
    
    # Crear lista de archivos para concatenar
    local concat_list="${TMP_ALBUM_DIR}/concat_list.txt"
    local track_count=0
    local total_tracks=${#audio_files[@]}
    
    echo ""
    echo "    ${C_LIME}╔════════════════════════════════════════════════════════════╗${NC}"
    echo "    ${C_LIME}║${NC}  ${C_YELLOW_GREEN}🎵 PREPARANDO PISTAS PARA EL ÁLBUM UNIFICADO 🎵${NC}          ${C_LIME}║${NC}"
    echo "    ${C_LIME}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    for audio_file in "${audio_files[@]}"; do
        # Verificar interrupción en cada iteración
        if [[ $INTERRUPTED -eq 1 ]]; then
            echo ""
            print_msg warning "Proceso interrumpido durante la preparación de pistas"
            return 1
        fi
        
        ((track_count++))
        
        # Mostrar barra de progreso animada
        local filename_short="${audio_file:t}"
        [[ ${#filename_short} -gt 25 ]] && filename_short="${filename_short[1,22]}..."
        animated_progress_bar "$track_count" "$total_tracks" "$filename_short"
        
        # Convertir cada archivo a WAV temporal con sample rate consistente
        local tmp_wav="${TMP_ALBUM_DIR}/track_$(printf '%03d' $track_count).wav"
        
        ffmpeg -hide_banner -loglevel error \
            -i "$audio_file" \
            -ar 48000 -ac 2 \
            -y "$tmp_wav"
        
        if [[ ! -f "$tmp_wav" ]]; then
            echo ""
            print_msg error "Error al procesar: ${audio_file:t}"
            [[ -d "$TMP_ALBUM_DIR" ]] && rm -rf "$TMP_ALBUM_DIR"
            return 1
        fi
        
        # Añadir a la lista de concatenación
        echo "file '${tmp_wav}'" >> "$concat_list"
        
        # Añadir silencio después de cada pista excepto la última
        if [[ $track_count -lt $total_tracks ]]; then
            echo "file '${silence_file}'" >> "$concat_list"
        fi
    done
    
    # Línea final después de la barra de progreso
    echo ""
    echo ""
    print_msg success "✅ ${total_tracks} pistas preparadas correctamente"
    
    # Verificar interrupción antes de concatenar
    [[ $INTERRUPTED -eq 1 ]] && return 1
    
    # Concatenar todos los archivos con animación
    echo ""
    echo "    ${C_LIME}╔════════════════════════════════════════════════════════════╗${NC}"
    echo "    ${C_LIME}║${NC}  ${C_YELLOW_GREEN}🎼 CONCATENANDO ${total_tracks} PISTAS EN UN SOLO ARCHIVO 🎼${NC}     ${C_LIME}║${NC}"
    echo "    ${C_LIME}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    local tmp_concat="${TMP_ALBUM_DIR}/concatenated.wav"
    
    # Iniciar animación de concatenación en background
    (
        local frame=0
        while true; do
            audio_wave_animation "$frame"
            printf "${C_MEDIUM_GREEN}Uniendo pistas...${NC}  " >&2
            ((frame++))
            sleep 0.15
        done
    ) &
    local anim_pid=$!
    
    # Ejecutar concatenación
    ffmpeg -hide_banner -loglevel error \
        -f concat -safe 0 -i "$concat_list" \
        -c copy \
        -y "$tmp_concat" 2>/dev/null
    
    local concat_result=$?
    
    # Detener animación y limpiar línea
    kill $anim_pid 2>/dev/null
    wait $anim_pid 2>/dev/null
    printf "\r\033[K" >&2  # Limpiar línea de animación
    
    if [[ $concat_result -ne 0 || ! -f "$tmp_concat" ]]; then
        echo ""
        print_msg error "Error al concatenar archivos"
        [[ -d "$TMP_ALBUM_DIR" ]] && rm -rf "$TMP_ALBUM_DIR"
        return 1
    fi
    
    echo ""
    print_msg success "✅ Pistas concatenadas exitosamente"
    
    # Verificar interrupción antes de convertir a MP3
    [[ $INTERRUPTED -eq 1 ]] && return 1
    
    # Convertir a MP3 final con animación
    echo ""
    echo "    ${C_LIME}╔════════════════════════════════════════════════════════════╗${NC}"
    echo "    ${C_LIME}║${NC}  ${C_YELLOW_GREEN}🎧 CODIFICANDO MP3 FINAL (${MP3_BITRATE}) 🎧${NC}                    ${C_LIME}║${NC}"
    echo "    ${C_LIME}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Iniciar animación de codificación en background
    (
        local frame=0
        local messages=("Codificando audio..." "Aplicando compresión..." "Generando MP3..." "Casi listo...")
        while true; do
            local msg_idx=$((frame / 10 % ${#messages[@]}))
            equalizer_animation "$frame"
            printf "${C_MEDIUM_GREEN}${messages[$msg_idx]}${NC}  " >&2
            ((frame++))
            sleep 0.1
        done
    ) &
    local encode_anim_pid=$!
    
    # Ejecutar codificación MP3
    ffmpeg -hide_banner -loglevel error \
        -i "$tmp_concat" \
        -codec:a libmp3lame -b:a "$MP3_BITRATE" \
        -id3v2_version 3 \
        -metadata title="$output_name" \
        -metadata album="$output_name" \
        -metadata comment="Álbum completo para registro de derechos de autor - ${total_tracks} pistas" \
        -y "$output_file" 2>/dev/null
    
    local encode_result=$?
    
    # Detener animación y limpiar línea
    kill $encode_anim_pid 2>/dev/null
    wait $encode_anim_pid 2>/dev/null
    printf "\r\033[K" >&2  # Limpiar línea de animación
    
    echo ""
    
    # Usar el resultado de la codificación
    local exit_code=$encode_result
    
    # Limpiar archivos temporales
    [[ -d "$TMP_ALBUM_DIR" ]] && rm -rf "$TMP_ALBUM_DIR"
    TMP_ALBUM_DIR=""
    
    if [[ $exit_code -eq 0 && -f "$output_file" ]]; then
        local final_size
        final_size=$(du -h "$output_file" | cut -f1)
        local final_dur
        final_dur=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$output_file")
        local final_dur_fmt
        final_dur_fmt=$(format_duration "$final_dur")
        
        # 🎉 ANIMACIÓN DE CELEBRACIÓN 🎉
        echo ""
        echo ""
        
        # Confetti animation
        local confetti=('🎉' '🎊' '✨' '🌟' '💫' '🎵' '🎶' '🏆')
        for ((i=0; i<3; i++)); do
            printf "\r    "
            for ((j=0; j<12; j++)); do
                local idx=$((RANDOM % ${#confetti[@]}))
                printf "${confetti[$idx]} "
            done
            sleep 0.2
        done
        
        echo ""
        echo ""
        echo "    ${C_LIME}╔════════════════════════════════════════════════════════════╗${NC}"
        echo "    ${C_LIME}║${NC}                                                            ${C_LIME}║${NC}"
        echo "    ${C_LIME}║${NC}   ${C_YELLOW_GREEN}🏆  ¡¡VICTORY ROYALE!!  🏆${NC}                              ${C_LIME}║${NC}"
        echo "    ${C_LIME}║${NC}                                                            ${C_LIME}║${NC}"
        echo "    ${C_LIME}║${NC}   ${C_LIGHT_GREEN}MP3 UNIFICADO CREADO EXITOSAMENTE${NC}                       ${C_LIME}║${NC}"
        echo "    ${C_LIME}║${NC}   ${C_MEDIUM_GREEN}Listo para registro de derechos de autor${NC}               ${C_LIME}║${NC}"
        echo "    ${C_LIME}║${NC}                                                            ${C_LIME}║${NC}"
        echo "    ${C_LIME}╚════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo "    ${C_LIME}Archivo:${NC}      ${C_LIGHT_GREEN}${output_file}${NC}"
        echo "    ${C_LIME}Pistas:${NC}       ${C_LIGHT_GREEN}${total_tracks}${NC}"
        echo "    ${C_LIME}Duración:${NC}     ${C_LIGHT_GREEN}${final_dur_fmt}${NC}"
        echo "    ${C_LIME}Tamaño:${NC}       ${C_LIGHT_GREEN}${final_size}${NC}"
        echo "    ${C_LIME}Bitrate:${NC}      ${C_LIGHT_GREEN}${MP3_BITRATE}${NC}"
        echo "    ${C_LIME}Silencio:${NC}     ${C_LIGHT_GREEN}${SILENCE_DURATION}s entre pistas${NC}"
        echo ""
        echo "    ${C_YELLOW_GREEN}📋 Este archivo contiene todas las pistas del álbum${NC}"
        echo "    ${C_YELLOW_GREEN}   en un solo MP3 continuo, ideal para:${NC}"
        echo "    ${C_MEDIUM_GREEN}   • Dirección Nacional de Derecho de Autor (Colombia)${NC}"
        echo "    ${C_MEDIUM_GREEN}   • Registro de obras musicales${NC}"
        echo "    ${C_MEDIUM_GREEN}   • Distribución con Ditto Pro${NC}"
        echo ""
        return 0
    else
        print_msg error "Error al crear el MP3 final"
        return 1
    fi
}

# ============================================================================
# MODO 5: AUDIO → FLAC 96kHz/24-bit (Alta resolución)
# ============================================================================

# Convertir archivo de audio a 432Hz (frecuencia sanadora para música devocional)
# Mantiene la duración original sin alterar el tempo
convert_to_432hz() {
    local input_file="$1"
    local output_file="$2"
    
    if [[ ! -f "$input_file" ]]; then
        print_msg error "El archivo no existe: $input_file"
        return 1
    fi
    
    # Detectar sample rate y bit depth del archivo original
    local sample_rate bit_depth codec_name
    sample_rate=$(ffprobe -v error -select_streams a:0 \
        -show_entries stream=sample_rate \
        -of default=noprint_wrappers=1:nokey=1 \
        "$input_file" 2>/dev/null)
    
    bit_depth=$(ffprobe -v error -select_streams a:0 \
        -show_entries stream=bits_per_sample \
        -of default=noprint_wrappers=1:nokey=1 \
        "$input_file" 2>/dev/null)
    
    if [[ -z "$sample_rate" ]]; then
        print_msg error "No se pudo detectar el sample rate del archivo"
        return 1
    fi
    
    # Usar bit depth detectado o default a 24
    bit_depth=${bit_depth:-24}
    
    # Determinar el formato de salida basado en la extensión
    local output_ext="${output_file:e:l}"
    local audio_codec="flac"
    local sample_fmt="s32"
    
    # FLAC requiere sample format específico
    if [[ $bit_depth -eq 16 ]]; then
        sample_fmt="s16"
    else
        sample_fmt="s32"  # FLAC usa s32 para 24-bit y 32-bit
    fi
    
    # Mostrar información de conversión
    echo "    ${C_MEDIUM_GREEN}🎵 Conversión a frecuencia universal 432Hz${NC}"
    echo "    ${C_DARK_FOREST}Sample Rate: ${sample_rate}Hz | Bit Depth: ${bit_depth}-bit${NC}"
    echo "    ${C_DARK_FOREST}Procesando: 440Hz → 432Hz (manteniendo duración)${NC}"
    
    TMP_LOG="/tmp/ffmpeg_432hz_$$.txt"
    
    # Iniciar animación en background
    (
        local frame=0
        local messages=("Ajustando frecuencia..." "Aplicando pitch shift..." "Re-muestreando audio..." "Casi listo...")
        while true; do
            local msg_idx=$((frame / 8 % ${#messages[@]}))
            audio_wave_animation "$frame"
            printf "${C_MEDIUM_GREEN}${messages[$msg_idx]}${NC}  " >&2
            ((frame++))
            sleep 0.12
        done
    ) &
    local anim_pid=$!
    
    # Fórmula de conversión:
    # asetrate = cambia el sample rate multiplicando por la relación 432/440
    # aresample = reestablece el sample rate original
    # atempo = ajusta el tempo para compensar y mantener la duración original
    # Redirigir stdout a /dev/null para que -stats no interfiera con la animación
    ffmpeg -hide_banner -loglevel warning -stats \
        -i "$input_file" \
        -af "asetrate=${sample_rate}*432/440,aresample=${sample_rate},atempo=440/432" \
        -c:a flac \
        -sample_fmt "$sample_fmt" \
        -compression_level "$FLAC_COMPRESSION" \
        -ar "$sample_rate" \
        -y "$output_file" >/dev/null 2>"$TMP_LOG"
    
    local exit_code=$?
    
    # Detener animación y limpiar línea
    kill $anim_pid 2>/dev/null
    wait $anim_pid 2>/dev/null
    printf "\r\033[K" >&2  # Limpiar línea de animación
    
    if [[ $exit_code -eq 0 && -f "$output_file" ]]; then
        local original_size new_size
        original_size=$(du -h "$input_file" | cut -f1)
        new_size=$(du -h "$output_file" | cut -f1)
        
        print_msg success "Conversión a 432Hz completada: ${output_file:t}"
        echo "    ${C_DARK_FOREST}Tamaño: ${original_size} → ${new_size}${NC}"
        
        # Limpiar log temporal
        [[ -f "$TMP_LOG" ]] && rm -f "$TMP_LOG"
        
        return 0
    else
        print_msg error "Error durante la conversión a 432Hz"
        [[ -f "$TMP_LOG" ]] && cat "$TMP_LOG" >&2
        [[ -f "$TMP_LOG" ]] && rm -f "$TMP_LOG"
        return 1
    fi
}

# Procesar archivos FLAC a 432Hz (para música devocional sikh)
process_flac_to_432hz() {
    local input_dir="$1"
    local output_dirname="${2:-flac_432hz}"
    
    cd "$input_dir" || {
        print_msg error "No se puede acceder a: $input_dir"
        return 1
    }
    
    # Buscar archivos FLAC en el directorio
    local flac_files=()
    while IFS= read -r -d '' file; do
        flac_files+=("$file")
    done < <(find . -maxdepth 1 -type f -iname "*.flac" -print0 | sort -z)
    
    if [[ ${#flac_files[@]} -eq 0 ]]; then
        print_msg error "No se encontraron archivos FLAC para convertir a 432Hz"
        return 1
    fi
    
    print_msg header "Conversión a frecuencia 432Hz - Música Devocional Sikh"
    echo ""
    echo "    ${C_LIME}╔════════════════════════════════════════════════════════════╗${NC}"
    echo "    ${C_LIME}║${NC}  ${C_YELLOW_GREEN}🕉️  CONVERSIÓN A 432Hz - FRECUENCIA SANADORA 🕉️${NC}         ${C_LIME}║${NC}"
    echo "    ${C_LIME}║${NC}  ${C_MEDIUM_GREEN}Wahe Guru Ji Ka Khalsa, Wahe Guru Ji Ki Fateh${NC}            ${C_LIME}║${NC}"
    echo "    ${C_LIME}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    print_msg info "Archivos FLAC encontrados: ${#flac_files[@]}"
    for f in "${flac_files[@]}"; do
        local dur
        dur=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$f" 2>/dev/null)
        local dur_fmt
        dur_fmt=$(format_duration "${dur:-0}")
        echo "    ${C_LIME}📄${NC} ${C_LIGHT_GREEN}${f:t}${NC} ${C_MEDIUM_GREEN}(${dur_fmt})${NC}"
    done
    echo ""
    
    if [[ $DRY_RUN -eq 1 ]]; then
        print_msg info "[DRY-RUN] Se convertirían ${#flac_files[@]} archivos FLAC a 432Hz"
        return 0
    fi
    
    mkdir -p "$output_dirname"
    
    local success_count=0
    local fail_count=0
    local total=${#flac_files[@]}
    local current=0
    
    for flac_file in "${flac_files[@]}"; do
        # Verificar interrupción
        if [[ $INTERRUPTED -eq 1 ]]; then
            print_msg warning "Conversión interrumpida por el usuario"
            break
        fi
        
        ((current++))
        local filename="${flac_file:t:r}"
        local output_file="${output_dirname}/${filename}_432Hz.flac"
        
        echo "\n${BOLD}[${current}/${total}]${NC} ${flac_file:t}"
        
        if convert_to_432hz "$flac_file" "$output_file"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
    done
    
    echo ""
    print_msg header "Conversión a 432Hz Completada"
    echo ""
    echo "    ${C_LIGHT_GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo "    ${C_LIGHT_GREEN}║${NC}  ${C_LIME}🎵 MÚSICA AHORA VIBRA EN FRECUENCIA UNIVERSAL 🎵${NC}        ${C_LIGHT_GREEN}║${NC}"
    echo "    ${C_LIGHT_GREEN}║${NC}  ${C_MEDIUM_GREEN}Sat Nam - Verdad es mi Identidad${NC}                   ${C_LIGHT_GREEN}║${NC}"
    echo "    ${C_LIGHT_GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "    ${C_LIGHT_GREEN}Exitosos:${NC} ${C_LIME}$success_count${NC}"
    [[ $fail_count -gt 0 ]] && echo "    ${C_DARK_GREEN}Fallidos:${NC} ${C_YELLOW_GREEN}$fail_count${NC}"
    echo "    ${C_LIME}Frecuencia:${NC} ${C_LIGHT_GREEN}432Hz (frecuencia sanadora)${NC}"
    echo "    ${C_LIME}Salida:${NC}     ${C_LIGHT_GREEN}${input_dir}/${output_dirname}/${NC}"
    echo ""
}

# Convertir un archivo individual a FLAC
convert_to_flac() {
    local audio_file="$1"
    local output_dir="$2"
    
    local filename="${audio_file:t:r}"
    local output_file="${output_dir}/${filename}.flac"
    
    if [[ $DRY_RUN -eq 1 ]]; then
        print_msg info "[DRY-RUN] Convertiría: ${audio_file:t} → ${output_file:t}"
        return 0
    fi
    
    # Obtener información del archivo de entrada
    local input_sr input_bd input_codec input_bd_actual
    input_sr=$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of default=nw=1:nk=1 "$audio_file" 2>/dev/null)
    input_bd=$(ffprobe -v error -select_streams a:0 -show_entries stream=bits_per_raw_sample -of default=nw=1:nk=1 "$audio_file" 2>/dev/null)
    input_bd_actual=$(ffprobe -v error -select_streams a:0 -show_entries stream=bits_per_sample -of default=nw=1:nk=1 "$audio_file" 2>/dev/null)
    input_codec=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=nw=1:nk=1 "$audio_file" 2>/dev/null)
    
    # Usar bits_per_sample si bits_per_raw_sample no está disponible
    input_bd=${input_bd:-$input_bd_actual}
    
    [[ $VERBOSE -eq 1 ]] && echo "    ${C_DARK_FOREST}Entrada: ${input_sr}Hz, ${input_bd:-?}bit, ${input_codec}${NC}"
    
    # Si el archivo ya es FLAC y tiene los mismos parámetros, copiar directamente
    if [[ "$input_codec" == "flac" ]]; then
        local needs_conversion=0
        
        # Verificar si necesita conversión
        if [[ "$input_sr" != "$FLAC_SAMPLE_RATE" ]]; then
            needs_conversion=1
        fi
        
        # Comparar bit depth
        local target_bd=$FLAC_BIT_DEPTH
        # Normalizar bit depth: 24-bit y 32-bit en FLAC usan s32 internamente
        local input_bd_norm="$input_bd"
        local target_bd_norm="$target_bd"
        [[ "$input_bd_norm" == "32" ]] && input_bd_norm="24"  # 32-bit FLAC se trata como 24-bit
        [[ "$target_bd_norm" == "32" ]] && target_bd_norm="24"  # 32-bit target se trata como 24-bit
        
        if [[ "$input_bd_norm" != "$target_bd_norm" ]]; then
            needs_conversion=1
        fi
        
        if [[ $needs_conversion -eq 0 ]]; then
            # No necesita conversión, copiar directamente
            print_msg info "Archivo FLAC ya tiene parámetros deseados, copiando..."
            cp "$audio_file" "$output_file"
            if [[ -f "$output_file" ]]; then
                local orig_size out_size
                orig_size=$(du -h "$audio_file" | cut -f1)
                out_size=$(du -h "$output_file" | cut -f1)
                print_msg success "Copiado (sin re-codificación): ${output_file:t}"
                echo "    ${C_DARK_FOREST}${orig_size} → ${out_size} | ${input_sr}Hz/${input_bd}bit${NC}"
                return 0
            fi
        else
            # Necesita conversión (sample rate o bit depth diferente)
            print_msg info "FLAC requiere re-codificación (${input_sr}Hz/${input_bd}bit → ${FLAC_SAMPLE_RATE}Hz/${FLAC_BIT_DEPTH}bit)"
        fi
    fi
    
    TMP_LOG="/tmp/ffmpeg_$$_log.txt"
    
    # Determinar sample format basado en bit depth
    local sample_fmt
    case "$FLAC_BIT_DEPTH" in
        16) sample_fmt="s16" ;;
        24) sample_fmt="s32" ;;  # FLAC usa s32 para 24-bit
        32) sample_fmt="s32" ;;
        *)  sample_fmt="s32" ;;
    esac
    
    # Iniciar animación en background
    (
        local frame=0
        local messages=("Procesando audio..." "Codificando FLAC..." "Aplicando compresión..." "Finalizando...")
        while true; do
            local msg_idx=$((frame / 8 % ${#messages[@]}))
            equalizer_animation "$frame"
            printf "${C_MEDIUM_GREEN}${messages[$msg_idx]}${NC}  " >&2
            ((frame++))
            sleep 0.12
        done
    ) &
    local anim_pid=$!
    
    # Redirigir stdout a /dev/null para que -stats no interfiera con la animación
    ffmpeg -hide_banner -loglevel warning -stats \
        -i "$audio_file" \
        -c:a flac \
        -ar "$FLAC_SAMPLE_RATE" \
        -sample_fmt "$sample_fmt" \
        -compression_level "$FLAC_COMPRESSION" \
        -y "$output_file" >/dev/null 2>"$TMP_LOG"
    
    local exit_code=$?
    
    # Detener animación y limpiar línea
    kill $anim_pid 2>/dev/null
    wait $anim_pid 2>/dev/null
    printf "\r\033[K" >&2  # Limpiar línea de animación
    
    if [[ $exit_code -eq 0 && -f "$output_file" ]]; then
        local orig_size out_size out_sr out_bd
        orig_size=$(du -h "$audio_file" | cut -f1)
        out_size=$(du -h "$output_file" | cut -f1)
        out_sr=$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of default=nw=1:nk=1 "$output_file" 2>/dev/null)
        out_bd=$(ffprobe -v error -select_streams a:0 -show_entries stream=bits_per_sample -of default=nw=1:nk=1 "$output_file" 2>/dev/null)
        
        print_msg success "Creado: ${output_file:t}"
        echo "    ${C_DARK_FOREST}${orig_size} → ${out_size} | ${out_sr}Hz/${out_bd}bit${NC}"
        return 0
    else
        print_msg error "Falló la conversión de: ${audio_file:t}"
        [[ -f "$TMP_LOG" ]] && cat "$TMP_LOG" >&2
        return 1
    fi
}

# Procesar carpeta completa a FLAC
process_audio_to_flac() {
    local output_dirname="${1:-flac_hires}"
    
    cd "$SOURCE_DIR" || {
        print_msg error "No se puede acceder a: $SOURCE_DIR"
        return 1
    }
    
    # Buscar archivos de audio soportados (WAV, M4A, MP3, AIFF, OGG, etc.)
    local audio_files=()
    while IFS= read -r -d '' file; do
        audio_files+=("$file")
    done < <(find . -maxdepth 1 -type f \( \
        -iname "*.wav" -o -iname "*.m4a" -o -iname "*.mp3" -o \
        -iname "*.aiff" -o -iname "*.aif" -o -iname "*.ogg" -o \
        -iname "*.wma" -o -iname "*.opus" -o -iname "*.flac" \
    \) -print0 | sort -z)
    
    if [[ ${#audio_files[@]} -eq 0 ]]; then
        print_msg error "No se encontraron archivos de audio en esta carpeta."
        print_msg info "Formatos soportados: WAV, M4A, MP3, AIFF, OGG, WMA, OPUS, FLAC"
        return 1
    fi
    
    print_msg header "Archivos de audio encontrados: ${#audio_files[@]}"
    for f in "${audio_files[@]}"; do
        local dur sr
        dur=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$f" 2>/dev/null)
        sr=$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of default=nw=1:nk=1 "$f" 2>/dev/null)
        local dur_fmt
        dur_fmt=$(format_duration "${dur:-0}")
        echo "    ${C_LIME}📄${NC} ${C_LIGHT_GREEN}${f:t}${NC} ${C_MEDIUM_GREEN}(${dur_fmt}, ${sr:-?}Hz)${NC}"
    done
    echo ""
    
    # Mostrar configuración
    local sr_display
    case "$FLAC_SAMPLE_RATE" in
        96000) sr_display="96kHz" ;;
        48000) sr_display="48kHz" ;;
        44100) sr_display="44.1kHz" ;;
        *)     sr_display="${FLAC_SAMPLE_RATE}Hz" ;;
    esac
    
    print_msg info "Configuración FLAC:"
    echo "    ${C_LIME}Sample Rate:${NC}    ${C_LIGHT_GREEN}${sr_display}${NC}"
    echo "    ${C_LIME}Bit Depth:${NC}      ${C_LIGHT_GREEN}${FLAC_BIT_DEPTH}-bit${NC}"
    echo "    ${C_LIME}Compresión:${NC}     ${C_LIGHT_GREEN}Nivel ${FLAC_COMPRESSION}${NC}"
    echo ""
    
    if [[ $DRY_RUN -eq 0 ]]; then
        if ! confirmar "¿Convertir ${#audio_files[@]} archivos a FLAC ${sr_display}/${FLAC_BIT_DEPTH}-bit?"; then
            print_msg warning "Conversión cancelada."
            return 0
        fi
    fi
    
    mkdir -p "$output_dirname"
    
    local success_count=0
    local fail_count=0
    local total=${#audio_files[@]}
    local current=0
    
    print_msg header "Iniciando conversión a FLAC ${sr_display}/${FLAC_BIT_DEPTH}-bit"
    echo "    ${C_MEDIUM_GREEN}💡 Presiona Ctrl+C en cualquier momento para cancelar${NC}"
    echo ""
    
    for audio_file in "${audio_files[@]}"; do
        # Verificar interrupción
        if [[ $INTERRUPTED -eq 1 ]]; then
            print_msg warning "Conversión interrumpida por el usuario"
            break
        fi
        
        ((current++))
        echo "\n${BOLD}[${current}/${total}]${NC} ${audio_file:t}"
        
        if convert_to_flac "$audio_file" "$output_dirname"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
    done
    
    echo ""
    print_msg header "Conversión FLAC Completada"
    echo ""
    echo "    ${C_LIGHT_GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo "    ${C_LIGHT_GREEN}║  ${C_LIME}ARCHIVOS FLAC DE ALTA RESOLUCIÓN CREADOS${C_LIGHT_GREEN}              ║${NC}"
    echo "    ${C_LIGHT_GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "    ${C_LIGHT_GREEN}Exitosos:${NC} ${C_LIME}$success_count${NC}"
    [[ $fail_count -gt 0 ]] && echo "    ${C_DARK_GREEN}Fallidos:${NC} ${C_YELLOW_GREEN}$fail_count${NC}"
    echo "    ${C_LIME}Formato:${NC}  ${C_LIGHT_GREEN}FLAC ${sr_display}/${FLAC_BIT_DEPTH}-bit${NC}"
    echo "    ${C_LIME}Salida:${NC}   ${C_LIGHT_GREEN}${SOURCE_DIR}/${output_dirname}/${NC}"
    echo ""
    echo "    ${C_YELLOW_GREEN}🎵 Archivos de alta resolución ideales para:${NC}"
    echo "    ${C_MEDIUM_GREEN}   • Producción musical y masterización${NC}"
    echo "    ${C_MEDIUM_GREEN}   • Archivo de audio sin pérdida${NC}"
    echo "    ${C_MEDIUM_GREEN}   • Reproductores Hi-Fi y DACs${NC}"
    echo ""
    
    # Preguntar si es música devocional sikh para conversión a 432Hz
    if [[ $DRY_RUN -eq 0 && $success_count -gt 0 ]]; then
        echo ""
        echo "    ${C_LIME}╔════════════════════════════════════════════════════════════╗${NC}"
        echo "    ${C_LIME}║${NC}  ${C_YELLOW_GREEN}🕉️  MÚSICA DEVOCIONAL SIKH 🕉️${NC}                              ${C_LIME}║${NC}"
        echo "    ${C_LIME}╚════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo "    ${C_MEDIUM_GREEN}¿Se trata de música devocional sikh (Kirtan, Shabad, etc.)?${NC}"
        echo "    ${C_DARK_FOREST}Si es así, puedes convertir estos archivos FLAC a 432Hz${NC}"
        echo "    ${C_DARK_FOREST}(frecuencia sanadora y armoniosa para música espiritual)${NC}"
        echo ""
        
        if confirmar "¿Convertir los archivos FLAC a 432Hz?"; then
            echo ""
            # Convertir los archivos FLAC recién creados a 432Hz
            process_flac_to_432hz "${SOURCE_DIR}/${output_dirname}" "flac_432hz"
        else
            echo ""
            print_msg info "Conversión a 432Hz omitida. Los archivos FLAC permanecen en 440Hz."
        fi
    fi
    echo ""
}

# ============================================================================
# MENÚ INTERACTIVO
# ============================================================================

show_menu() {
    echo ""
    echo "${C_DARK_FOREST}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo "${C_DARK_FOREST}║${NC}  ${BOLD}${C_LIME}🎵 MENÚ DE CONVERSIÓN DE AUDIO/VIDEO${NC}                ${C_DARK_FOREST}║${NC}"
    echo "${C_DARK_FOREST}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  ${C_LIME}1)${NC} M4A → MP4   ${C_MEDIUM_GREEN}(video con imagen para YouTube)${NC}"
    echo "  ${C_LIME}2)${NC} WAV → M4A   ${C_MEDIUM_GREEN}(compresión AAC alta calidad)${NC}"
    echo "  ${C_LIME}3)${NC} FLAC → M4A  ${C_MEDIUM_GREEN}(compresión AAC alta calidad)${NC}"
    echo ""
    echo "  ${BOLD}${C_YELLOW_GREEN}4)${NC} ${C_YELLOW_GREEN}ÁLBUM → MP3 UNIFICADO${NC}  ${C_LIGHT_GREEN}(para registro de derechos de autor)${NC}"
    echo "     ${C_MEDIUM_GREEN}Une todos los archivos de audio en UN SOLO MP3${NC}"
    echo ""
    echo "  ${BOLD}${C_LIGHT_GREEN}5)${NC} ${C_LIGHT_GREEN}AUDIO → FLAC HI-RES${NC}  ${C_LIME}(96kHz/24-bit alta resolución)${NC}"
    echo "     ${C_MEDIUM_GREEN}Convierte cualquier audio a FLAC sin pérdida${NC}"
    echo ""
    echo "  ${C_DARK_FOREST}h)${NC} Ayuda"
    echo "  ${C_DARK_FOREST}q)${NC} Salir"
    echo ""
    echo -n "${C_LIME}▶ Selecciona una opción: ${NC}"
}

# ============================================================================
# PARSEO DE ARGUMENTOS
# ============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -f|--file)
                SINGLE_FILE="$2"
                shift 2
                ;;
            -o|--origen)
                # Carpeta ORIGEN donde están los archivos a convertir
                SOURCE_DIR="$2"
                shift 2
                ;;
            -d|--destino)
                # Carpeta DESTINO donde guardar los archivos convertidos
                DEST_DIR="$2"
                shift 2
                ;;
            -m|--mode)
                MODE="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=1
                shift
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            --cbr)
                QUALITY_MODE="cbr"
                CBR_BITRATE="$2"
                shift 2
                ;;
            --vbr)
                QUALITY_MODE="vbr"
                VBR_QUALITY="$2"
                shift 2
                ;;
            --silence)
                # Segundos de silencio entre pistas (modo 4)
                SILENCE_DURATION="$2"
                shift 2
                ;;
            --album)
                # Nombre del archivo MP3 de salida (modo 4)
                ALBUM_NAME="$2"
                shift 2
                ;;
            --mp3-bitrate)
                # Bitrate del MP3 final (modo 4)
                MP3_BITRATE="$2"
                shift 2
                ;;
            --sample-rate)
                # Sample rate para FLAC (modo 5)
                FLAC_SAMPLE_RATE="$2"
                shift 2
                ;;
            --bit-depth)
                # Bit depth para FLAC (modo 5)
                FLAC_BIT_DEPTH="$2"
                shift 2
                ;;
            --flac-level)
                # Nivel de compresión FLAC (modo 5)
                FLAC_COMPRESSION="$2"
                shift 2
                ;;
            *)
                print_msg error "Opción desconocida: $1"
                echo "Usa -h para ver la ayuda."
                exit 1
                ;;
        esac
    done
}

# ============================================================================
# PUNTO DE ENTRADA
# ============================================================================

main() {
    parse_args "$@"
    
    # Verificar dependencias
    if ! check_dependencies; then
        exit 1
    fi
    
    [[ $DRY_RUN -eq 1 ]] && print_msg warning "Modo DRY-RUN: No se realizarán conversiones"
    
    # Si se especificó archivo individual
    if [[ -n "$SINGLE_FILE" ]]; then
        if [[ ! -f "$SINGLE_FILE" ]]; then
            print_msg error "Archivo no encontrado: $SINGLE_FILE"
            exit 1
        fi
        
        SOURCE_DIR=$(dirname "$SINGLE_FILE")
        local ext="${SINGLE_FILE:e:l}"
        
        case "$ext" in
            m4a)
                [[ -z "$MODE" ]] && MODE=1
                if [[ "$MODE" == "1" ]]; then
                    cd "$SOURCE_DIR" || exit 1
                    local cover=""
                    for img in cover.png cover.jpg Cover.png Cover.jpg; do
                        [[ -f "$img" ]] && cover="$img" && break
                    done
                    if [[ -z "$cover" ]]; then
                        print_msg error "No se encontró cover.png/jpg en: $SOURCE_DIR"
                        exit 1
                    fi
                    mkdir -p "${DEST_DIR:-converted_videos}"
                    convert_m4a_to_mp4 "$SINGLE_FILE" "${DEST_DIR:-converted_videos}" "$cover"
                fi
                ;;
            wav|flac|mp3|aiff|aif|ogg|wma|opus)
                if [[ "$MODE" == "5" ]]; then
                    mkdir -p "${DEST_DIR:-flac_hires}"
                    convert_to_flac "$SINGLE_FILE" "${DEST_DIR:-flac_hires}"
                else
                    mkdir -p "${DEST_DIR:-converted}"
                    convert_to_m4a "$SINGLE_FILE" "${DEST_DIR:-converted}"
                fi
                ;;
            *)
                print_msg error "Formato no soportado: $ext"
                exit 1
                ;;
        esac
        exit 0
    fi
    
    # Si se especificó modo por línea de comandos
    if [[ -n "$MODE" ]]; then
        if ! select_folder; then
            exit 1
        fi
        
        case "$MODE" in
            1) process_m4a_to_mp4 "${DEST_DIR:-converted_videos}" ;;
            2) process_audio_to_m4a "wav" "${DEST_DIR:-converted}" ;;
            3) process_audio_to_m4a "flac" "${DEST_DIR:-converted}" ;;
            4) process_album_to_unified_mp3 "${DEST_DIR:-unified}" ;;
            5) process_audio_to_flac "${DEST_DIR:-flac_hires}" ;;
            *)
                print_msg error "Modo inválido: $MODE"
                exit 1
                ;;
        esac
        exit 0
    fi
    
    # Modo interactivo
    while true; do
        show_menu
        read -r mode
        echo ""
        
        # Resetear variables para permitir selección de nueva carpeta
        SOURCE_DIR=""
        DEST_DIR=""
        ALBUM_NAME=""
        
        case "$mode" in
            1)
                if select_folder; then
                    echo -n "${C_YELLOW_GREEN}Nombre del directorio de salida (Enter=converted_videos): ${NC}"
                    read -r output_dirname
                    process_m4a_to_mp4 "${output_dirname:-converted_videos}"
                fi
                ;;
            2)
                if select_folder; then
                    echo -n "${C_YELLOW_GREEN}Nombre del directorio de salida (Enter=converted): ${NC}"
                    read -r output_dirname
                    process_audio_to_m4a "wav" "${output_dirname:-converted}"
                fi
                ;;
            3)
                if select_folder; then
                    echo -n "${C_YELLOW_GREEN}Nombre del directorio de salida (Enter=converted): ${NC}"
                    read -r output_dirname
                    process_audio_to_m4a "flac" "${output_dirname:-converted}"
                fi
                ;;
            4)
                if select_folder; then
                    echo ""
                    echo "${C_LIME}═══ Configuración del Álbum Unificado ═══${NC}"
                    echo ""
                    echo -n "${C_YELLOW_GREEN}Segundos de silencio entre pistas (Enter=2): ${NC}"
                    read -r silence_input
                    [[ -n "$silence_input" ]] && SILENCE_DURATION="$silence_input"
                    
                    echo -n "${C_YELLOW_GREEN}Nombre del archivo MP3 (Enter=nombre de carpeta): ${NC}"
                    read -r album_input
                    [[ -n "$album_input" ]] && ALBUM_NAME="$album_input"
                    
                    echo -n "${C_YELLOW_GREEN}Bitrate MP3 (Enter=320k): ${NC}"
                    read -r bitrate_input
                    [[ -n "$bitrate_input" ]] && MP3_BITRATE="$bitrate_input"
                    
                    echo -n "${C_YELLOW_GREEN}Nombre del directorio de salida (Enter=unified): ${NC}"
                    read -r output_dirname
                    
                    process_album_to_unified_mp3 "${output_dirname:-unified}"
                fi
                ;;
            5)
                if select_folder; then
                    echo ""
                    echo "${C_LIME}═══ Configuración FLAC Alta Resolución ═══${NC}"
                    echo ""
                    echo "  ${C_MEDIUM_GREEN}Sample rates disponibles:${NC}"
                    echo "    ${C_LIGHT_GREEN}96000${NC} - 96kHz (máxima calidad, archivos grandes)"
                    echo "    ${C_LIGHT_GREEN}48000${NC} - 48kHz (estudio profesional)"
                    echo "    ${C_LIGHT_GREEN}44100${NC} - 44.1kHz (calidad CD)"
                    echo ""
                    echo -n "${C_YELLOW_GREEN}Sample rate (Enter=96000): ${NC}"
                    read -r sr_input
                    [[ -n "$sr_input" ]] && FLAC_SAMPLE_RATE="$sr_input"
                    
                    echo ""
                    echo -n "${C_YELLOW_GREEN}Bit depth - 24 o 16 (Enter=24): ${NC}"
                    read -r bd_input
                    [[ -n "$bd_input" ]] && FLAC_BIT_DEPTH="$bd_input"
                    
                    echo ""
                    echo -n "${C_YELLOW_GREEN}Nivel compresión 0-12 (Enter=8): ${NC}"
                    read -r comp_input
                    [[ -n "$comp_input" ]] && FLAC_COMPRESSION="$comp_input"
                    
                    echo ""
                    echo -n "${C_YELLOW_GREEN}Nombre del directorio de salida (Enter=flac_hires): ${NC}"
                    read -r output_dirname
                    
                    process_audio_to_flac "${output_dirname:-flac_hires}"
                fi
                ;;
            h|H)
                show_help
                ;;
            q|Q)
                print_msg info "¡Hasta luego!"
                exit 0
                ;;
            *)
                print_msg error "Opción inválida: $mode"
                ;;
        esac
        
        # Resetear variables después de cada operación
        SOURCE_DIR=""
        DEST_DIR=""
        ALBUM_NAME=""
        SILENCE_DURATION=2
        MP3_BITRATE="320k"
        FLAC_SAMPLE_RATE=96000
        FLAC_BIT_DEPTH=24
        FLAC_COMPRESSION=8
        
        echo ""
        echo -n "${C_MEDIUM_GREEN}Presiona Enter para continuar...${NC}"
        read -r
    done
}

# Ejecutar
main "$@"
