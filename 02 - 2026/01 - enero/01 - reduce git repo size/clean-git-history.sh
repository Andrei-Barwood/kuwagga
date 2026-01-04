#!/bin/bash
# Script para limpiar el historial de git eliminando archivos grandes
# 
# Uso:
#   1. Edita la sección "ARCHIVOS A ELIMINAR" con las rutas de los archivos/directorios
#      que quieres eliminar del historial
#   2. Ejecuta: ./clean-git-history.sh
#   3. Si todo está bien, haz: git push origin --force --all
#
# ⚠️  ADVERTENCIA: Este script reescribe el historial de git permanentemente.
#    Asegúrate de tener un backup antes de ejecutarlo.

set -euo pipefail

# Script para limpiar el historial de git eliminando archivos grandes
# ADVERTENCIA: Reescribe el historial permanentemente

# Suprimir warning de git-filter-branch
export FILTER_BRANCH_SQUELCH_WARNING=1

# Verificar que estamos en un repositorio git
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Error: No estás en un repositorio git." >&2
    exit 1
fi

# Verificar que git-filter-branch o git-filter-repo esté disponible
if ! command -v git-filter-branch > /dev/null 2>&1 && ! command -v git-filter-repo > /dev/null 2>&1; then
    echo "❌ Error: Se requiere git-filter-branch o git-filter-repo." >&2
    echo "   Instala git-filter-repo: pip install git-filter-repo" >&2
    exit 1
fi

echo "🧹 Limpiando historial de git..."
echo ""
echo "⚠️  ADVERTENCIA: Este script reescribirá el historial de git."
echo "   Asegúrate de tener un backup antes de continuar."
echo ""
read -p "¿Continuar? (s/n): " confirmar || exit 1
if [[ ! "$confirmar" =~ ^[Ss]$ ]]; then
    echo "❌ Operación cancelada."
    exit 0
fi

# Crear backup del branch actual
echo ""
echo "📦 Creando backup..."
git branch backup-before-cleanup 2>/dev/null || true
echo "✓ Backup creado en branch: backup-before-cleanup"

# ============================================
# ARCHIVOS A ELIMINAR - EDITA ESTA SECCIÓN
# ============================================
# Agrega aquí las rutas de archivos/directorios que quieres eliminar del historial
# Ejemplos:
#   "archivos-grandes/"
#   "node_modules/"
#   "*.pdf"
#   "carpeta/subcarpeta/"
# ============================================

ARCHIVOS_A_ELIMINAR=(
    # Ejemplo: descomenta y edita las siguientes líneas con tus archivos
    # "images/cine/"
    # "2025/descargar/"
    # "node_modules/"
    # "*.pdf"
)

# Si no hay archivos especificados, mostrar mensaje
if [ ${#ARCHIVOS_A_ELIMINAR[@]} -eq 0 ]; then
    echo ""
    echo "⚠️  No hay archivos especificados para eliminar."
    echo "   Por favor, edita el script y agrega las rutas en la sección"
    echo "   'ARCHIVOS A ELIMINAR' antes de ejecutarlo."
    exit 1
fi

# Eliminar archivos grandes del historial usando git filter-branch
echo ""
echo "🗑️  Eliminando archivos grandes del historial..."
echo "   Archivos a eliminar:"
for archivo in "${ARCHIVOS_A_ELIMINAR[@]}"; do
    echo "   - $archivo"
done
echo ""

# Construir el comando git rm
RM_COMMAND="git rm --cached --ignore-unmatch -r"
for archivo in "${ARCHIVOS_A_ELIMINAR[@]}"; do
    RM_COMMAND="$RM_COMMAND \"$archivo\""
done

# Ejecutar filter-branch
git filter-branch --force --index-filter "$RM_COMMAND" --prune-empty --tag-name-filter cat -- --all

# Limpiar referencias
echo ""
echo "🧼 Limpiando referencias..."
rm -rf .git/refs/original/
git reflog expire --expire=now --all
git gc --prune=now --aggressive

echo ""
echo "✅ Limpieza completada!"
echo ""
echo "📊 Tamaño actual del repositorio:"
du -sh .git

echo ""
echo "⚠️  IMPORTANTE: Si ya has hecho push a GitHub, necesitarás hacer:"
echo "   git push origin --force --all"
echo "   git push origin --force --tags"
echo ""
echo "⚠️  Si algo sale mal, puedes restaurar con:"
echo "   git checkout backup-before-cleanup"
echo ""
echo "💡 Tip: Verifica el tamaño antes y después con:"
echo "   du -sh .git"
echo "   git count-objects -vH"
