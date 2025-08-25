#!/bin/zsh

# -----------------------------------------------------------------------------
#
#  Mac App Uninstaller - Un script para encontrar y eliminar aplicaciones y
#  sus datos asociados en macOS.
#
#  Uso:
#  1. Guarda este archivo (ej. uninstall.sh).
#  2. Dale permisos de ejecución: chmod +x uninstall.sh
#  3. Ejecútalo: ./uninstall.sh
#
#  Dependencia: fzf (https://github.com/junegunn/fzf)
#  Se recomienda encarecidamente instalar 'fzf' para el menú interactivo.
#  Puedes instalarlo con Homebrew: brew install fzf
#
# -----------------------------------------------------------------------------

# --- Colores y Estilos ---
C_RESET='\033[0m'
C_BOLD='\033[1m'

# Colores estándar
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'

# Paleta de colores personalizada
C_PRIMARY='\033[38;5;45m'   # #0ED1FF - Cian brillante
C_SECONDARY='\033[38;5;61m' # #485199 - Azul oscuro/púrpura
C_LIGHT_INFO='\033[38;5;153m' # #ADBAD1 - Azul grisáceo claro

# --- Comprobación de Dependencias ---
if ! command -v fzf &> /dev/null; then
    echo "${C_YELLOW}ADVERTENCIA:${C_RESET} ${C_BOLD}fzf${C_RESET} no está instalado."
    echo "El script funcionará, pero la experiencia del menú es mucho mejor con fzf."
    echo "Puedes instalarlo con Homebrew: ${C_PRIMARY}brew install fzf${C_RESET}"
    use_fzf=false
else
    use_fzf=true
fi

# --- Funciones ---

# Muestra un mensaje de encabezado
function print_header() {
    echo "${C_PRIMARY}${C_BOLD}--- Desinstalador de Aplicaciones para macOS ---${C_RESET}"
    echo "Este script te ayudará a eliminar aplicaciones y sus datos asociados."
    echo
}

