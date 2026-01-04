#!/bin/zsh
set -euo pipefail

# Script para descargar e instalar macOS Sequoia
# Requiere permisos de administrador

if [[ $EUID -ne 0 ]]; then
  echo "Error: Este script requiere permisos de administrador." >&2
  echo "Ejecuta con: sudo $0" >&2
  exit 1
fi

# Verificar que softwareupdate esté disponible
if ! command -v softwareupdate &> /dev/null; then
  echo "Error: softwareupdate no está disponible en este sistema." >&2
  exit 1
fi

versions=("15.3.2" "15.3.1" "15.3" "15.2" "15.1")
installer_app="/Applications/Install macOS Sequoia.app"

echo "Intentando descargar la versión más reciente de macOS Sequoia..."

for ver in "${versions[@]}"; do
  echo "Probando $ver con --verbose..."
  if softwareupdate --fetch-full-installer --full-installer-version "$ver" --verbose 2>&1; then
    if [[ -d "$installer_app" ]]; then
      echo "¡Éxito! Instalador en $installer_app (~14GB descargados)."
      if command -v open &> /dev/null; then
        exec open "$installer_app"  # Abre directamente
      else
        echo "Instalador listo en: $installer_app"
        echo "Ejecuta manualmente: open '$installer_app'"
      fi
      exit 0
    else
      echo "Advertencia: softwareupdate reportó éxito pero el instalador no se encuentra." >&2
    fi
  else
    echo "Fallo en $ver (normal si no está disponible para Ventura/M2)."
  fi
done

echo "No disponible vía softwareupdate desde Ventura."
echo "Alternativas:"
echo "- GUI: System Settings > General > Software Update > 'More info...' > 'Get installer'."
echo "- Directo: https://apps.apple.com/cl/app/macos-sequoia/id6479647251 [web:37]"
echo "- MrMacintosh links: https://mrmacintosh.com/macos-sequoia-full-installer-database-download-directly-from-apple/ [web:22]"

