# Uso de Hokkaido Disk Sentinel

Hokkaido Disk Sentinel está diseñado para ser utilizado tanto de forma interactiva como a través de comandos CLI, permitiendo a los administradores integrarlo en scripts de automatización.

## Menú Interactivo
La forma más amigable de utilizar la herramienta es mediante su menú:
```bash
hokkaido-sentinel menu
```
Desde aquí podrás escanear, ver el espacio protegido y realizar simulaciones.

## Interfaz de Línea de Comandos (CLI)

### Escaneo y Auditoría
- `hokkaido-sentinel scan`: Escanea el disco principal y muestra resumen.
- `hokkaido-sentinel recoverable`: Lista todos los candidatos a borrado con sus clasificaciones de riesgo.
- `hokkaido-sentinel protected`: Lista rutas del sistema que la herramienta nunca tocará.

### Limpieza
- `hokkaido-sentinel clean --dry-run`: (Comportamiento por defecto). Simula el borrado y te muestra qué liberaría.
- `hokkaido-sentinel clean --execute`: Ejecuta el borrado de elementos SAFE tras tu confirmación explícita.

### Reportes
- `hokkaido-sentinel report --format json`: Genera `hokkaido_report.json`.
- `hokkaido-sentinel report --format markdown`: Genera `hokkaido_report.md`.
