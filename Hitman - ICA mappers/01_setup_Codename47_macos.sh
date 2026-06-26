#!/usr/bin/env zsh

echo "Buscando instalación de Hitman: Codename 47..."

# Buscar la ruta del juego en Porting Kit / Wine
GAME_DIR=$(find ~/Applications /Applications -type d -name "Hitman Codename 47.app" 2>/dev/null | head -n 1)

if [ -z "$GAME_DIR" ]; then
    echo "❌ No se encontró la instalación de Hitman Codename 47 en la carpeta Applications."
    exit 1
fi

INI_PATH="$GAME_DIR/Contents/SharedSupport/prefix/drive_c/GOG Games/Hitman Codename 47/Hitman.ini"

if [ ! -f "$INI_PATH" ]; then
    echo "❌ No se encontró el archivo Hitman.ini en $INI_PATH"
    exit 1
fi

echo "✅ Juego encontrado. Aplicando parche de pantalla negra (1280x720 + Window)..."

# Modificar Hitman.ini para arreglar pantalla negra sin tocar controles
sed -i.bak 's/Resolution.*/Resolution 1280x720\nWindow/' "$INI_PATH"

echo "🎉 ¡Parche visual aplicado! Ya puedes usar tu app de mapeo para los controles."
