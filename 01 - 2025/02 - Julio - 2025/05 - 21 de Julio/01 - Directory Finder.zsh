#!/bin/zsh
set -euo pipefail

#
# A script to find a folder by its approximate name across all connected drives on macOS.
#
# Usage:
# 1. Save this file (e.g., as `finddir.zsh`).
# 2. Make it executable: `chmod +x finddir.zsh`
# 3. Run it with a search term: `./finddir.zsh <foldername>`
#    Example: `./finddir.zsh photos`
#

# --- Script Start ---

# 1. Check for user input
# We need to make sure the user has provided a name to search for.
if [[ -z "${1:-}" ]]; then
  # If no argument is given, print the usage instructions and exit.
  echo "Error: Please provide an approximate folder name to search for." >&2
  echo "Usage: $(basename "$0") <approximate_name>" >&2
  exit 1
fi

# 2. Store the search term
# We'll take the first argument the user provides and use it as our search query.
SEARCH_TERM="${1}"

# Validar que el término de búsqueda no esté vacío después de trim
SEARCH_TERM="${SEARCH_TERM#"${SEARCH_TERM%%[![:space:]]*}"}"
SEARCH_TERM="${SEARCH_TERM%"${SEARCH_TERM##*[![:space:]]}"}"

if [[ -z "$SEARCH_TERM" ]]; then
  echo "Error: El término de búsqueda no puede estar vacío." >&2
  exit 1
fi

# 3. Inform the user that the search is starting
# This can be a long process, so it's good to give feedback.
echo "🔎 Searching for folders with names containing \"$SEARCH_TERM\"..."
echo "This might take several minutes depending on the size and speed of your drives. Please be patient."
echo "----------------------------------------------------"

# 4. Execute the search command
#
# `find`: The command-line utility to find files and directories.
# `/ /Volumes`: The search paths. `/` is your main startup disk. `/Volumes` is where macOS mounts all other drives, including external HDDs, SSDs, and USB sticks.
# `-type d`: Specifies that we are only looking for directories (folders).
# `-iname "*$SEARCH_TERM*"`: This is the core of the "approximate" search.
#   - `-iname` makes the search case-insensitive.
#   - The asterisks `*` are wildcards, meaning "match any characters".
#   - So, `"*$SEARCH_TERM*"` will find any directory that *contains* your search term anywhere in its name.
# `2>/dev/null`: This part cleans up the output. It redirects any error messages (like "Permission denied" for system-protected folders) to a place where they are discarded, so you only see the results.
find / /Volumes -type d -iname "*$SEARCH_TERM*" 2>/dev/null

# 5. Inform the user that the search is complete
echo "----------------------------------------------------"
echo "✅ Search complete."

# --- Script End ---
