#!/usr/bin/env zsh
set -euo pipefail

# ============================================================================
# Script Verification Tool v2.0 - Modular con Categorías
# ============================================================================
# Verificación de Scripts del Repositorio organizada por categorías
# Basado en las categorías del README.md
# ============================================================================

# Colores
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Directorio raíz del repositorio
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")" && pwd)}"

# ============================================================================
# DEFINICIÓN DE CATEGORÍAS (basadas en README.md)
# ============================================================================

declare -A CATEGORIES

# Conversión de Audio/Video
CATEGORIES["audio_video"]="Conversión de Audio/Video"
CATEGORIES["audio_video_paths"]="
01 - 2025/08 - december - 2025/06_m4a_to_mp4.zsh
01 - 2025/06 - October - 2025/wav_to_m4a.zsh
01 - 2025/07 - november - 2025/12_m4a_to_mp3.zsh
01 - 2025/07 - november - 2025/10_flac_to_mp4_converter.zsh
01 - 2025/08 - december - 2025/01_m4a_mp3_flac_tags.zsh
01 - 2025/08 - december - 2025/02_tags_template_generator.zsh
01 - 2025/07 - november - 2025/11_add_img_to_mp3.zsh
"

# Conversión de Documentos
CATEGORIES["documentos"]="Conversión de Documentos"
CATEGORIES["documentos_paths"]="
02 - 2026/01 - enero/02 - md_to_pdf_converter/md_to_pdf.py
02 - 2026/01 - enero/02 - md_to_pdf_converter/md_to_pdf_auto.py
02 - 2026/01 - enero/02 - md_to_pdf_converter/md_to_pdf_pandoc.py
02 - 2026/01 - enero/02 - md_to_pdf_converter/md_to_pdf_reportlab.py
02 - 2026/01 - enero/02 - md_to_pdf_converter/md_to_pdf_simple.py
02 - 2026/01 - enero/02 - md_to_pdf_converter/md_to_pdf_weasyprint.py
01 - 2025/08 - december - 2025/12_wiki_to_pdf.zsh
01 - 2025/08 - december - 2025/13_translate_pdf/translate_pdf.py
01 - 2025/08 - december - 2025/13_translate_pdf/translate_pdf_cli.py
01 - 2025/07 - november - 2025/01 - HTML to PDF/html_to_pdf_converter.py
01 - 2025/07 - november - 2025/01 - HTML to PDF/setup_project.sh
01 - 2025/07 - november - 2025/01 - HTML to PDF/setup_weasyprint_mac_intel_silicon.zsh
"

# Gestión y Monitoreo de Disco
CATEGORIES["disco"]="Gestión y Monitoreo de Disco"
CATEGORIES["disco_paths"]="
01 - 2025/08 - december - 2025/07_disk_guard.zsh
01 - 2025/01 - Junio - 2025/19 de junio - 2025/01_disk_guard.zsh
01 - 2025/01 - Junio - 2025/19 de junio - 2025/02_disk_guard_plus.zsh
01 - 2025/01 - Junio - 2025/19 de junio - 2025/03_disk_guard_daemon.zsh
01 - 2025/01 - Junio - 2025/19 de junio - 2025/04_auditor_disco_macos.zsh
01 - 2025/08 - december - 2025/08_disk_scanner.sh
01 - 2025/01 - Junio - 2025/30 de Junio - 2025/01_registro_espacio_libre.zsh
01 - 2025/01 - Junio - 2025/30 de Junio - 2025/02_rastreador_cambios_disco.zsh
01 - 2025/01 - Junio - 2025/30 de Junio - 2025/03_vigia_escritura_fisica.zsh
01 - 2025/01 - Junio - 2025/30 de Junio - 2025/04_informe_volumenes.zsh
01 - 2025/01 - Junio - 2025/30 de Junio - 2025/05_bloqueo_indexado_volumenes.zsh
01 - 2025/08 - december - 2025/09_stop_the_bleeding.sh
01 - 2025/01 - Junio - 2025/20 de Junio - 2025/03_disk_guardian_reforzado_clean.sh
"

