#!/bin/zsh
# Script de ejemplo para configurar monitoreo de memoria con cron
# Este archivo contiene instrucciones para configurar cron

set -euo pipefail

echo "=== Configuración de Monitoreo de Memoria con Cron ==="
echo ""
echo "Para configurar el monitoreo automático de memoria:"
echo ""
echo "1. Edita tu crontab:"
echo "   crontab -e"
echo ""
echo "2. Agrega una de estas líneas según tu preferencia:"
echo ""
echo "   # Monitoreo cada 5 minutos:"
echo "   */5 * * * * $(pwd)/memory_pressure_monitor.zsh >> ~/memory_monitor.log 2>&1"
echo ""
echo "   # Monitoreo cada 10 minutos:"
echo "   */10 * * * * $(pwd)/memory_pressure_monitor.zsh >> ~/memory_monitor.log 2>&1"
echo ""
echo "   # Monitoreo cada hora:"
echo "   0 * * * * $(pwd)/memory_pressure_monitor.zsh >> ~/memory_monitor.log 2>&1"
echo ""
echo "3. Asegúrate de que el script tenga permisos de ejecución:"
echo "   chmod +x memory_pressure_monitor.zsh"
echo ""
echo "4. Verifica que cron esté ejecutándose:"
echo "   sudo launchctl list | grep cron"
echo ""
echo "Nota: Los logs se guardarán en ~/memory_monitor.log"
