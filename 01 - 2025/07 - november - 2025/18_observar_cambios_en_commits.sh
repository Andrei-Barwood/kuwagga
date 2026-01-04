#!/bin/bash
# Git History - Sistema, ARREGLADO (output limpio)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

open_browser() {
    local url=$1
    case $(uname -s 2>/dev/null || echo "Linux") in
        Darwin) open "$url" ;;
        Linux) xdg-open "$url" 2>/dev/null || setsid "$BROWSER" "$url" >/dev/null 2>&1 ;;
        CYGWIN*) cygstart "$url" 2>/dev/null || start "$url" ;;
        MINGW*) start "$url" ;;
        *) echo "Usa: open/firefox/chrome $url" ;;
    esac
}

find_repos_system_wide() {
    local start_dir="${1:-.}"
    local maxdepth=6
    
    echo -e "${YELLOW}Buscando repositorios Git...${NC}" >&2
    echo -e "${YELLOW}(máx profundidad: $maxdepth, espera 30-60 seg)${NC}" >&2
    
    # SOLO repos al stdout, mensajes a stderr [web:61]
    timeout 120 find "$start_dir" -maxdepth "$maxdepth" -type d -name ".git" 2>/dev/null | \
    sed 's|/\.git$||' | \
    sort -u
    
    echo -e "${GREEN}✓ Búsqueda completada${NC}" >&2
}

get_top_files() {
    local repo_dir=$1
    pushd "$repo_dir" >/dev/null
    git log --pretty=format: --name-only 2>/dev/null | \
    awk 'NF{ count[$0]++ } END{ for(f in count) print count[f] "\t" f }' | \
    sort -k1 -nr | head -20 | nl -w2 -s': '
    popd >/dev/null
}

get_repo_slug() {
    local repo_dir=$1
    pushd "$repo_dir" >/dev/null
    local origin=$(git remote get-url origin 2>/dev/null || echo "")
    if [[ $origin == *"github.com"* ]]; then
        echo "$origin" | sed -E 's|.*/github.com[/:]([^/]+/[^.]+).*|\1|' | sed 's/\.git$//'
        return
    fi
    echo "NO_GITHUB"
    popd >/dev/null
}

main() {
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}Git History Browser - Sistema${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}\n"

    local search_path="$HOME"
    echo -n "Path (Enter=$HOME): "
    read -r custom_path
    [[ -n "$custom_path" ]] && search_path="$custom_path"

    [[ ! -d "$search_path" ]] && { echo -e "${RED}Ruta no existe.${NC}"; exit 1; }

    # Buscar y guardar
    local temp_file="/tmp/repos-$$.txt"
    find_repos_system_wide "$search_path" > "$temp_file"
    
    local repos=$(cat "$temp_file")
    [[ -z "$repos" ]] && { echo -e "${RED}No repos encontrados.${NC}"; rm -f "$temp_file"; exit 1; }

    local repo_count=$(echo "$repos" | wc -l)
    echo -e "\n${GREEN}Total: $repo_count repositorios${NC}\n"
    
    echo "Repositorios:"
    echo "$repos" | head -30 | nl -w2 -s': '
    
    if [[ $repo_count -gt 30 ]]; then
        echo -e "${YELLOW}... y $((repo_count - 30)) más${NC}"
    fi
    
    echo -n "Repo # : "
    read repo_num
    local repo=$(echo "$repos" | sed -n "${repo_num}p")
    [[ -z "$repo" || ! -d "$repo/.git" ]] && { echo -e "${RED}Repo inválido.${NC}"; rm -f "$temp_file"; exit 1; }

    echo -e "\n${BLUE}=== $(basename "$repo") ===${NC}"
    echo "Extrayendo archivos..."
    local top_files=$(get_top_files "$repo")
    echo "$top_files"
    
    echo -n "Archivo # : "
    read file_num
    local file_line=$(echo "$top_files" | sed -n "${file_num}p")
    [[ -z "$file_line" ]] && { echo -e "${RED}Inválido.${NC}"; rm -f "$temp_file"; exit 1; }
    
    local file_path=$(echo "$file_line" | cut -f2-)
    local repo_slug=$(get_repo_slug "$repo")
    local branch=$(cd "$repo" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

    echo -e "\n${GREEN}Archivo:${NC} $file_path"
    echo -e "${GREEN}Branch:${NC} $branch"

    if [[ "$repo_slug" != "NO_GITHUB" ]]; then
        local gh_url="https://github.com/$repo_slug/commits/$branch/$file_path"
        echo -e "${BLUE}GitHub:${NC} $gh_url\n"
        
        echo -n "¿Abrir? (y/N): "
        read open_gh
        case "$open_gh" in [Yy]*) 
            open_browser "$gh_url"
            echo -e "${GREEN}✓ Abierto${NC}"
        ;; esac
    else
        echo -e "${YELLOW}⚠ No está en GitHub${NC}"
    fi

    rm -f "$temp_file"
}

main "$@"