# Monitoreo de Memoria
CATEGORIES["memoria"]="Monitoreo de Memoria"
CATEGORIES["memoria_paths"]="
01 - 2025/05 - September 2025/memory_pressure_monitor.zsh
01 - 2025/05 - September 2025/memory_pressure_monitor_advanced_notification_features.zsh
01 - 2025/05 - September 2025/memory_pressure_monitor_notification_center.zsh
01 - 2025/05 - September 2025/memory_pressure_monitor_with_cron.zsh
01 - 2025/05 - September 2025/memory_pressure_simulator.zsh
"

# Herramientas de Sistema macOS
CATEGORIES["macos"]="Herramientas de Sistema macOS"
CATEGORIES["macos_paths"]="
01 - 2025/04 - August - 2025/01 - put back from trash.zsh
01 - 2025/04 - August - 2025/02 - restore preview.zsh
01 - 2025/04 - August - 2025/03 - undo git commit.zsh
01 - 2025/04 - August - 2025/04 - stop icloud automatic downloads.zsh
01 - 2025/01 - Junio - 2025/19 de junio - 2025/05_limpiar_cryptex.zsh
01 - 2025/01 - Junio - 2025/19 de junio - 2025/06_revisar_purgeable_finder.zsh
01 - 2025/01 - Junio - 2025/19 de junio - 2025/07_bloquear_tethering_riesgoso.zsh
01 - 2025/01 - Junio - 2025/29 de junio - 2025/01_uninstall_cleanmymac.zsh
01 - 2025/01 - Junio - 2025/29 de junio - 2025/02_liberar_snapshot.zsh
01 - 2025/08 - december - 2025/10_remove_macOS_installer_leftovers.sh
01 - 2025/07 - november - 2025/13_install_sequoia.sh
01 - 2025/07 - november - 2025/14_upgrade_legacy_macs.sh
01 - 2025/07 - november - 2025/15_from_lion_to_el_capitan.sh
01 - 2025/07 - november - 2025/16_from_el_capitan_to_high_sierra.sh
"

# Recuperación de Datos
CATEGORIES["recuperacion"]="Recuperación de Datos"
CATEGORIES["recuperacion_paths"]="
01 - 2025/07 - november - 2025/01_data_recovery.py
01 - 2025/07 - november - 2025/02_data_recovery_installer.py
"

# Herramientas Matemáticas/Educativas
CATEGORIES["matematicas"]="Herramientas Matemáticas/Educativas"
CATEGORIES["matematicas_paths"]="
01 - 2025/07 - november - 2025/05_teoria_de_conjuntos.py
01 - 2025/07 - november - 2025/06_el_complemento_de_un_conjunto.py
01 - 2025/07 - november - 2025/07_union_de_conjuntos.py
01 - 2025/07 - november - 2025/08_interseccion_de_conjuntos.py
01 - 2025/07 - november - 2025/09_disyuncion_diferencia_y_diferencia_simetrica.py
01 - 2025/07 - november - 2025/04_tabla_pt100.py
aemaeth/01_trig_func.py
"

# Herramientas de Git
CATEGORIES["git"]="Herramientas de Git"
CATEGORIES["git_paths"]="
01 - 2025/07 - november - 2025/18_observar_cambios_en_commits.sh
02 - 2026/01 - enero/01 - reduce git repo size/clean-git-history.sh
"

