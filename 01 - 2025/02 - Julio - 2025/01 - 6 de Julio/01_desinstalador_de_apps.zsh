#!/bin/zsh
set -euo pipefail
setopt typesetsilent

# -----------------------------------------------------------------------------
#
#  Desinstalador de aplicaciones para macOS.
#  - Detecta apps en /Applications y ~/Applications.
#  - Calcula tamaño real (app + datos asociados).
#  - Permite seleccionar múltiples apps y eliminar de forma segura.
#
# -----------------------------------------------------------------------------

# --- Colores ---
if [[ -t 1 ]]; then
    C_RESET='\033[0m'
    C_BOLD='\033[1m'
    C_RED='\033[0;31m'
    C_GREEN='\033[0;32m'
    C_YELLOW='\033[0;33m'
    C_PRIMARY='\033[38;5;45m'
    C_SECONDARY='\033[38;5;61m'
    C_LIGHT_INFO='\033[38;5;153m'
else
    C_RESET=''
    C_BOLD=''
    C_RED=''
    C_GREEN=''
    C_YELLOW=''
    C_PRIMARY=''
    C_SECONDARY=''
    C_LIGHT_INFO=''
fi

# --- Seguridad de borrado ---
typeset -a ALLOWED_DELETE_PREFIXES=(
    "/Applications/"
    "$HOME/Applications/"
    "$HOME/Library/Application Support/"
    "$HOME/Library/Caches/"
    "$HOME/Library/Preferences/"
    "$HOME/Library/Logs/"
    "$HOME/Library/Containers/"
    "$HOME/Library/Group Containers/"
    "$HOME/Library/Saved Application State/"
    "$HOME/Library/WebKit/"
    "/Library/Application Support/"
    "/Library/Caches/"
    "/Library/Preferences/"
    "/Library/Logs/"
)

typeset -a BLOCKED_DELETE_PATHS=(
    "/"
    "/Applications"
    "/Library"
    "/System"
    "/System/Applications"
    "/System/Library"
    "$HOME"
    "$HOME/Applications"
    "$HOME/Library"
)

# --- Dependencias ---
if command -v fzf >/dev/null 2>&1; then
    use_fzf=true
else
    use_fzf=false
    echo "${C_YELLOW}ADVERTENCIA:${C_RESET} ${C_BOLD}fzf${C_RESET} no está instalado."
    echo "Se usará un menú de texto. Puedes instalar fzf con: ${C_PRIMARY}brew install fzf${C_RESET}"
fi

function print_header() {
    echo "${C_PRIMARY}${C_BOLD}--- Desinstalador de Aplicaciones para macOS ---${C_RESET}"
    echo "Escanea apps y residuos asociados para ayudarte a liberar espacio en disco."
    echo
}

function escape_find_pattern() {
    local pattern="$1"
    pattern="${pattern//\\/\\\\}"
    pattern="${pattern//\*/\\*}"
    pattern="${pattern//\?/\\?}"
    pattern="${pattern//\[/\\[}"
    pattern="${pattern//\]/\\]}"
    printf '%s' "$pattern"
}

function human_readable_bytes() {
    local bytes="${1:-0}"
    if (( bytes < 1024 )); then
        printf "%dB" "$bytes"
        return
    fi

    local kib=$(( (bytes + 1023) / 1024 ))
    if (( kib < 1024 )); then
        printf "%dKB" "$kib"
        return
    fi

    local mib=$(( (kib + 1023) / 1024 ))
    if (( mib < 1024 )); then
        printf "%dMB" "$mib"
        return
    fi

    local gib=$(( (mib + 1023) / 1024 ))
    if (( gib < 1024 )); then
        printf "%dGB" "$gib"
        return
    fi

    local tib=$(( (gib + 1023) / 1024 ))
    printf "%dTB" "$tib"
}

