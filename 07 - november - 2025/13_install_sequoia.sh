#!/bin/zsh

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Ejecuta con sudo."
  exit 1
fi

versions=("15.3.2" "15.3.1" "15.3" "15.2" "15.1")
installer_app="/Applications/Install macOS Sequoia.app"

echo "Intentando descargar la versión más reciente de macOS Sequoia..."

for ver in "${versions[@]}"; do
  echo "Probando $ver con --verbose..."
  if softwareupdate --fetch-full-installer --full-installer-version "$ver" --verbose; then
    if [[ -d "$installer_app" ]]; then
      echo "¡Éxito! Instalador en $installer_app (~14GB descargados)."
      exec open "$installer_app"  # Abre directamente
      exit 0
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

