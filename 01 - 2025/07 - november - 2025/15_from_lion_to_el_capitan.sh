#!/bin/bash
set -euo pipefail

# Script para actualizar macOS Lion a El Capitan
# Requiere: macOS 10.6.3+, conexión a Internet, Apple ID

echo "🦁 UPDATE LION → EL CAPITAN 10.11"
echo "================================="

# Verificar App Store
if ! command -v open &> /dev/null; then
  echo "Error: App Store no disponible (necesitas macOS 10.6.3+)." >&2
  exit 1
fi

# Verificar permisos de administrador
if [[ $EUID -ne 0 ]]; then
  echo "Advertencia: Se requieren permisos de administrador para la instalación." >&2
  echo "El script continuará, pero necesitarás sudo para instalar." >&2
fi

# Abrir App Store directo a El Capitan
echo "📥 Descargando El Capitan desde App Store..."
open "macappstore://itunes.apple.com/app/os-x-el-capitan/id1140860417?mt=12" 2>/dev/null || \
open "https://apps.apple.com/us/app/os-x-el-capitan/id1140860417"

echo ""
echo "⏳ Pasos:"
echo "1. Inicia sesión con Apple ID si pide."
echo "2. Clic 'Get' / Descargar (5-10GB)."
echo "3. Espera a /Applications/Install OS X El Capitan.app"

read -p "Pulsa ENTER cuando el instalador esté listo: " || exit 1

if [[ ! -d "/Applications/Install OS X El Capitan.app" ]]; then
  echo "Error: Instalador no encontrado en /Applications/Install OS X El Capitan.app" >&2
  echo "Por favor, descarga el instalador desde el App Store y vuelve a ejecutar este script." >&2
  exit 1
fi

INSTALLER_PATH="/Applications/Install OS X El Capitan.app/Contents/MacOS/InstallMacOSX"
if [[ ! -f "$INSTALLER_PATH" ]]; then
  echo "Error: El ejecutable del instalador no se encuentra: $INSTALLER_PATH" >&2
  exit 1
fi

echo "🚀 Iniciando instalación auto..."
echo "⚠️  ADVERTENCIA: El sistema se reiniciará automáticamente después de la instalación."
echo "⚠️  Asegúrate de haber hecho backup de tus datos importantes."
read -p "¿Continuar? (s/N): " confirm
if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
  echo "Instalación cancelada."
  exit 0
fi

if sudo "$INSTALLER_PATH" --agreetolicense --nointeraction --verbose 2>&1; then
  echo "✅ Instalación iniciada. El sistema se reiniciará automáticamente."
else
  echo "Error: La instalación falló." >&2
  exit 1
fi