function bytes_of_paths() {
    if (( $# == 0 )); then
        echo 0
        return
    fi

    local -a existing=()
    local candidate
    for candidate in "$@"; do
        if [[ -n "$candidate" && -e "$candidate" ]]; then
            existing+=("$candidate")
        fi
    done

    if (( ${#existing[@]} == 0 )); then
        echo 0
        return
    fi

    local total_kb
    total_kb=$({ du -sk "${existing[@]}" 2>/dev/null || true; } | awk '{sum += $1} END {print sum + 0}')
    echo $(( total_kb * 1024 ))
}

function unique_existing_paths() {
    local -A seen=()
    local -a unique_paths=()
    local entry resolved

    for entry in "$@"; do
        [[ -n "$entry" && -e "$entry" ]] || continue
        resolved="${entry:A}"
        [[ -n "$resolved" ]] || continue

        if (( ! ${+seen[$resolved]} )); then
            seen[$resolved]=1
            unique_paths+=("$resolved")
        fi
    done

    if (( ${#unique_paths[@]} > 0 )); then
        printf '%s\n' "${unique_paths[@]}"
    fi
}

function find_app_bundle_id() {
    local app_path="$1"
    local bundle_id
    bundle_id=$(mdls -name kMDItemCFBundleIdentifier -raw "$app_path" 2>/dev/null || true)

    if [[ "$bundle_id" == "(null)" || -z "$bundle_id" ]]; then
        echo ""
    else
        echo "$bundle_id"
    fi
}

function find_associated_data() {
    local app_path="$1"
    [[ -d "$app_path" ]] || return 0

    local app_name bundle_id escaped_bundle_id
    app_name=$(basename "$app_path" .app)
    bundle_id=$(find_app_bundle_id "$app_path")

    local -a candidates=()
    candidates+=(
        "$HOME/Library/Application Support/$app_name"
        "$HOME/Library/Caches/$app_name"
        "$HOME/Library/Logs/$app_name"
        "/Library/Application Support/$app_name"
        "/Library/Caches/$app_name"
        "/Library/Logs/$app_name"
    )

    if [[ -n "$bundle_id" ]]; then
        candidates+=(
            "$HOME/Library/Application Support/$bundle_id"
            "$HOME/Library/Caches/$bundle_id"
            "$HOME/Library/Preferences/${bundle_id}.plist"
            "$HOME/Library/Containers/$bundle_id"
            "$HOME/Library/Saved Application State/${bundle_id}.savedState"
            "$HOME/Library/WebKit/$bundle_id"
            "/Library/Application Support/$bundle_id"
            "/Library/Caches/$bundle_id"
            "/Library/Preferences/${bundle_id}.plist"
            "/Library/Logs/$bundle_id"
        )

        local -a prefix_dirs=(
            "$HOME/Library/Application Support"
            "$HOME/Library/Caches"
            "$HOME/Library/Preferences"
            "$HOME/Library/Logs"
            "$HOME/Library/Containers"
            "$HOME/Library/Group Containers"
            "$HOME/Library/Saved Application State"
            "$HOME/Library/WebKit"
            "/Library/Application Support"
            "/Library/Caches"
            "/Library/Preferences"
            "/Library/Logs"
        )

        escaped_bundle_id=$(escape_find_pattern "$bundle_id")
        local dir match
        for dir in "${prefix_dirs[@]}"; do
            [[ -d "$dir" ]] || continue
            while IFS= read -r match; do
                candidates+=("$match")
            done < <(find "$dir" -mindepth 1 -maxdepth 1 -iname "${escaped_bundle_id}*" -print 2>/dev/null || true)
        done

        if [[ -d "$HOME/Library/Preferences/ByHost" ]]; then
            while IFS= read -r match; do
                candidates+=("$match")
            done < <(find "$HOME/Library/Preferences/ByHost" -mindepth 1 -maxdepth 1 -iname "${escaped_bundle_id}.*.plist" -print 2>/dev/null || true)
        fi
    fi

    unique_existing_paths "${candidates[@]}"
}

function build_app_list() {
    local -a roots=("/Applications" "$HOME/Applications")
    local -a existing_roots=()
    local root

    for root in "${roots[@]}"; do
        [[ -d "$root" ]] && existing_roots+=("$root")
    done

    if (( ${#existing_roots[@]} == 0 )); then
        return 0
    fi

    {
        find "${existing_roots[@]}" -mindepth 1 -maxdepth 2 -type d -name "*.app" -print 2>/dev/null | sort -u
    } || true
}

function is_safe_delete_target() {
    local target="$1"
    [[ -n "$target" && -e "$target" ]] || return 1

    local resolved="${target:A}"
    [[ -n "$resolved" ]] || return 1

    local blocked
    for blocked in "${BLOCKED_DELETE_PATHS[@]}"; do
        if [[ "$resolved" == "$blocked" ]]; then
            return 1
        fi
    done

    local prefix
    for prefix in "${ALLOWED_DELETE_PREFIXES[@]}"; do
        case "$resolved/" in
            "$prefix"*) return 0 ;;
        esac
    done

    return 1
}

function delete_target() {
    local target="$1"
    [[ -n "$target" && -e "$target" ]] || return 0

    if ! is_safe_delete_target "$target"; then
        echo "${C_YELLOW}Omitido por seguridad:${C_RESET} $target"
        return 0
    fi

    echo "${C_LIGHT_INFO}Eliminando:${C_RESET} $target"
    if rm -rf "$target" 2>/dev/null; then
        return 0
    fi

    echo "${C_YELLOW}Reintentando con permisos de administrador...${C_RESET}"
    sudo rm -rf "$target"
}

function render_manual_menu() {
    local -a lines=("$@")
    local i=1
    local line size name app_location

    echo >&2
    echo "${C_BOLD}Aplicaciones detectadas (ordenadas por tamaño):${C_RESET}" >&2
    for line in "${lines[@]}"; do
        IFS=$'\t' read -r size name app_location <<< "$line"
        printf "%3d) %8s | %s | %s\n" "$i" "$size" "$name" "$app_location" >&2
        ((i += 1))
    done

    echo >&2
    local raw
    read -r "raw?Números a desinstalar (ej. 1,3,8) o ENTER para cancelar: "

    if [[ -z "${raw// }" ]]; then
        return 0
    fi

    local cleaned="${raw// /}"
    local -a picks=()
    IFS=',' read -rA picks <<< "$cleaned"

    local -A seen_index=()
    local -a chosen_lines=()
    local idx
    for idx in "${picks[@]}"; do
        if [[ "$idx" != <-> ]]; then
            echo "${C_YELLOW}Índice inválido: $idx${C_RESET}" >&2
            continue
        fi
        if (( idx < 1 || idx > ${#lines[@]} )); then
            echo "${C_YELLOW}Índice fuera de rango: $idx${C_RESET}" >&2
            continue
        fi
        if (( ! ${+seen_index[$idx]} )); then
            seen_index[$idx]=1
            chosen_lines+=("${lines[$idx]}")
        fi
    done

    if (( ${#chosen_lines[@]} > 0 )); then
        printf '%s\n' "${chosen_lines[@]}"
    fi
}

function main() {
    print_header

    echo "Este script escaneará aplicaciones y residuos asociados (cachés, preferencias, etc.)."
    echo "${C_YELLOW}Dependiendo de tu disco, el escaneo puede tardar varios minutos.${C_RESET}"
    echo
    read -r "start?Presiona ENTER para comenzar el escaneo... "
    echo

    echo "${C_SECONDARY}Buscando aplicaciones instaladas...${C_RESET}"
    local -a all_apps=()
    all_apps=("${(@f)$(build_app_list)}")

    if (( ${#all_apps[@]} == 0 )); then
        echo "${C_RED}No se encontraron aplicaciones en /Applications ni ~/Applications.${C_RESET}"
        exit 0
    fi

    echo "Se encontraron ${#all_apps[@]} aplicaciones. Calculando uso total por aplicación..."

    typeset -A app_name_by_path
    typeset -A app_data_files_by_path
    typeset -A app_bytes_by_path
    typeset -A app_size_by_path

    local total=${#all_apps[@]}
    local current=0
    local app app_name

    for app in "${all_apps[@]}"; do
        ((current += 1))
        printf "\r${C_GREEN}Escaneando: %d/%d${C_RESET}" "$current" "$total"

        app_name=$(basename "$app" .app)
        local -a associated_files=()
        associated_files=("${(@f)$(find_associated_data "$app" 2>/dev/null || true)}")

        local -a all_targets=("$app" "${associated_files[@]}")
        local total_bytes
        total_bytes=$(bytes_of_paths "${all_targets[@]}")

        app_name_by_path[$app]="$app_name"
        app_data_files_by_path[$app]="${(F)associated_files}"
        app_bytes_by_path[$app]="$total_bytes"
        app_size_by_path[$app]="$(human_readable_bytes "$total_bytes")"
    done
    printf "\n\n${C_GREEN}Escaneo completado.${C_RESET}\n\n"

    local -a sorted_paths=()
    sorted_paths=("${(@f)$(
        for app in "${all_apps[@]}"; do
            printf '%s\t%s\n' "${app_bytes_by_path[$app]}" "$app"
        done | sort -t$'\t' -k1,1nr | cut -f2-
    )}")

    local tab=$'\t'
    local -a menu_lines=()
    local app_path_iter
    for app_path_iter in "${sorted_paths[@]}"; do
        menu_lines+=("${app_size_by_path[$app_path_iter]}${tab}${app_name_by_path[$app_path_iter]}${tab}${app_path_iter}")
    done

    local selections=""
    if $use_fzf; then
        selections=$(printf '%s\n' "${menu_lines[@]}" | fzf \
            --multi \
            --height=70% \
            --border \
            --reverse \
            --delimiter=$'\t' \
            --with-nth=1,2,3 \
            --prompt="Desinstalar> " \
            --header="TAB seleccionar | ENTER confirmar" || true)
    else
        echo "${C_YELLOW}Menú de texto activo (sin fzf).${C_RESET}"
        selections=$(render_manual_menu "${menu_lines[@]}")
    fi

    if [[ -z "$selections" ]]; then
        echo
        echo "Operación cancelada. No se ha eliminado nada."
        exit 0
    fi

    local -a selected_lines=("${(@f)selections}")
    local -a selected_summary=()
    local -A seen_targets=()
    local -a dedup_targets=()

    local line size name selected_path
    for line in "${selected_lines[@]}"; do
        IFS=$'\t' read -r size name selected_path <<< "$line"
        [[ -n "$selected_path" ]] || continue
        selected_summary+=("$size | $name | $selected_path")

        local -a associated=()
        associated=("${(@f)app_data_files_by_path[$selected_path]}")

        local -a targets=("$selected_path" "${associated[@]}")
        local target normalized_target
        for target in "${targets[@]}"; do
            [[ -n "$target" && -e "$target" ]] || continue
            normalized_target="${target:A}"
            if (( ! ${+seen_targets[$normalized_target]} )); then
                seen_targets[$normalized_target]=1
                dedup_targets+=("$normalized_target")
            fi
        done
    done

    local -a safe_targets=()
    local -a skipped_targets=()
    for target in "${dedup_targets[@]}"; do
        if is_safe_delete_target "$target"; then
            safe_targets+=("$target")
        else
            skipped_targets+=("$target")
        fi
    done

    if (( ${#safe_targets[@]} == 0 )); then
        echo "${C_YELLOW}No hay rutas seguras para eliminar con la selección actual.${C_RESET}"
        exit 0
    fi

    local estimated_bytes
    estimated_bytes=$(bytes_of_paths "${safe_targets[@]}")
    local estimated_human
    estimated_human=$(human_readable_bytes "$estimated_bytes")

    echo "${C_BOLD}Has seleccionado:${C_RESET}"
    printf ' - %s\n' "${selected_summary[@]}"
    echo
    echo "${C_BOLD}Resumen de limpieza:${C_RESET}"
    echo " - Elementos a eliminar: ${#safe_targets[@]}"
    echo " - Espacio estimado a liberar: $estimated_human"
    if (( ${#skipped_targets[@]} > 0 )); then
        echo " - Omitidos por seguridad: ${#skipped_targets[@]}"
    fi
    echo
    echo "${C_RED}${C_BOLD}¡ADVERTENCIA! ESTA ACCIÓN ES IRREVERSIBLE.${C_RESET}"

    local confirmation
    read -r "confirmation?Escribe ELIMINAR para continuar: "
    echo

    if [[ "${confirmation:u}" != "ELIMINAR" ]]; then
        echo "Desinstalación cancelada por el usuario."
        exit 0
    fi

    echo "Iniciando desinstalación..."
    local deleted_count=0
    local failed_count=0
    for target in "${safe_targets[@]}"; do
        if delete_target "$target"; then
            ((deleted_count += 1))
        else
            ((failed_count += 1))
            echo "${C_RED}Error al eliminar:${C_RESET} $target"
        fi
    done

    echo
    echo "${C_BOLD}Proceso finalizado.${C_RESET}"
    echo " - Elementos procesados: ${#safe_targets[@]}"
    echo " - Eliminados: $deleted_count"
    echo " - Fallidos: $failed_count"
    echo " - Espacio objetivo estimado: $estimated_human"
}

main
