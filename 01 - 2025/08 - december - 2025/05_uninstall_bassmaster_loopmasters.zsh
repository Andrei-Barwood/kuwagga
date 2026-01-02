#!/bin/zsh

# Script para desinstalar completamente Bass Master de Loop Masters
# Compatible con macOS Sequoia

echo "=========================================="
echo "Desinstalador de Bass Master - Loop Masters"
echo "=========================================="
echo ""

# Colores para mensajes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # Sin color

# Función para eliminar archivos/directorios
remove_item() {
    local item="$1"
    if [ -e "$item" ]; then
        echo "${YELLOW}Eliminando:${NC} $item"
        sudo rm -rf "$item"
        echo "${GREEN}✓ Eliminado${NC}"
        return 0
    else
        echo "${RED}✗ No encontrado:${NC} $item"
        return 1
    fi
}

# Solicitar confirmación
echo "${YELLOW}Este script eliminará completamente Bass Master y todas sus dependencias.${NC}"
read "confirm?¿Deseas continuar? (s/n): "
if [[ ! $confirm =~ ^[Ss]$ ]]; then
    echo "Cancelado por el usuario."
    exit 0
fi

echo ""
echo "Iniciando desinstalación..."
echo ""

# 1. Eliminar plugins AU (Audio Unit)
echo "1. Buscando plugins Audio Unit..."
remove_item "/Library/Audio/Plug-Ins/Components/Bass Master.component"
remove_item "$HOME/Library/Audio/Plug-Ins/Components/Bass Master.component"
remove_item "/Library/Audio/Plug-Ins/Components/BassMaster.component"
remove_item "$HOME/Library/Audio/Plug-Ins/Components/BassMaster.component"

echo ""

# 2. Eliminar plugins VST2
echo "2. Buscando plugins VST2..."
remove_item "/Library/Audio/Plug-Ins/VST/Bass Master.vst"
remove_item "$HOME/Library/Audio/Plug-Ins/VST/Bass Master.vst"
remove_item "/Library/Audio/Plug-Ins/VST/BassMaster.vst"
remove_item "$HOME/Library/Audio/Plug-Ins/VST/BassMaster.vst"

echo ""

# 3. Eliminar plugins VST3
echo "3. Buscando plugins VST3..."
remove_item "/Library/Audio/Plug-Ins/VST3/Bass Master.vst3"
remove_item "$HOME/Library/Audio/Plug-Ins/VST3/Bass Master.vst3"
remove_item "/Library/Audio/Plug-Ins/VST3/BassMaster.vst3"
remove_item "$HOME/Library/Audio/Plug-Ins/VST3/BassMaster.vst3"

echo ""

# 4. Eliminar archivos de contenido
echo "4. Buscando archivos de contenido..."
remove_item "/Library/Application Support/Loopmasters/Bass Master"
remove_item "$HOME/Library/Application Support/Loopmasters/Bass Master"
remove_item "/Library/Application Support/Bass Master"
remove_item "$HOME/Library/Application Support/Bass Master"

echo ""

# 5. Eliminar preferencias
echo "5. Eliminando preferencias..."
remove_item "$HOME/Library/Preferences/com.loopmasters.bassmaster.plist"
remove_item "$HOME/Library/Preferences/com.loopmasters.Bass-Master.plist"

echo ""

# 6. Eliminar cachés
echo "6. Limpiando cachés..."
remove_item "$HOME/Library/Caches/com.loopmasters.bassmaster"
remove_item "$HOME/Library/Caches/Loopmasters/Bass Master"

echo ""

# 7. Eliminar recibos de instalación
echo "7. Eliminando recibos de instalación..."
sudo rm -f /var/db/receipts/*loopmasters*bass*master* 2>/dev/null
sudo rm -f /var/db/receipts/*Bass*Master* 2>/dev/null

echo ""

# 8. Limpiar caché de Audio Units
echo "8. Limpiando caché de Audio Units..."
remove_item "$HOME/Library/Caches/AudioUnitCache"
remove_item "/Library/Caches/AudioUnitCache"

# Forzar reconstrucción del caché AU
echo "${YELLOW}Reiniciando caché de Audio Units...${NC}"
killall -9 AudioComponentRegistrar 2>/dev/null

echo ""

# 9. Buscar archivos residuales
echo "9. Buscando archivos residuales..."
echo "${YELLOW}Buscando en /Applications...${NC}"
find /Applications -iname "*bass*master*" -maxdepth 2 2>/dev/null | while read file; do
    echo "Encontrado: $file"
    read "remove_app?¿Eliminar? (s/n): "
    if [[ $remove_app =~ ^[Ss]$ ]]; then
        sudo rm -rf "$file"
        echo "${GREEN}✓ Eliminado${NC}"
    fi
done

echo ""
echo "=========================================="
echo "${GREEN}Desinstalación completada${NC}"
echo "=========================================="
echo ""
echo "Recomendaciones finales:"
echo "1. Reinicia tu DAW y reescanea los plugins"
echo "2. Si usas Logic Pro, resetea la lista de plugins:"
echo "   Logic Pro > Preferencias > Plug-in Manager > Reset"
echo "3. Considera reiniciar tu Mac para completar la limpieza"
echo ""
