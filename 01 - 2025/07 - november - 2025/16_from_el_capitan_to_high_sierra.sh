#!/bin/bash
set -euo pipefail

# Script para actualizar macOS El Capitan a High Sierra
# Requiere: macOS 10.11+, conexión a Internet, Apple ID

echo "🏔️ UPDATE EL CAPITAN → HIGH SIERRA 10.13"
echo "========================================="

# Verificar que open esté disponible
if ! command -v open &> /dev/null; then
  echo "Error: El comando 'open' no está disponible." >&2
  exit 1
fi

echo "📥 Descargando High Sierra desde App Store..."
open "macappstore://itunes.apple.com/app/macos-high-sierra/id1246284741?mt=12" 2>/dev/null || \
open "https://apps.apple.com/us/app/macos-high-sierra/id1246284741"

echo ""
echo "⏳ 1. Inicia sesión Apple ID."
echo "   2. Clic 'Get' (5-6GB)."
echo "   3. Espera /Applications/Install macOS High Sierra.app"

read -p "Pulsa ENTER cuando listo: " || exit 1

if [[ ! -d "/Applications/Install macOS High Sierra.app" ]]; then
  echo "Error: Instalador no encontrado en /Applications/Install macOS High Sierra.app" >&2
  echo "Por favor, descarga el instalador desde el App Store y vuelve a ejecutar este script." >&2
  exit 1
fi

INSTALLER_PATH="/Applications/Install macOS High Sierra.app/Contents/MacOS/Install macOS High Sierra"
if [[ ! -f "$INSTALLER_PATH" ]]; then
  echo "Error: El ejecutable del instalador no se encuentra: $INSTALLER_PATH" >&2
  exit 1
fi

echo "🚀 Instalación auto (se convertirá a APFS)..."
echo "⚠️  ADVERTENCIA: El sistema se reiniciará automáticamente después de la instalación."
echo "⚠️  Asegúrate de haber hecho backup de tus datos importantes."
read -p "¿Continuar? (s/N): " confirm
if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
  echo "Instalación cancelada."
  exit 0
fi

if sudo "$INSTALLER_PATH" --agreetolicense --nointeraction --verbose 2>&1; then
  echo "✅ Instalación iniciada. El sistema se reiniciará automáticamente. High Sierra 🎉"
else
  echo "Error: La instalación falló." >&2
  exit 1
fi

