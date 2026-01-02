#!/bin/zsh

# Script para renombrar archivos .jpeg en orden numérico

echo "=== Renombrador de archivos JPEG ==="
echo ""
echo "Por favor, pega la ruta del directorio (cópiala desde Finder):"
read -r directorio

# Eliminar posibles comillas o espacios extra
directorio="${directorio//\'/}"
directorio="${directorio//\"/}"
directorio="${directorio## }"
directorio="${directorio%% }"

# Verificar que el directorio existe
if [[ ! -d "$directorio" ]]; then
    echo "Error: El directorio no existe o no es válido."
    exit 1
fi

# Cambiar al directorio
cd "$directorio" || exit 1

# Contar archivos .jpeg
archivos=(*.jpeg)
if [[ ${#archivos[@]} -eq 0 ]] || [[ ! -e "${archivos[1]}" ]]; then
    echo "No se encontraron archivos .jpeg en este directorio."
    exit 1
fi

echo ""
echo "Se encontraron ${#archivos[@]} archivos .jpeg"
echo "¿Deseas continuar con el renombrado? (s/n):"
read -r confirmacion

if [[ "$confirmacion" != "s" ]] && [[ "$confirmacion" != "S" ]]; then
    echo "Operación cancelada."
    exit 0
fi

# Renombrar archivos
contador=1
for archivo in *.jpeg(N); do
    [[ -f "$archivo" ]] || continue
    nuevo_nombre=$(printf "%03d.jpeg" $contador)
    
    # Evitar sobrescribir si ya existe
    if [[ "$archivo" != "$nuevo_nombre" ]]; then
        mv "$archivo" "$nuevo_nombre"
        echo "Renombrado: $archivo -> $nuevo_nombre"
    fi
    
    ((contador++))
done

echo ""
echo "¡Renombrado completado! Total: $((contador - 1)) archivos."
