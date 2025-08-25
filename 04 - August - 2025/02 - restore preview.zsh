#!/bin/zsh

# Quit Preview app if running
osascript -e 'tell application "Preview" to quit'

# Wait a moment to ensure it quits
sleep 2

# Remove Preview preferences plist (resets Preview settings)
rm -f ~/Library/Preferences/com.apple.Preview.plist

# Remove Preview saved state
rm -rf ~/Library/Saved\ Application\ State/com.apple.Preview.savedState

# Optional: Clear the Quick Look cache (can help with thumbnail/previews)
qlmanage -r cache

# Relaunch Preview app
open -a Preview

echo "Preview app has been reset and relaunched."