# Build Scripts
CATEGORIES["build"]="Build Scripts"
CATEGORIES["build_paths"]="
01 - 2025/05 - September 2025/01_build_flint_w_dep.zsh
01 - 2025/05 - September 2025/02_build_flint_w_dep_http2_framing.zsh
01 - 2025/05 - September 2025/03_build_flint_w_dep_http2_framing_mac_os_only.zsh
01 - 2025/05 - September 2025/04_build_flint_w_dep_http2_framing_apple_silicon_only.zsh
01 - 2025/05 - September 2025/05_build_flint_w_dep_http2_framing_apple_silicon_only.zsh
01 - 2025/05 - September 2025/06_build_flint_w_dep_http2_framing_apple_silicon_only.zsh
01 - 2025/05 - September 2025/07_build_flint_w_dep_http2_framing_apple_silicon_only.zsh
01 - 2025/05 - September 2025/08_build_flint_w_dep_http2_framing_apple_silicon_only.zsh
01 - 2025/05 - September 2025/09_build_flint_w_dep_http2_framing_apple_silicon_only.zsh
01 - 2025/05 - September 2025/10_build_flint_w_dep_http2_framing_apple_silicon_only.zsh
01 - 2025/05 - September 2025/11_build_flint_w_dep_http2_framing_apple_silicon_only.zsh
01 - 2025/05 - September 2025/12_fix_framework_symlinks.zsh
"

# Limpieza y Mantenimiento
CATEGORIES["limpieza"]="Limpieza y Mantenimiento"
CATEGORIES["limpieza_paths"]="
01 - 2025/08 - december - 2025/11_hunter.zsh
01 - 2025/08 - december - 2025/05_uninstall_bassmaster_loopmasters.zsh
01 - 2025/07 - november - 2025/03_renombrar_imagenes.zsh
01 - 2025/02 - Julio - 2025/01 - 6 de Julio/01_desinstalador_de_apps.zsh
01 - 2025/02 - Julio - 2025/01 - 6 de Julio/02_eliminar_duplicados.zsh
01 - 2025/02 - Julio - 2025/02 - 11 de Julio/01_eliminar_duplicados.py
01 - 2025/02 - Julio - 2025/03 - 12 de Julio/01_eliminar_duplicados_en_discos_externos.py
01 - 2025/02 - Julio - 2025/05 - 21 de Julio/01 - Directory Finder.zsh
01 - 2025/02 - Julio - 2025/06 - 22 de Julio/01_file_and_dirs_finder.zsh
"

# Temas y Personalización
CATEGORIES["temas"]="Temas y Personalización"
CATEGORIES["temas_paths"]="
01 - 2025/08 - december - 2025/install_tank_theme.zsh
01 - 2025/08 - december - 2025/test_tank_colors.zsh
"

# Herramientas Varias
CATEGORIES["varias"]="Herramientas Varias"
CATEGORIES["varias_paths"]="
01 - 2025/07 - november - 2025/setup_project.zsh
verify_scripts.zsh
"

# ============================================================================
# FUNCIONES DE UTILIDAD
# ============================================================================

