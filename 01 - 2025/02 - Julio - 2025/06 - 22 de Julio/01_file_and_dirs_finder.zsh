#!/bin/zsh

#
# A script to find a folder or a file by its approximate name across all connected drives on macOS.
#
# Usage:
# 1. Save this file (e.g., as `findstuff.zsh`).
# 2. Make it executable: `chmod +x findstuff.zsh`
# 3. Run it: `./findstuff.zsh`
#

# --- Script Start ---

# 1. Display Menu and get user's choice
echo "What would you like to search for?"
echo "  1) A Directory (Folder)"
echo "  2) A File"
echo ""
echo -n "Enter your choice [1 or 2]: "
read choice

# 2. Determine search parameters using an array for robustness
# An array ensures that '-type' and its value ('d' or 'f') are passed as separate arguments.
case $choice in
    1)
        # Define an array with two elements: '-type' and 'd'
        search_params=('-type' 'd')
        SEARCH_TYPE_NAME="folder"
        ;;
    2)
        # Define an array with two elements: '-type' and 'f'
        search_params=('-type' 'f')
        SEARCH_TYPE_NAME="file"
        ;;
    *)
        echo "❌ Invalid choice. Please run the script again and select 1 or 2."
        exit 1
        ;;
esac

# 3. Prompt for and store the search term
echo ""
read "SEARCH_TERM?Please enter the approximate name of the $SEARCH_TYPE_NAME: "

# 4. Check for user input
if [ -z "$SEARCH_TERM" ]; then
  echo "Error: The search term cannot be empty."
  exit 1
fi

# 5. Inform the user that the search is starting
echo ""
echo "🔎 Searching for ${SEARCH_TYPE_NAME}s with names containing \"$SEARCH_TERM\"..."
echo "This might take several minutes depending on the size and speed of your drives. Please be patient."
echo "----------------------------------------------------"

# 6. Execute the search command
# We now use the ${search_params[@]} array, which expands correctly to '-type' 'f'.
# '2>/dev/null' is still removed so you can see if the search is running.
# You can add it back to the end of the line to hide "Permission denied" errors.
find / /Volumes ${search_params[@]} -iname "*$SEARCH_TERM*"

# 7. Inform the user that the search is complete
echo "----------------------------------------------------"
echo "✅ Search complete."

# --- Script End ---
