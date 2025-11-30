#!/bin/bash

echo "🦁 UPDATE LION → EL CAPITAN 10.11"
echo "================================="

# Verificar App Store
if ! which open >/dev/null 2>&1; then
  echo "❌ App Store no disponible (necesitas 10.6.3+)."
  exit 1
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

read -p "Pulsa ENTER cuando el instalador esté listo: "

if [[ ! -d "/Applications/Install OS X El Capitan.app" ]]; then
  echo "❌ Instalador no encontrado. Reinicia script."
  exit 1
fi

echo "🚀 Iniciando instalación auto..."
sudo "/Applications/Install OS X El Capitan.app/Contents/MacOS/InstallMacOSX" \
  --agreetolicense --nointeraction --verbose

echo "✅ Reiniciará automáticamente. ¡Backup hecho?!"

