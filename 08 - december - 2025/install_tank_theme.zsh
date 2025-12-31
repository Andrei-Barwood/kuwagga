#!/bin/zsh
# ============================================================================
# INSTALADOR DEL TEMA "TANK" PARA TERMINAL.APP
# ============================================================================
# Paleta: Forest Green
# Colores: #3E7352, #529B6F, #67C294, #AAF797, #DCFF93, #0E1C0F, #1C3121, #2B4D33

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           🌲 INSTALADOR DEL TEMA TANK 🌲                     ║"
echo "║              Paleta Forest Green                             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

SCRIPT_DIR="${0:A:h}"
SWIFT_FILE="$SCRIPT_DIR/tank_theme_installer.swift"
COMPILED="/tmp/configure_tank"

# Verificar si existe el archivo Swift
if [[ ! -f "$SWIFT_FILE" ]]; then
    echo "❌ No se encontró: $SWIFT_FILE"
    exit 1
fi

echo "🔧 Compilando instalador..."
swiftc "$SWIFT_FILE" -o "$COMPILED" -framework AppKit 2>&1

if [[ $? -ne 0 ]]; then
    echo "❌ Error de compilación"
    exit 1
fi

echo ""
"$COMPILED"

echo ""
echo "💡 Para revertir, ve a Terminal → Ajustes → Perfiles"
echo "   y selecciona otro perfil como predeterminado."
echo ""
