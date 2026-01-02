#!/bin/zsh

recovered_folder=~/Desktop/recovered
trash_folder=~/.Trash

# Create recovered folder if does not exist
mkdir -p "$recovered_folder"

# List files in trash (including hidden) and pipe to fzf for interactive search
selected_files=$(find "$trash_folder" -mindepth 1 -maxdepth 1 | fzf --multi --prompt="Search Trash: ")

if [[ -z "$selected_files" ]]; then
  echo "No files selected."
  exit 0
fi

# Move selected files to recovered folder
while IFS= read -r file; do
  mv "$file" "$recovered_folder"
done <<< "$selected_files"

echo "Moved selected files to $recovered_folder"
