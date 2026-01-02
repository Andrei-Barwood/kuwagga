#!/bin/bash

echo "🏔️ UPDATE EL CAPITAN → HIGH SIERRA 10.13"
echo "========================================="

echo "📥 Descargando High Sierra desde App Store..."
open "macappstore://itunes.apple.com/app/macos-high-sierra/id1246284741?mt=12" 2>/dev/null || \
open "https://apps.apple.com/us/app/macos-high-sierra/id1246284741"

echo ""
echo "⏳ 1. Inicia sesión Apple ID."
echo "   2. Clic 'Get' (5-6GB)."
echo "   3. Espera /Applications/Install macOS High Sierra.app"

read -p "Pulsa ENTER cuando listo: "

if [[ ! -d "/Applications/Install macOS High Sierra.app" ]]; then
  echo "❌ Instalador no encontrado."
  exit 1
fi

echo "🚀 Instalación auto (se convertirá a APFS)..."
sudo "/Applications/Install macOS High Sierra.app/Contents/MacOS/Install macOS High Sierra" \
  --agreetolicense --nointeraction --verbose

echo "✅ Listo! El sistema se Reinicia solo. High Sierra 🎉"

