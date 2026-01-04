#!/bin/bash
set -euo pipefail

# Must be run from inside FLINT.framework directory
# Script para arreglar symlinks rotos en FLINT.framework

FRAMEWORK_DIR="${1:-.}"

# Verificar que estamos en un directorio de framework
if [[ ! -d "$FRAMEWORK_DIR/Versions" ]]; then
    echo "Error: No se encontró el directorio Versions. ¿Estás dentro de un framework?" >&2
    echo "Uso: $0 [directorio_del_framework]" >&2
    exit 1
fi

cd "$FRAMEWORK_DIR" || exit 1

echo "🔧 Fixing FLINT.framework symlinks..."

# Remove broken directories/symlinks  
rm -rf Headers Modules Resources FLINT

# Create correct symlinks at framework root
if ! ln -sf Versions/A/Headers Headers || \
   ! ln -sf Versions/A/Modules Modules || \
   ! ln -sf Versions/A/Resources Resources || \
   ! ln -sf Versions/A/FLINT FLINT; then
    echo "Error: No se pudieron crear los symlinks" >&2
    exit 1
fi

# Fix Current version symlink
cd Versions || exit 1
rm -f Current  
if ! ln -sf A Current; then
    echo "Error: No se pudo crear el symlink Current" >&2
    exit 1
fi
cd ..

echo "✅ Framework symlinks fixed!"

# Verify the fix
if [[ -d "Headers" ]]; then
    echo "📁 Checking Headers directory:"
    ls -la Headers/
else
    echo "⚠️  Advertencia: El directorio Headers no existe después de crear el symlink" >&2
    exit 1
fi