log_info() {
    echo -e "${CYAN}▶${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC}  $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

# ============================================================================
# FUNCIONES DE VERIFICACIÓN (modulares, reutilizables)
# ============================================================================

check_shebang() {
    local file="$1"
    local ext="${file##*.}"
    local first_line
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    first_line=$(head -n 1 "$file" 2>/dev/null || echo "")
    
    if [[ -z "$first_line" ]]; then
        return 1
    fi
    
    case "$ext" in
        zsh)
            if [[ "$first_line" =~ ^#!/.*zsh ]]; then
                return 0
            fi
            ;;
        sh|bash)
            if [[ "$first_line" =~ ^#!/.*(sh|bash) ]]; then
                return 0
            fi
            ;;
        py)
            if [[ "$first_line" =~ ^#!/.*python ]] || \
               [[ "$first_line" =~ ^(import|from|#|def|class) ]]; then
                return 0
            fi
            ;;
    esac
    
    return 1
}

check_set_euo_pipefail() {
    local file="$1"
    local ext="${file##*.}"
    
    if [[ "$ext" != "zsh" && "$ext" != "sh" && "$ext" != "bash" ]]; then
        return 0  # No aplica
    fi
    
    if grep -q "^set -euo pipefail" "$file" 2>/dev/null || \
       grep -q "^set -euopipefail" "$file" 2>/dev/null; then
        return 0
    fi
    
    return 1
}

check_syntax() {
    local file="$1"
    local ext="${file##*.}"
    
    case "$ext" in
        zsh|sh|bash)
            if zsh -n "$file" 2>/dev/null || bash -n "$file" 2>/dev/null; then
                return 0
            fi
            return 1
            ;;
        py)
            if python3 -m py_compile -q "$file" 2>/dev/null; then
                return 0
            fi
            return 1
            ;;
    esac
    
    return 0
}

check_executable() {
    local file="$1"
    [[ -x "$file" ]]
}

check_file_size() {
    local file="$1"
    local size=$(wc -c < "$file" 2>/dev/null || echo "0")
    (( size > 1000000 )) && return 1  # > 1MB es sospechoso
    return 0
}

check_dependencies() {
    local file="$1"
    local ext="${file##*.}"
    local missing_deps=()
    
    if [[ "$ext" == "zsh" || "$ext" == "sh" || "$ext" == "bash" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Ignorar comentarios
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            # Buscar comandos comunes
            if [[ "$line" =~ command[[:space:]]+([a-zA-Z0-9_-]+) ]]; then
                cmd="${match[1]}"
                [[ "$cmd" =~ \$ ]] && continue
                [[ "$cmd" =~ [\{\}\(\)] ]] && continue
                [[ ! "$cmd" =~ ^[a-zA-Z0-9_-]+$ ]] && continue
                if ! command -v "$cmd" >/dev/null 2>&1; then
                    missing_deps+=("$cmd")
                fi
            fi
        done < "$file"
    elif [[ "$ext" == "py" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ "$line" =~ ^import[[:space:]]+([a-zA-Z0-9_]+) ]]; then
                module="${match[1]}"
                case "$module" in
                    sys|os|json|urllib|datetime|pathlib|subprocess|shutil|hashlib|collections|textwrap|tkinter|argparse)
                        continue
                        ;;
                esac
                if ! python3 -c "import $module" >/dev/null 2>&1; then
                    missing_deps+=("$module")
                fi
            elif [[ "$line" =~ ^from[[:space:]]+([a-zA-Z0-9_]+) ]]; then
                module="${match[1]}"
                case "$module" in
                    sys|os|json|urllib|datetime|pathlib|subprocess|shutil|hashlib|collections|textwrap|tkinter|argparse)
                        continue
                        ;;
                esac
                if ! python3 -c "import $module" >/dev/null 2>&1; then
                    missing_deps+=("$module")
                fi
            fi
        done < "$file"
    fi
    
    if (( ${#missing_deps[@]} > 0 )); then
        printf '%s\n' "${missing_deps[@]}"
        return 1
    fi
    
    return 0
}

verify_script() {
    local script="$1"
    local issues=()
    local warnings=()
    local score=0
    local max_score=6
    
    if [[ ! -f "$script" ]]; then
        return 3  # Skip
    fi
    
    local ext="${script##*.}"
    local basename_script=$(basename "$script")
    
    # Verificar shebang
    if ! check_shebang "$script"; then
        if [[ "$ext" == "py" ]]; then
            local has_python_content=false
            if head -n 5 "$script" 2>/dev/null | grep -qE "^(import|from|def|class)"; then
                has_python_content=true
            fi
            if [[ "$has_python_content" == false ]]; then
                issues+=("Falta shebang o contenido Python válido")
            else
                warnings+=("Falta shebang (pero tiene contenido Python válido)")
                ((score++))
            fi
        else
            issues+=("Falta shebang apropiado")
        fi
    else
        ((score++))
    fi
    
    # Verificar set -euo pipefail
    if [[ "$ext" == "zsh" || "$ext" == "sh" || "$ext" == "bash" ]]; then
        if ! check_set_euo_pipefail "$script"; then
            warnings+=("Falta 'set -euo pipefail'")
        else
            ((score++))
        fi
    else
        ((score++))  # No aplica
    fi
    
    # Verificar sintaxis
    if ! check_syntax "$script"; then
        issues+=("Error de sintaxis")
    else
        ((score++))
    fi
    
    # Verificar ejecutable
    if ! check_executable "$script"; then
        warnings+=("No es ejecutable (chmod +x)")
    else
        ((score++))
    fi
    
    # Verificar tamaño
    if ! check_file_size "$script"; then
        warnings+=("Archivo muy grande (>1MB)")
    else
        ((score++))
    fi
    
    # Verificar dependencias
    local missing_deps=$(check_dependencies "$script")
    if [[ -n "$missing_deps" ]]; then
        local deps_array=($(printf '%s\n' "$missing_deps" | sort -u))
        warnings+=("Dependencias faltantes: ${deps_array[*]}")
    else
        ((score++))
    fi
    
    # Mostrar resultado
    if (( ${#issues[@]} > 0 )); then
        log_error "$script"
        for issue in "${issues[@]}"; do
            echo "    → $issue"
        done
        return 2  # Failed
    elif (( ${#warnings[@]} > 0 )); then
        log_warning "$script (score: $score/$max_score)"
        for warning in "${warnings[@]}"; do
            echo "    → $warning"
        done
        return 1  # Warning
    else
        log_success "$script (score: $score/$max_score)"
        return 0  # Passed
    fi
}

fix_script() {
    local script="$1"
    local ext="${script##*.}"
    local fixed=false
    
    if [[ ! -f "$script" ]]; then
        return 1
    fi
    
    # Agregar shebang si falta
    if ! check_shebang "$script"; then
        case "$ext" in
            zsh)
                printf '%s\n' "#!/usr/bin/env zsh" > "$script.tmp" && cat "$script" >> "$script.tmp" && mv "$script.tmp" "$script" 2>/dev/null && fixed=true
                ;;
            sh|bash)
                printf '%s\n' "#!/bin/bash" > "$script.tmp" && cat "$script" >> "$script.tmp" && mv "$script.tmp" "$script" 2>/dev/null && fixed=true
                ;;
            py)
                printf '%s\n' "#!/usr/bin/env python3" > "$script.tmp" && cat "$script" >> "$script.tmp" && mv "$script.tmp" "$script" 2>/dev/null && fixed=true
                ;;
        esac
    fi
    
    # Agregar set -euo pipefail si falta (solo shell scripts)
    if [[ "$ext" == "zsh" || "$ext" == "sh" || "$ext" == "bash" ]]; then
        if ! check_set_euo_pipefail "$script"; then
            local first_line=$(head -n 1 "$script")
            if [[ "$first_line" =~ ^#! ]]; then
                sed -i '' "1a\\
set -euo pipefail
" "$script" 2>/dev/null && fixed=true
            fi
        fi
    fi
    
    # Hacer ejecutable
    if ! check_executable "$script"; then
        chmod +x "$script" 2>/dev/null && fixed=true
    fi
    
    if [[ "$fixed" == true ]]; then
        log_success "Correcciones aplicadas a: $script"
        return 0
    fi
    
    return 1
}

# ============================================================================
# FUNCIONES DE CATEGORÍAS
# ============================================================================

get_category_scripts() {
    local category_key="$1"
    local scripts=()
    local paths_key="${category_key}_paths"
    local paths_content
    local path full_path
    
    # Verificar que la clave existe
    if [[ -z "${CATEGORIES[$paths_key]:-}" ]]; then
        return 1
    fi
    
    # Obtener el contenido de las rutas
    paths_content="${CATEGORIES[$paths_key]}"
    
    # Si está vacío, retornar
    [[ -z "$paths_content" ]] && return 1
    
    # Dividir el contenido en líneas usando un método más robusto
    local temp_ifs="$IFS"
    IFS=$'\n'
    local paths_array=($(printf '%s\n' "$paths_content"))
    IFS="$temp_ifs"
    
    # Procesar cada ruta
    for path in "${paths_array[@]}"; do
        # Eliminar espacios al inicio y final
        path="${path#"${path%%[![:space:]]*}"}"
        path="${path%"${path##*[![:space:]]}"}"
        
        # Saltar líneas vacías
        [[ -z "$path" ]] && continue
        
        # Construir ruta completa
        if [[ "$path" == /* ]]; then
            full_path="$path"
        else
            full_path="$REPO_ROOT/$path"
        fi
        
        # Verificar que el archivo existe (usar test -f para mayor compatibilidad)
        if test -f "$full_path"; then
            scripts+=("$full_path")
        fi
    done
    
    # Retornar solo si hay scripts
    if (( ${#scripts[@]} > 0 )); then
        printf '%s\n' "${scripts[@]}"
        return 0
    fi
    
    return 1
}

list_categories() {
    local i=1
    
    # Orden específico de categorías
    local ordered_keys=(
        "audio_video"
        "documentos"
        "disco"
        "memoria"
        "macos"
        "recuperacion"
        "matematicas"
        "git"
        "build"
        "limpieza"
        "temas"
        "varias"
    )
    
    # Mostrar categorías en el orden definido
    for key in "${ordered_keys[@]}"; do
        # Verificar que la categoría existe usando -v (zsh 5.3+)
        if [[ -v CATEGORIES[$key] ]] && [[ -v CATEGORIES[${key}_paths] ]]; then
            local cat_name="${CATEGORIES[$key]}"
            if [[ -n "$cat_name" ]]; then
                echo "$i) $cat_name"
                ((i++))
            fi
        fi
    done
    echo "$i) Todas las categorías"
    echo "$((i+1))) Salir"
}

get_category_by_number() {
    local num="$1"
    local i=1
    
    # Usar el mismo orden que list_categories
    local ordered_keys=(
        "audio_video"
        "documentos"
        "disco"
        "memoria"
        "macos"
        "recuperacion"
        "matematicas"
        "git"
        "build"
        "limpieza"
        "temas"
        "varias"
    )
    
    # Buscar la categoría por número
    for key in "${ordered_keys[@]}"; do
        if [[ -n "${CATEGORIES[$key]:-}" ]]; then
            if (( i == num )); then
                echo "$key"
                return 0
            fi
            ((i++))
        fi
    done
    return 1
}

# ============================================================================
# MENÚ INTERACTIVO
# ============================================================================

show_main_menu() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           Script Verification Tool v2.0                      ║${NC}"
    echo -e "${CYAN}║           Verificación por Categorías                        ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    log_info "Selecciona una categoría:"
    echo ""
    list_categories
    echo ""
}

show_category_menu() {
    local category_key="$1"
    local category_name="${CATEGORIES[$category_key]:-Categoría desconocida}"
    local scripts=()
    
    # Obtener scripts de forma segura
    scripts=($(get_category_scripts "$category_key" 2>/dev/null || true))
    local count=${#scripts[@]}
    
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           ${category_name}${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    log_info "Scripts encontrados: $count"
    echo ""
    echo "1) Verificar todos los scripts de esta categoría"
    echo "2) Seleccionar script específico"
    echo "3) Volver al menú principal"
    echo ""
}

show_script_selection() {
    local category_key="$1"
    local scripts=($(get_category_scripts "$category_key"))
    local i=1
    
    echo ""
    log_info "Selecciona un script:"
    echo ""
    for script in "${scripts[@]}"; do
        local rel_path="${script#$REPO_ROOT/}"
        echo "$i) $rel_path"
        ((i++))
    done
    echo "$i) Volver"
    echo ""
}

# ============================================================================
# PROCESAMIENTO
# ============================================================================

process_category() {
    local category_key="$1"
    local auto_fix="${2:-false}"
    local category_name="${CATEGORIES[$category_key]}"
    local scripts=($(get_category_scripts "$category_key"))
    local total=${#scripts[@]}
    local passed=0
    local warnings=0
    local failed=0
    
    if (( total == 0 )); then
        log_warning "No se encontraron scripts en esta categoría"
        return 1
    fi
    
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           ${category_name}${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    log_info "Verificando $total scripts..."
    echo ""
    
    for script in "${scripts[@]}"; do
        local result
        verify_script "$script"
        result=$?
        
        case $result in
            0) ((passed++)) ;;
            1) ((warnings++)) ;;
            2) ((failed++)) ;;
        esac
        
        # Preguntar si hacer fix después de cada verificación
        if [[ "$auto_fix" == false ]] && (( result != 0 )); then
            echo ""
            read -q "?¿Aplicar correcciones automáticas a este script? (y/n): " && echo ""
            if [[ $REPLY == "y" || $REPLY == "Y" ]]; then
                fix_script "$script"
                # Verificar nuevamente después del fix
                verify_script "$script"
            fi
        elif [[ "$auto_fix" == true ]] && (( result != 0 )); then
            fix_script "$script"
        fi
    done
    
    echo ""
    echo -e "${CYAN}────────────────────────────────────────────────────────────${NC}"
    log_info "Resumen de la categoría:"
    echo "  Passed:    $passed"
    echo "  Warnings:  $warnings"
    echo "  Failed:    $failed"
    echo ""
    read -k 1 "?Presiona cualquier tecla para continuar..."
}

process_single_script() {
    local script="$1"
    
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           Verificación de Script Individual                  ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    verify_script "$script"
    local result=$?
    
    echo ""
    if (( result != 0 )); then
        read -q "?¿Aplicar correcciones automáticas? (y/n): " && echo ""
        if [[ $REPLY == "y" || $REPLY == "Y" ]]; then
            fix_script "$script"
            echo ""
            log_info "Verificación después de las correcciones:"
            verify_script "$script"
        fi
    fi
    
    echo ""
    read -k 1 "?Presiona cualquier tecla para continuar..."
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

main() {
    local category_num
    local category_key
    local choice
    local script_num
    local scripts
    
    while true; do
        show_main_menu
        read "?Selecciona una opción: " category_num
        
        # Verificar si es "Todas las categorías"
        local total_categories=$((${#CATEGORIES[@]} / 2))  # Dividir por 2 porque hay _paths
        if (( category_num == total_categories + 1 )); then
            # Procesar todas las categorías
            for key in "${(@k)CATEGORIES}"; do
                if [[ ! "$key" =~ _paths$ ]]; then
                    process_category "$key" false
                fi
            done
            continue
        elif (( category_num == total_categories + 2 )); then
            log_info "Saliendo..."
            exit 0
        fi
        
        category_key=$(get_category_by_number "$category_num")
        if [[ -z "$category_key" ]]; then
            log_error "Opción inválida"
            sleep 2
            continue
        fi
        
        # Menú de categoría
        while true; do
            show_category_menu "$category_key"
            read "?Selecciona una opción: " choice
            
            case "$choice" in
                1)
                    # Verificar todos los scripts de la categoría
                    process_category "$category_key" false
                    ;;
                2)
                    # Seleccionar script específico
                    scripts=($(get_category_scripts "$category_key"))
                    if (( ${#scripts[@]} == 0 )); then
                        log_warning "No hay scripts en esta categoría"
                        sleep 2
                        continue
                    fi
                    
                    show_script_selection "$category_key"
                    read "?Selecciona un script: " script_num
                    
                    if (( script_num > ${#scripts[@]} )); then
                        continue  # Volver
                    fi
                    
                    process_single_script "${scripts[$script_num]}"
                    ;;
                3)
                    # Volver al menú principal
                    break
                    ;;
                *)
                    log_error "Opción inválida"
                    sleep 1
                    ;;
            esac
        done
    done
}

# ============================================================================
# EJECUCIÓN
# ============================================================================

# Verificar si se ejecuta con argumentos (modo no interactivo)
if (( $# > 0 )); then
    case "$1" in
        --all|--fix-all)
            # Procesar todas las categorías con fix automático
            for key in "${(@k)CATEGORIES}"; do
                if [[ ! "$key" =~ _paths$ ]]; then
                    process_category "$key" true
                fi
            done
            ;;
        --help|-h)
            echo "Uso: $0 [opciones]"
            echo ""
            echo "Opciones:"
            echo "  (sin opciones)  Modo interactivo con menú"
            echo "  --all            Verificar todas las categorías"
            echo "  --fix-all        Verificar y corregir todas las categorías"
            echo "  --help, -h       Mostrar esta ayuda"
            exit 0
            ;;
        *)
            log_error "Opción desconocida: $1"
            echo "Usa --help para ver las opciones disponibles"
            exit 1
            ;;
    esac
else
    # Modo interactivo
    main
fi