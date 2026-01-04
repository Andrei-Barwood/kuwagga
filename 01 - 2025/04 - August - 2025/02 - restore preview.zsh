#!/bin/zsh
set -euo pipefail

# Script para restaurar la aplicación Preview de macOS
# Resetea las preferencias y el estado guardado de Preview

# Quit Preview app if running
if pgrep -x "Preview" > /dev/null; then
  osascript -e 'tell application "Preview" to quit' || true
  # Wait a moment to ensure it quits
  sleep 2
fi

# Remove Preview preferences plist (resets Preview settings)
if [[ -f ~/Library/Preferences/com.apple.Preview.plist ]]; then
  rm -f ~/Library/Preferences/com.apple.Preview.plist
  echo "✓ Preferencias eliminadas"
fi

# Remove Preview saved state
if [[ -d ~/Library/Saved\ Application\ State/com.apple.Preview.savedState ]]; then
  rm -rf ~/Library/Saved\ Application\ State/com.apple.Preview.savedState
  echo "✓ Estado guardado eliminado"
fi

# Optional: Clear the Quick Look cache (can help with thumbnail/previews)
if command -v qlmanage &> /dev/null; then
  qlmanage -r cache 2>/dev/null || true
  echo "✓ Caché de Quick Look limpiado"
fi

# Relaunch Preview app
if open -a Preview 2>/dev/null; then
  echo "✓ Preview reiniciado"
  echo "Preview app has been reset and relaunched."
else
  echo "Error: No se pudo abrir Preview" >&2
  exit 1
fi
