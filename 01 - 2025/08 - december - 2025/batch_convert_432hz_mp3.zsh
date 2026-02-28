#!/usr/bin/env zsh
#
# Script de automatización para conversión masiva a MP3 432Hz usando preset Ditto Pro
# Procesa todos los subdirectorios de audio excluyendo '2022'
#

set -e  # Salir si hay error

# ============================================================================
# CONFIGURACIÓN
# ============================================================================

SOURCE_BASE="/Volumes/TOSHIBA EXT/2026/00 - bakcup spektra/Kirtan Teg Singh/discography"
DEST_BASE="/Volumes/Backup II - mid 2025/2026/01 - Kirtant Teg Singh"
EXCLUDE_DIR="2022"
PYTHON_SCRIPT="06_audio_converter.py"

# Obtener la ruta absoluta del script Python (está en el mismo directorio que este script)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PYTHON_SCRIPT_PATH="${SCRIPT_DIR}/${PYTHON_SCRIPT}"

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# FUNCIONES
# ============================================================================

print_header() {
    echo ""
    echo "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo "${BLUE}  $1${NC}"
    echo "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_info() {
    echo "${GREEN}ℹ${NC}  $1"
}

print_success() {
    echo "${GREEN}✓${NC}  $1"
}

print_error() {
    echo "${RED}✗${NC}  $1" >&2
}

print_warning() {
    echo "${YELLOW}⚠${NC}  $1"
}

# Verificar que el script Python existe
check_python_script() {
    if [[ ! -f "$PYTHON_SCRIPT_PATH" ]]; then
        print_error "No se encontró el script Python: $PYTHON_SCRIPT_PATH"
        exit 1
    fi
    print_success "Script Python encontrado: $PYTHON_SCRIPT_PATH"
}

# Verificar que las rutas base existen
check_paths() {
    if [[ ! -d "$SOURCE_BASE" ]]; then
        print_error "El directorio fuente no existe: $SOURCE_BASE"
        exit 1
    fi
    
    if [[ ! -d "$DEST_BASE" ]]; then
        print_warning "El directorio destino no existe. Creándolo..."
        mkdir -p "$DEST_BASE" || {
            print_error "No se pudo crear el directorio destino: $DEST_BASE"
            exit 1
        }
        print_success "Directorio destino creado: $DEST_BASE"
    fi
}

# Verificar que expect está instalado
check_expect() {
    if ! command -v expect &> /dev/null; then
        print_error "expect no está instalado. Instálalo con: brew install expect"
        exit 1
    fi
}

