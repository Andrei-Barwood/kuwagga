#!/bin/zsh
set -euo pipefail

typeset -g SEARCH_TERM=""
typeset -g SEARCH_TYPE_NAME=""
typeset -g SEARCH_TYPE_FLAG=""
typeset -ga SEARCH_ROOTS=()
typeset -g FIND_PATTERN=""
typeset -gi RESULT_COUNT=0
typeset -gA SEEN_PATHS=()

trim_whitespace() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    print -r -- "$value"
}

escape_find_pattern() {
    local value="$1"
    value=${value//\\/\\\\}
    value=${value//\*/\\*}
    value=${value//\?/\\?}
    value=${value//\[/\\[}
    value=${value//\]/\\]}
    print -r -- "$value"
}

build_search_roots() {
    local -A seen_roots=()
    local root

    SEARCH_ROOTS=("/")
    for root in /Volumes/*(N/); do
        SEARCH_ROOTS+=("$root")
    done

    local -a unique_roots=()
    for root in "${SEARCH_ROOTS[@]}"; do
        [[ -n "${seen_roots[$root]-}" ]] && continue
        seen_roots[$root]=1
        unique_roots+=("$root")
    done

    SEARCH_ROOTS=("${unique_roots[@]}")
}

emit_result_if_valid() {
    local path="$1"

    [[ -z "$path" ]] && return
    [[ -n "${SEEN_PATHS[$path]-}" ]] && return

    if [[ "$SEARCH_TYPE_FLAG" == "d" ]]; then
        [[ -d "$path" ]] || return
    else
        [[ -f "$path" ]] || return
    fi

    SEEN_PATHS[$path]=1
    print -r -- "$path"
    (( ++RESULT_COUNT ))
}

spotlight_is_usable() {
    command -v mdfind >/dev/null 2>&1 || return 1
    command -v mdutil >/dev/null 2>&1 || return 1

    local root md_status
    for root in "${SEARCH_ROOTS[@]}"; do
        md_status="$(mdutil -s "$root" 2>/dev/null || true)"
        [[ "$md_status" == *"Indexing enabled."* ]] && return 0
    done

    return 1
}

search_with_spotlight() {
    local root path

    for root in "${SEARCH_ROOTS[@]}"; do
        while IFS= read -r path; do
            emit_result_if_valid "$path"
        done < <(mdfind -onlyin "$root" -name "$SEARCH_TERM" 2>/dev/null || true)
    done
}

run_find_for_root() {
    local root="$1"
    local path

    if [[ "$root" == "/" ]]; then
        while IFS= read -r -d '' path; do
            emit_result_if_valid "$path"
        done < <(
            find "$root" -xdev \
                \( -path "/System/*" -o -path "/dev/*" -o -path "/proc/*" -o -path "/private/var/*" -o -path "/private/tmp/*" \) -prune -o \
                -type "$SEARCH_TYPE_FLAG" -iname "$FIND_PATTERN" -print0 2>/dev/null || true
        )
    else
        while IFS= read -r -d '' path; do
            emit_result_if_valid "$path"
        done < <(
            find "$root" -xdev \
                -type "$SEARCH_TYPE_FLAG" -iname "$FIND_PATTERN" -print0 2>/dev/null || true
        )
    fi
}

search_with_find() {
    local root

    for root in "${SEARCH_ROOTS[@]}"; do
        run_find_for_root "$root"
    done
}

prompt_user() {
    local choice

    echo "What would you like to search for?"
    echo "  1) A Directory (Folder)"
    echo "  2) A File"
    echo ""
    read -r "choice?Enter your choice [1 or 2]: " || exit 1

    case "$choice" in
        1)
            SEARCH_TYPE_FLAG="d"
            SEARCH_TYPE_NAME="folder"
            ;;
        2)
            SEARCH_TYPE_FLAG="f"
            SEARCH_TYPE_NAME="file"
            ;;
        *)
            echo "Invalid choice. Please run the script again and select 1 or 2." >&2
            exit 1
            ;;
    esac

    echo ""
    read -r "SEARCH_TERM?Please enter part of the ${SEARCH_TYPE_NAME} name: " || exit 1
    SEARCH_TERM="$(trim_whitespace "$SEARCH_TERM")"

    if [[ -z "$SEARCH_TERM" ]]; then
        echo "Error: The search term cannot be empty." >&2
        exit 1
    fi

    FIND_PATTERN="*$(escape_find_pattern "$SEARCH_TERM")*"
}

main() {
    local -i spotlight_ok=0
    local run_deep_scan=""

    prompt_user
    build_search_roots

    echo ""
    echo "Searching for ${SEARCH_TYPE_NAME}s containing \"$SEARCH_TERM\"..."
    echo "----------------------------------------------------"

    if spotlight_is_usable; then
        spotlight_ok=1
        search_with_spotlight
    else
        echo "Spotlight index is not available. Using deep filesystem scan..."
        search_with_find
    fi

    if (( RESULT_COUNT == 0 && spotlight_ok == 1 )); then
        echo "No indexed results found."
        read -r "run_deep_scan?Run a deep filesystem scan anyway? [y/N]: " || true

        case "${run_deep_scan:l}" in
            y|yes)
                search_with_find
                ;;
        esac
    fi

    echo "----------------------------------------------------"
    echo "Found $RESULT_COUNT result(s)."
}

main "$@"
