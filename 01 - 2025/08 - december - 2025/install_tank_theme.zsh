#!/bin/zsh
set -euo pipefail

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

# Verificar que estamos en macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "❌ Error: Este script solo funciona en macOS" >&2
    exit 1
fi

# Verificar que swiftc esté disponible
if ! command -v swiftc &> /dev/null; then
    echo "❌ Error: swiftc no está disponible" >&2
    echo "   Instala Xcode Command Line Tools: xcode-select --install" >&2
    exit 1
fi

SCRIPT_DIR="${0:A:h}"
SWIFT_FILE="$SCRIPT_DIR/tank_theme_installer.swift"
COMPILED="/tmp/configure_tank"

# Verificar si existe el archivo Swift
if [[ ! -f "$SWIFT_FILE" ]]; then
    echo "❌ No se encontró: $SWIFT_FILE" >&2
    exit 1
fi

echo "🔧 Compilando instalador..."
if ! swiftc "$SWIFT_FILE" -o "$COMPILED" -framework AppKit 2>&1; then
    echo "❌ Error de compilación" >&2
    exit 1
fi

# Verificar que el ejecutable se creó
if [[ ! -f "$COMPILED" || ! -x "$COMPILED" ]]; then
    echo "❌ Error: El ejecutable no se creó correctamente" >&2
    exit 1
fi

echo ""
if "$COMPILED"; then
    echo ""
    echo "✅ Tema Tank instalado exitosamente"
else
    echo ""
    echo "❌ Error al instalar el tema" >&2
    exit 1
fi

echo ""
echo "💡 Para revertir, ve a Terminal → Ajustes → Perfiles"
echo "   y selecciona otro perfil como predeterminado."
echo ""