# Procesar un directorio individual
process_directory() {
    local source_dir="$1"
    local dest_dir="$2"
    local dir_name="$3"
    
    local log_file="/tmp/batch_convert_${dir_name//\//_}_$$.log"
    local start_time=$(date +%s)
    
    print_header "Procesando: $dir_name"
    print_info "Origen: $source_dir"
    print_info "Destino: $dest_dir"
    print_info "Log: $log_file"
    echo ""
    
    # Crear directorio de destino si no existe
    mkdir -p "$dest_dir" || {
        print_error "No se pudo crear el directorio destino: $dest_dir"
        return 1
    }
    
    # Contar archivos de audio en el directorio fuente
    local audio_count=$(find "$source_dir" -maxdepth 1 \( -iname "*.flac" -o -iname "*.wav" -o -iname "*.m4a" -o -iname "*.mp3" \) 2>/dev/null | wc -l | tr -d ' ')
    if [[ $audio_count -eq 0 ]]; then
        print_warning "No se encontraron archivos de audio en: $dir_name"
        return 1
    fi
    print_info "Archivos de audio encontrados: $audio_count"
    echo ""
    
    # Crear script expect temporal
    local expect_script=$(mktemp /tmp/audio_converter_expect.XXXXXX)
    
    # Crear script expect con variables expandidas por zsh
    cat > "$expect_script" <<EXPECT_EOF
#!/usr/bin/expect -f
set timeout 600
set source_dir "$source_dir"
set dest_dir "$dest_dir"
set python_script "$PYTHON_SCRIPT_PATH"

# Configuración para mejor manejo de output
log_user 1
exp_internal 0

# Configurar para que el output se muestre inmediatamente
match_max 10000

# Spawn del proceso Python
spawn -noecho python3 \$python_script

# Esperar menú principal y seleccionar opción 7
expect {
    "Selecciona una opción:" {
        puts "PROGRESO: Seleccionando opción 7 (MP3 432Hz)"
        send "7\r"
        expect {
            eof {
                puts "ERROR: El proceso terminó inesperadamente"
                exit 1
            }
            timeout {
                # Continuar
            }
        }
    }
    timeout {
        puts "ERROR: Timeout esperando menú principal"
        exit 1
    }
    eof {
        puts "ERROR: El proceso terminó antes de mostrar el menú"
        exit 1
    }
}

# Seleccionar carpeta fuente
expect {
    "Pega la ruta de la carpeta (o Enter para cancelar):" {
        puts "PROGRESO: Enviando ruta de carpeta fuente"
        send "\$source_dir\r"
    }
    timeout {
        puts "ERROR: Timeout esperando selección de carpeta fuente"
        exit 1
    }
    eof {
        puts "ERROR: El proceso terminó inesperadamente"
        exit 1
    }
}

# Esperar confirmación de carpeta fuente
expect {
    "Carpeta seleccionada:" {
        # Continuar
    }
    "Operación cancelada" {
        puts "ERROR: Operación cancelada al seleccionar carpeta fuente"
        exit 1
    }
    timeout {
        puts "ERROR: Timeout esperando confirmación de carpeta fuente"
        exit 1
    }
}

# Seleccionar carpeta destino
expect {
    "Pega la ruta de la carpeta de destino (Enter=directorio actual):" {
        puts "PROGRESO: Enviando ruta de carpeta destino"
        send "\$dest_dir\r"
    }
    timeout {
        puts "ERROR: Timeout esperando selección de carpeta destino"
        exit 1
    }
    eof {
        puts "ERROR: El proceso terminó inesperadamente"
        exit 1
    }
}

# Esperar confirmación de carpeta destino
expect {
    "Carpeta de destino seleccionada:" {
        # Continuar
    }
    "Usando directorio actual:" {
        # Continuar
    }
    timeout {
        puts "ERROR: Timeout esperando confirmación de carpeta destino"
        exit 1
    }
}

# Seleccionar archivos (Enter para todos)
expect {
    "Selecciona archivo(s)" {
        send "\r"
    }
    timeout {
        puts "ERROR: Timeout esperando selección de archivos"
        exit 1
    }
}

# Esperar confirmación de archivos seleccionados
expect {
    "Procesando todos los archivos" {
        # Continuar
    }
    "Archivos seleccionados:" {
        # Continuar
    }
    timeout {
        puts "ERROR: Timeout esperando confirmación de archivos"
        exit 1
    }
}

# Usar preset Ditto Pro
expect {
    "¿Usar preset Ditto Pro? (configuración automática)" {
        puts "PROGRESO: Seleccionando preset Ditto Pro"
        send "s\r"
    }
    timeout {
        puts "ERROR: Timeout esperando pregunta de preset Ditto Pro"
        exit 1
    }
}

# Esperar confirmación de preset
expect {
    "Preset Ditto Pro seleccionado" {
        # Continuar
    }
    timeout {
        puts "ERROR: Timeout esperando confirmación de preset"
        exit 1
    }
}

# Confirmar configuración del preset
expect {
    "¿Continuar con esta configuración?" {
        send "s\r"
    }
    timeout {
        puts "ERROR: Timeout esperando confirmación de configuración"
        exit 1
    }
}

# Esperar tabla de estimaciones o manejo de archivos existentes
# Usar expect con múltiples patrones y exp_continue para manejar el flujo
expect {
    "Se encontraron" {
        puts "PROGRESO: Archivos existentes detectados, esperando prompt..."
        exp_continue
    }
    -re "Selecciona opción.*1-4.*:" {
        puts "PROGRESO: Enviando opción 2 (saltar archivos existentes)"
        send "2\r"
        exp_continue
    }
    "Se saltarán" {
        puts "PROGRESO: Archivos existentes serán saltados"
        exp_continue
    }
    "¿Convertir" {
        puts "PROGRESO: Confirmando conversión"
        send "s\r"
    }
    eof {
        puts "ERROR: El proceso terminó inesperadamente antes de la conversión"
        exit 1
    }
    timeout {
        puts "ERROR: Timeout esperando confirmación final"
        exit 1
    }
}

# Esperar a que termine la conversión (puede tardar mucho)
# Monitorear progreso mientras procesa
expect {
    "Convirtiendo:" {
        # Archivo siendo procesado - loguear y continuar
        puts "PROGRESO: Procesando archivo..."
        exp_continue
    }
    "✓" {
        # Archivo completado exitosamente
        puts "PROGRESO: Archivo completado"
        exp_continue
    }
    "✗" {
        # Error en archivo
        puts "ERROR: Error al procesar archivo"
        exp_continue
    }
    "Conversión a 432Hz MP3 Completada" {
        puts "PROGRESO: Conversión completada"
        # Continuar
    }
    "Exitosos:" {
        puts "PROGRESO: Mostrando resumen"
        # Continuar
    }
    timeout {
        # Verificar si ffmpeg sigue corriendo
        if {[catch {exec pgrep -f "ffmpeg.*432Hz"} result] == 0} {
            puts "PROGRESO: FFmpeg aún procesando, esperando..."
            exp_continue
        } else {
            puts "WARNING: Timeout esperando finalización"
        }
    }
}

# Esperar mensaje de "Presiona Enter para continuar"
expect {
    "Presiona Enter para continuar" {
        send "\r"
    }
    timeout {
        # Puede que ya haya terminado
    }
}

# Volver al menú y salir
expect {
    "Selecciona una opción:" {
        send "q\r"
    }
    timeout {
        # Puede que ya haya salido
    }
}

# Esperar mensaje de despedida
expect {
    "¡Hasta luego!" {
        # Salir exitosamente
    }
    eof {
        # Salir exitosamente
    }
    timeout {
        # Salir de todas formas
    }
}

exit 0
EXPECT_EOF

    chmod +x "$expect_script"
    
    # Función para monitorear ffmpeg en segundo plano
    monitor_ffmpeg() {
        while true; do
            if pgrep -f "ffmpeg.*432Hz" > /dev/null; then
                local ffmpeg_pid=$(pgrep -f "ffmpeg.*432Hz" | head -1)
                local cpu=$(ps -p $ffmpeg_pid -o %cpu= 2>/dev/null | tr -d ' ')
                local mem=$(ps -p $ffmpeg_pid -o %mem= 2>/dev/null | tr -d ' ')
                if [[ -n "$cpu" ]]; then
                    echo "[$(date +%H:%M:%S)] 🎵 FFmpeg activo - CPU: ${cpu}% | Mem: ${mem}%" >> "$log_file"
                fi
            fi
            sleep 5
        done
    }
    
    # Iniciar monitoreo de ffmpeg en segundo plano
    monitor_ffmpeg &
    local monitor_pid=$!
    
    # Ejecutar expect con logging detallado
    print_info "Iniciando conversión... (ver progreso en: $log_file)"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Iniciando procesamiento de: $dir_name" >> "$log_file"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Origen: $source_dir" >> "$log_file"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Destino: $dest_dir" >> "$log_file"
    echo "" >> "$log_file"
    
    # Ejecutar expect redirigiendo todo el output al log
    # No usar stdbuf debido a problemas de compatibilidad de arquitectura
    expect "$expect_script" >> "$log_file" 2>&1
    local expect_exit=$?
    
    if [[ $expect_exit -eq 0 ]]; then
        # Detener monitoreo
        kill $monitor_pid 2>/dev/null
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        local duration_min=$((duration / 60))
        local duration_sec=$((duration % 60))
        
        # Verificar si hubo errores en el output
        if grep -q "ERROR:" "$log_file" 2>/dev/null; then
            print_error "Error detectado en el procesamiento de: $dir_name"
            print_info "Revisa el log: $log_file"
            rm -f "$expect_script"
            return 1
        else
            # Contar archivos MP3 creados
            local mp3_count=$(find "$dest_dir" -maxdepth 1 -name "*_432Hz.mp3" 2>/dev/null | wc -l | tr -d ' ')
            print_success "Directorio procesado exitosamente: $dir_name"
            print_info "Tiempo transcurrido: ${duration_min}m ${duration_sec}s"
            print_info "Archivos MP3 creados: $mp3_count"
            print_info "Log completo: $log_file"
            rm -f "$expect_script"
            return 0
        fi
    else
        # Detener monitoreo
        kill $monitor_pid 2>/dev/null
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        print_error "Error al ejecutar expect para: $dir_name"
        print_error "Tiempo transcurrido antes del error: ${duration}s"
        print_info "Revisa el log completo: $log_file"
        print_info "Últimas líneas del log:"
        tail -10 "$log_file" 2>/dev/null | sed 's/^/  /'
        rm -f "$expect_script"
        return 1
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    print_header "Conversión Masiva a MP3 432Hz - Preset Ditto Pro"
    
    # Verificaciones
    check_expect
    check_python_script
    check_paths
    
    print_info "Directorio fuente: $SOURCE_BASE"
    print_info "Directorio destino: $DEST_BASE"
    print_info "Excluyendo: $EXCLUDE_DIR"
    echo ""
    
    # Encontrar todos los subdirectorios
    local dirs=()
    for dir in "$SOURCE_BASE"/*; do
        if [[ -d "$dir" ]]; then
            local dir_name=$(basename "$dir")
            if [[ "$dir_name" != "$EXCLUDE_DIR" ]]; then
                dirs+=("$dir")
            fi
        fi
    done
    
    if [[ ${#dirs[@]} -eq 0 ]]; then
        print_warning "No se encontraron subdirectorios para procesar"
        exit 0
    fi
    
    print_info "Se encontraron ${#dirs[@]} directorio(s) para procesar:"
    for dir in "${dirs[@]}"; do
        echo "  • $(basename "$dir")"
    done
    echo ""
    
    # Confirmar antes de proceder
    read "?¿Continuar con la conversión? (s/n): " confirm
    if [[ "$confirm" != "s" && "$confirm" != "S" && "$confirm" != "y" && "$confirm" != "Y" ]]; then
        print_warning "Operación cancelada"
        exit 0
    fi
    
    echo ""
    
    # Procesar cada directorio
    local success_count=0
    local fail_count=0
    local total=${#dirs[@]}
    local current=0
    local overall_start_time=$(date +%s)
    
    for source_dir in "${dirs[@]}"; do
        current=$((current + 1))
        local dir_name=$(basename "$source_dir")
        local dest_dir="${DEST_BASE}/${dir_name}"
        
        echo ""
        print_info "[$current/$total] Procesando: $dir_name"
        print_info "Hora de inicio: $(date '+%H:%M:%S')"
        echo ""
        
        if process_directory "$source_dir" "$dest_dir" "$dir_name"; then
            success_count=$((success_count + 1))
            print_success "✓ Completado: $dir_name ($current/$total)"
        else
            fail_count=$((fail_count + 1))
            print_error "✗ Fallido: $dir_name ($current/$total)"
        fi
        
        # Mostrar progreso acumulado
        local elapsed=$(( $(date +%s) - overall_start_time ))
        local elapsed_min=$((elapsed / 60))
        local avg_time_per_dir=$((elapsed / current))
        local remaining_dirs=$((total - current))
        local estimated_remaining=$((avg_time_per_dir * remaining_dirs))
        local est_min=$((estimated_remaining / 60))
        
        echo ""
        print_info "Progreso: $current/$total directorios"
        print_info "Tiempo transcurrido: ${elapsed_min} minutos"
        if [[ $remaining_dirs -gt 0 ]]; then
            print_info "Tiempo estimado restante: ~${est_min} minutos"
        fi
        echo ""
        
        # Pequeña pausa entre directorios
        sleep 2
    done
    
    # Resumen final
    local overall_end_time=$(date +%s)
    local total_duration=$((overall_end_time - overall_start_time))
    local total_hours=$((total_duration / 3600))
    local total_min=$(((total_duration % 3600) / 60))
    local total_sec=$((total_duration % 60))
    
    echo ""
    print_header "Procesamiento Completado"
    print_success "Exitosos: $success_count"
    if [[ $fail_count -gt 0 ]]; then
        print_error "Fallidos: $fail_count"
    fi
    print_info "Total procesados: $total"
    if [[ $total_hours -gt 0 ]]; then
        print_info "Tiempo total: ${total_hours}h ${total_min}m ${total_sec}s"
    else
        print_info "Tiempo total: ${total_min}m ${total_sec}s"
    fi
    
    # Mostrar ubicación de logs
    echo ""
    print_info "Logs individuales guardados en: /tmp/batch_convert_*.log"
    print_info "Puedes revisarlos con: ls -lht /tmp/batch_convert_*.log"
    echo ""
}

# Ejecutar main
main "$@"

