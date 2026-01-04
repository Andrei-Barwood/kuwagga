#!/bin/zsh
set -euo pipefail

# Script para simular presión de memoria crítica (solo para pruebas)
# ADVERTENCIA: Este script puede afectar el rendimiento del sistema
# Úsalo solo en entornos de prueba

# Verificar que memory_pressure esté disponible
if ! command -v memory_pressure &> /dev/null; then
  echo "Error: memory_pressure no está disponible en este sistema." >&2
  exit 1
fi

# Verificar permisos de administrador
if [[ $EUID -ne 0 ]]; then
  echo "Este script requiere permisos de administrador (sudo)." >&2
  echo ""
  echo "Uso:"
  echo "  sudo $0 [nivel]"
  echo ""
  echo "Niveles disponibles:"
  echo "  warn      - Presión de memoria de advertencia"
  echo "  urgent    - Presión de memoria urgente"
  echo "  critical  - Presión de memoria crítica (por defecto)"
  echo ""
  echo "Ejemplo:"
  echo "  sudo $0 critical"
  exit 1
fi

LEVEL="${1:-critical}"

# Validar nivel
case "$LEVEL" in
  warn|urgent|critical)
    echo "⚠️  ADVERTENCIA: Simulando presión de memoria en nivel: $LEVEL"
    echo "   Esto puede afectar el rendimiento del sistema."
    echo "   Presiona Ctrl+C para cancelar (espera 3 segundos)..."
    sleep 3
    echo "Iniciando simulación..."
    memory_pressure -S -l "$LEVEL"
    ;;
  *)
    echo "Error: Nivel inválido: $LEVEL" >&2
    echo "Niveles válidos: warn, urgent, critical" >&2
    exit 1
    ;;
esac