# Encuentra los datos asociados a una aplicación
function find_associated_data() {
    local app_path="$1"
    local app_name=$(basename "$app_path" .app)
    
    local bundle_id
    bundle_id=$(mdls -name kMDItemCFBundleIdentifier -r "$app_path" 2>/dev/null)

    local search_paths=(
        "$HOME/Library/Application Support"
        "$HOME/Library/Caches"
        "$HOME/Library/Preferences"
        "$HOME/Library/Logs"
        "$HOME/Library/Containers"
        "/Library/Application Support"
        "/Library/Caches"
        "/Library/Preferences"
        "/Library/Logs"
    )

    local found_files=()
    local search_terms=("$app_name")
    
    if [[ -n "$bundle_id" && "$bundle_id" != "(null)" ]]; then
        search_terms+=("$bundle_id")
    fi
    
    for path in "${search_paths[@]}"; do
        if [[ -d "$path" ]]; then
            for term in "${search_terms[@]}"; do
                while IFS= read -r line; do
                    found_files+=("$line")
                done < <(find "$path" -ipath "*${term}*" -maxdepth 2 2>/dev/null)
            done
        fi
    done

    # CORRECCIÓN: Imprime una lista de archivos únicos, separados por nueva línea,
    # para manejar correctamente los espacios en las rutas.
    local unique_files=("${(@u)found_files[@]}")
    if ((${#unique_files[@]} > 0)); then
        printf '%s\n' "${unique_files[@]}"
    fi
}

# Calcula el tamaño total de una lista de archivos/directorios
function calculate_size() {
    # CORRECCIÓN: Maneja correctamente los argumentos con espacios.
    if [ $# -eq 0 ]; then
        echo "0B"
        return
    fi
    
    # Pasa los argumentos entre comillas a 'du' para manejar espacios.
    total_size=$(du -shc "$@" 2>/dev/null | grep 'total$' | awk '{print $1}')
    
    echo "${total_size:-0B}"
}

# --- Flujo Principal ---

main() {
    print_header

    echo "Bienvenido! Este programa escaneará tu sistema en busca de aplicaciones y sus datos"
    echo "asociados (cachés, configuraciones, etc.) para calcular el espacio que ocupan."
    echo "${C_YELLOW}Este proceso puede tardar varios minutos dependiendo del número de apps.${C_RESET}"
    echo
    printf "%s" "Presiona ENTER para comenzar el escaneo..."
    read -k 1
    echo
    echo

    typeset -A app_paths
    typeset -A app_data_files
    typeset -A app_data_sizes

    echo "${C_SECONDARY}Buscando aplicaciones...${C_RESET}"
    local all_apps=()
    while IFS= read -r line; do
        all_apps+=("$line")
    done < <(find /Applications ~/Applications -name "*.app" -maxdepth 2 -type d)

    echo "Se encontraron ${#all_apps[@]} aplicaciones. Calculando el tamaño de los datos asociados..."
    
    local progress=0
    local total=${#all_apps[@]}

    for app in "${all_apps[@]}"; do
        progress=$((progress + 1))
        printf "\r${C_GREEN}Escaneando: [%-50s] %d/%d${C_RESET}" $(printf '#%.0s' $(seq 1 $((progress * 50 / total)))) $progress $total

        local app_name=$(basename "$app" .app)
        
        if [[ -n "${app_paths[$app_name]}" ]]; then
            continue
        fi

        app_paths[$app_name]="$app"
        
        # CORRECCIÓN: Lee rutas separadas por nueva línea en un array.
        local data_files=("${(@f)$(find_associated_data "$app")}")
        
        # CORRECCIÓN: Almacena el array como una cadena separada por nueva línea.
        IFS=$'\n'
        app_data_files[$app_name]="${data_files[*]}"
        
        # CORRECCIÓN: Pasa los argumentos entre comillas para manejar espacios.
        local data_size=$(calculate_size "$app" "${data_files[@]}")
        app_data_sizes[$app_name]=$data_size
    done
    
    printf "\n\n${C_GREEN}¡Escaneo completado!${C_RESET}\n\n"

    local options=()
    for name in ${(k)app_paths}; do
        options+=("(${app_data_sizes[$name]}) - $name")
    done
    
    options=($(printf '%s\n' "${options[@]}" | sort))

    if [ ${#options[@]} -eq 0 ]; then
        echo "${C_RED}No se encontraron aplicaciones para mostrar.${C_RESET}"
        exit 0
    fi

    echo "${C_BOLD}El tamaño mostrado incluye la aplicación y todos sus datos asociados (cachés, etc.).${C_RESET}"
    echo "Al seleccionar una app, se selecciona también los datos asociados a esa app, serán eliminados para recuperar espacio."
    echo
    echo "Selecciona las aplicaciones que deseas desinstalar:"
    echo "(Usa las flechas, ${C_BOLD}TAB${C_RESET} para seleccionar/deseleccionar, ${C_BOLD}ENTER${C_RESET} para confirmar)"
    
    local selections
    if $use_fzf; then
        selections=$(printf '%s\n' "${options[@]}" | fzf --multi --height=40% --border --reverse --prompt="${C_PRIMARY}Desinstalar> ${C_RESET}")
    else
        echo "${C_YELLOW}Usando menú básico. Para selección múltiple, instala fzf.${C_RESET}"
        select choice in "${options[@]}" "CANCELAR"; do
            if [[ "$choice" == "CANCELAR" ]]; then
                selections=""
                break
            elif [[ -n "$choice" ]]; then
                selections=$choice
                break
            else
                echo "Opción inválida."
            fi
        done
    fi

    if [[ -z "$selections" ]]; then
        echo "\nOperación cancelada. No se ha eliminado nada."
        exit 0
    fi

    echo "\n${C_BOLD}Has seleccionado desinstalar:${C_RESET}"
    echo "$selections"
    echo "\n${C_RED}${C_BOLD}¡ADVERTENCIA! ESTA ACCIÓN ES IRREVERSIBLE.${C_RESET}"
    
    read "choice?¿Estás absolutamente seguro de que quieres continuar? (s/n): "
    echo

    if [[ "$choice" != "s" && "$choice" != "S" ]]; then
        echo "\nDesinstalación cancelada por el usuario."
        exit 0
    fi

    echo "\nIniciando desinstalación..."
    
    local selected_apps=(${(f)selections})

    for item in "${selected_apps[@]}"; do
        local app_name_to_delete=$(echo "$item" | sed 's/^([^)]*) - //')
        
        echo "\n${C_PRIMARY}--- Desinstalando: $app_name_to_delete ---${C_RESET}"

        local app_file_path="${app_paths[$app_name_to_delete]}"
        
        # CORRECCIÓN: Recrea el array a partir de la cadena separada por nueva línea.
        local data_files_to_delete=("${(@f)app_data_files[$app_name_to_delete]}")
        
        local all_files_to_delete=("$app_file_path" "${data_files_to_delete[@]}")

        for file_path in "${all_files_to_delete[@]}"; do
            # Asegurarse de que la ruta no esté vacía antes de intentar eliminar
            if [[ -n "$file_path" && -e "$file_path" ]]; then
                echo "${C_LIGHT_INFO}Eliminando: $file_path${C_RESET}"
                if [[ ! -w "$file_path" ]]; then
                    echo "${C_YELLOW}Se requieren permisos de administrador...${C_RESET}"
                    sudo rm -rf "$file_path"
                else
                    rm -rf "$file_path"
                fi
            fi
        done
        echo "${C_GREEN}¡'$app_name_to_delete' desinstalado con éxito!${C_RESET}"
    done

    echo "\n${C_BOLD}Proceso de desinstalación finalizado.${C_RESET}"
}

main
