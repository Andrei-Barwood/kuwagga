## TUTORIAL COMPLETO: Conversión de HTML a PDF con Python y Pyenv

### 📋 Tabla de Contenidos
1. Instalación de Python con Pyenv
2. Creación del entorno virtual
3. Instalación de dependencias
4. Explicación del script
5. Ejecución paso a paso
6. Troubleshooting

---

## 1. INSTALACIÓN DE PYTHON CON PYENV

### 1.1 Instalación de Pyenv

#### En macOS:
```bash
# Usando Homebrew (recomendado)
brew install pyenv

# Añadir a ~/.bash_profile o ~/.zshrc (si usas zsh)
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.zshrc
echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.zshrc
echo 'eval "$(pyenv init -)"' >> ~/.zshrc

# Recargar configuración
source ~/.zshrc
```

#### En Linux (Ubuntu/Debian):
```bash
# Instalación de dependencias
sudo apt-get update
sudo apt-get install -y make build-essential libssl-dev zlib1g-dev \
  libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \
  libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
  libffi-dev liblzma-dev

# Descargar e instalar pyenv
curl https://pyenv.run | bash

# Añadir a ~/.bashrc
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(pyenv init -)"' >> ~/.bashrc

# Recargar configuración
source ~/.bashrc
```

#### En Windows (usando Git Bash o WSL):
```bash
# Opción 1: Usar pyenv-win en PowerShell
iex (New-Object System.Net.WebClient).DownloadString('https://pyenv-win.github.io/pyenv-win/install.ps1')

# Opción 2: Usar WSL (Windows Subsystem for Linux) - RECOMENDADO
# Seguir instrucciones de Linux
```

### 1.2 Verificar instalación de Pyenv

```bash
pyenv --version
# Salida esperada: pyenv 2.3.x (o similar)
```

### 1.3 Listar versiones de Python disponibles

```bash
# Ver versiones disponibles para instalar
pyenv install --list | grep "3.11"

# Versión recomendada para este proyecto: 3.11.x o 3.12.x
pyenv install 3.11.7
```

### 1.4 Instalar Python con Pyenv

```bash
# Instalar versión específica
pyenv install 3.11.7

# Listar versiones instaladas
pyenv versions

# Salida esperada:
# system
# * 3.11.7 (set by /Users/usuario/.pyenv/version)
```

---

## 2. CREACIÓN DEL ENTORNO VIRTUAL

### 2.1 Crear directorio del proyecto

```bash
# Crear carpeta para el proyecto
mkdir ~/mi_proyecto_pdf
cd ~/mi_proyecto_pdf

# Crear subdirectorios
mkdir -p scripts data output logs
```

### 2.2 Configurar Pyenv para el proyecto

```bash
# Desde dentro del directorio del proyecto
cd ~/mi_proyecto_pdf

# Establecer versión de Python para este directorio
pyenv local 3.11.7

# Verificar
python --version
# Salida: Python 3.11.7

# Verificar que está usando la versión correcta
which python
# Salida: /Users/usuario/.pyenv/versions/3.11.7/bin/python
```

### 2.3 Crear entorno virtual

```bash
# Usar venv (incluido en Python 3.3+)
python -m venv venv

# Alternativamente, usar virtualenv (más moderno)
pip install --upgrade pip
pip install virtualenv
virtualenv venv

# Activar entorno virtual

# En macOS/Linux:
source venv/bin/activate

# En Windows (PowerShell):
.\venv\Scripts\Activate.ps1

# En Windows (Git Bash):
source venv/Scripts/activate

# Verificación de activación (debería mostrar (venv) al inicio de la línea):
# (venv) usuario@computadora ~/mi_proyecto_pdf $
```

### 2.4 Crear archivo de requisitos

```bash
# Crear archivo requirements.txt
cat > requirements.txt << 'EOF'
# Conversión HTML a PDF con preservación de estilos
weasyprint==61.0

# Manejo de URLs y recursos web
requests==2.31.0

# Validación de HTML
lxml==4.9.3

# Utilidades de desarrollo
python-dotenv==1.0.0

# Herramientas opcionales
Pillow==10.1.0  # Para procesamiento de imágenes
fonttools==4.47.0  # Para manejo de fuentes
EOF

cat requirements.txt
```

---

## 3. INSTALACIÓN DE DEPENDENCIAS

### 3.1 Instalar dependencias del sistema (importante)

**IMPORTANTE:** WeasyPrint requiere algunas librerías del sistema.

#### macOS:
```bash
# Usar Homebrew
brew install python3 cairo pango gdk-pixbuf libffi

# Si encuentras problemas con GDK-Pixbuf:
brew reinstall gdk-pixbuf
```

#### Linux (Ubuntu/Debian):
```bash
# Dependencias para WeasyPrint
sudo apt-get install -y \
  build-essential \
  python3-dev \
  libcairo2-dev \
  libpango-1.0-0 \
  libpango-cairo-1.0-0 \
  libgdk-pixbuf2.0-0 \
  libffi-dev \
  libssl-dev

# Fuentes para PDF
sudo apt-get install -y fonts-liberation fonts-noto
```

#### Windows (WSL recomendado):
```bash
# Dentro de WSL, ejecutar comandos de Linux
sudo apt-get update
sudo apt-get install -y libcairo2-dev libpango-1.0-0 libpango-cairo-1.0-0 libgdk-pixbuf2.0-0
```

### 3.2 Instalar requisitos de Python

```bash
# Con el entorno virtual activado:
# (venv) usuario@computadora ~/mi_proyecto_pdf $

pip install --upgrade pip setuptools wheel

# Instalar de requirements.txt
pip install -r requirements.txt

# Proceso (ejemplo):
# Collecting weasyprint==61.0
#   Downloading weasyprint-61.0-py3-none-manylinux1_x86_64.whl
# Installing collected packages: ...
# Successfully installed weasyprint-61.0 ...
```

### 3.3 Verificar instalación

```bash
# Verificar que WeasyPrint está correctamente instalado
python -c "from weasyprint import HTML, CSS; print('✓ WeasyPrint instalado correctamente')"

# Salida esperada:
# ✓ WeasyPrint instalado correctamente
```

---

## 4. EXPLICACIÓN DEL SCRIPT

### 4.1 Estructura general

```
html_to_pdf_converter.py
├── Importaciones y configuración
├── setup_logging() - Sistema de logs
├── Constantes de configuración PDF
├── PAGE_BREAK_CSS - CSS para saltos de página
├── ContentAnalyzer - Análisis del HTML
└── HTMLtoPDFConverter - Conversión principal
```

### 4.2 Funciones principales

#### `setup_logging()`
- Configura registro de eventos en archivo y consola
- Crea archivo `conversion.log` con todos los detalles
- Nivel DEBUG para archivo, INFO para consola

#### `ContentAnalyzer`
- Analiza estructura del HTML
- Calcula número de tablas, filas, párrafos
- Estima alturas para planificación de saltos

#### `HTMLtoPDFConverter`
- Clase principal que realiza conversión
- Método `calculate_table_heights()`: previene tablas cortadas
- Método `convert()`: realiza conversión con WeasyPrint

### 4.3 Cálculos de dimensionamiento

```python
# Dimensiones A4
PAGE_HEIGHT_MM = 297  # Altura de página
CONTENT_HEIGHT_MM = 267  # Altura disponible (297 - márgenes)

# Altura estimada de tablas
ROW_HEIGHT_MM = 8
HEADER_HEIGHT_MM = 10
TOTAL_TABLE_HEIGHT = HEADER_HEIGHT_MM + (rows * ROW_HEIGHT_MM)

# Si TOTAL_TABLE_HEIGHT > CONTENT_HEIGHT_MM:
# La tabla requiere múltiples páginas
pages_needed = ceil(TOTAL_TABLE_HEIGHT / CONTENT_HEIGHT_MM)
```

### 4.4 CSS para control de saltos

El script inyecta CSS que:
- Evita saltos dentro de tablas (`page-break-inside: avoid`)
- Mantiene encabezados en primera página (`display: table-header-group`)
- Evita líneas viudas/huérfanas (`orphans: 3; widows: 3`)
- Desactiva sombras en impresión (`@media print`)

---

## 5. EJECUCIÓN PASO A PASO

### 5.1 Estructura de archivos

```bash
# Antes de ejecutar, asegúrate que tengas:
ls -la ~/mi_proyecto_pdf/

# Salida esperada:
# drwxr-xr-x  venv/
# drwxr-xr-x  data/
# drwxr-xr-x  output/
# -rw-r--r--  requirements.txt
# -rw-r--r--  html_to_pdf_converter.py
# -rw-r--r--  index_2.html

# Copiar archivos necesarios
cp index_2.html ~/mi_proyecto_pdf/data/
cp html_to_pdf_converter.py ~/mi_proyecto_pdf/scripts/
```

### 5.2 Preparar directorio de trabajo

```bash
cd ~/mi_proyecto_pdf

# Verificar estructura
tree -L 2  # O: ls -la

# Copiar archivo HTML
cp /ruta/a/tu/index_2.html ./index_2.html

# Cambiar a directorio de scripts (opcional)
cd scripts
```

### 5.3 Ejecutar conversión - Método 1 (Uso básico)

```bash
# Con entorno activado
source venv/bin/activate  # macOS/Linux
# o
.\venv\Scripts\Activate.ps1  # Windows

# Ejecutar con valores por defecto
python html_to_pdf_converter.py ../index_2.html

# Salida esperada:
# 2025-01-15 10:30:45 - HTMLtoPDFConverter - INFO - Entrada: ../index_2.html
# 2025-01-15 10:30:45 - HTMLtoPDFConverter - INFO - Salida: ../index_2_converted.pdf
# ✓ Conversión exitosa: ../index_2_converted.pdf
```

### 5.4 Ejecutar conversión - Método 2 (Con opciones)

```bash
# Especificar archivo de salida
python html_to_pdf_converter.py ../index_2.html -o ../output/memoria_2025_v1.pdf

# Con archivo de log personalizado
python html_to_pdf_converter.py ../index_2.html \
  -o ../output/memoria.pdf \
  --log-file ../logs/conversion_2025.log

# Sin inyección de CSS (si tienes problemas)
python html_to_pdf_converter.py ../index_2.html --no-css-injection
```

### 5.5 Ver resultados

```bash
# Archivo PDF generado
ls -lh index_2_converted.pdf

# Log de conversión
cat conversion.log

# Filtrar solo errores
grep ERROR conversion.log

# Ver análisis de tablas
grep -A 5 "Análisis de tablas:" conversion.log
```

---

## 6. TROUBLESHOOTING

### Problema 1: "ModuleNotFoundError: No module named 'weasyprint'"

```bash
# Solución 1: Verificar entorno virtual activado
which python
# Debe mostrar: /ruta/a/venv/bin/python

# Solución 2: Reinstalar WeasyPrint
pip install --force-reinstall weasyprint==61.0

# Solución 3: Instalar dependencias del sistema
# Ver sección 3.1 para tu sistema operativo
```

### Problema 2: "OSError: cannot open shared object file"

**En Linux:** Faltan librerías del sistema

```bash
# Instalar librerías faltantes
sudo apt-get install -y libcairo2 libpango-1.0-0

# Reinstalar WeasyPrint
pip install --force-reinstall --no-cache-dir weasyprint
```

**En macOS:**

```bash
# Reinstalar con Homebrew
brew uninstall cairo pango gdk-pixbuf --force
brew install cairo pango gdk-pixbuf

# Reinstalar WeasyPrint
pip install --force-reinstall weasyprint
```

### Problema 3: PDF sin estilos/colores

```bash
# Opción 1: Verificar que HTML tiene <style> tags
grep -c "<style" index_2.html

# Opción 2: Ejecutar sin inyección de CSS (testing)
python html_to_pdf_converter.py index_2.html --no-css-injection

# Opción 3: Revisar archivo HTML temporal generado
cat index_2_temp.html | grep -A 5 "<style"
```

### Problema 4: Tablas divididas entre páginas

```bash
# Los estilos CSS inyectados deben prevenir esto
# Si persiste, verificar:

# 1. Revisar estimación de altura de tabla
grep "Tabla" conversion.log

# 2. Aumentar altura estimada en script (línea ~280):
# ROW_HEIGHT_MM = 10  # en lugar de 8

# 3. Reducir márgenes en configuración (líneas ~48-51):
# MARGIN_TOP_MM = 10
# MARGIN_BOTTOM_MM = 10
```

### Problema 5: Fuentes no se ven correctamente

```bash
# macOS
brew install font-roboto font-ubuntu

# Linux
sudo apt-get install -y fonts-liberation fonts-noto fonts-roboto

# Reinstalar WeasyPrint para que detecte fuentes
pip install --force-reinstall weasyprint
```

---

## 7. SCRIPT DE LANZAMIENTO RÁPIDO

Crear archivo `run_conversion.sh` para ejecutar fácilmente:

```bash
#!/bin/bash
# run_conversion.sh - Script para lanzar conversión

# Colores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  HTML to PDF Converter                 ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"

# Cambiar a directorio del proyecto
cd "$(dirname "$0")"

# Verificar entorno virtual
if [ ! -d "venv" ]; then
    echo -e "${RED}✗ Entorno virtual no encontrado${NC}"
    exit 1
fi

# Activar entorno
source venv/bin/activate

# Verificar argumentos
if [ $# -lt 1 ]; then
    echo -e "${RED}Uso: ./run_conversion.sh archivo.html [salida.pdf]${NC}"
    exit 1
fi

INPUT_FILE=$1
OUTPUT_FILE=${2:-"${INPUT_FILE%.html}_converted.pdf"}

echo -e "${GREEN}Entrada: $INPUT_FILE${NC}"
echo -e "${GREEN}Salida: $OUTPUT_FILE${NC}"
echo ""

# Ejecutar conversión
python scripts/html_to_pdf_converter.py "$INPUT_FILE" -o "$OUTPUT_FILE"

# Verificar resultado
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Conversión completada${NC}"
    echo -e "${GREEN}Archivo guardado en: $OUTPUT_FILE${NC}"
else
    echo -e "${RED}✗ Error durante la conversión${NC}"
    echo -e "${BLUE}Revisar logs en: conversion.log${NC}"
fi
```

Hacer el script ejecutable:

```bash
chmod +x run_conversion.sh

# Usar:
./run_conversion.sh index_2.html
./run_conversion.sh index_2.html output/memoria_final.pdf
```

---

## 8. CHECKLIST DE INSTALACIÓN

```bash
# Copiar y pegar paso a paso:

# ✓ Paso 1: Instalar Pyenv
pyenv --version

# ✓ Paso 2: Instalar Python
pyenv install 3.11.7

# ✓ Paso 3: Crear proyecto
mkdir ~/mi_proyecto_pdf && cd ~/mi_proyecto_pdf

# ✓ Paso 4: Configurar Pyenv
pyenv local 3.11.7

# ✓ Paso 5: Crear entorno virtual
python -m venv venv

# ✓ Paso 6: Activar entorno
source venv/bin/activate

# ✓ Paso 7: Instalar requisitos
pip install -r requirements.txt

# ✓ Paso 8: Verificar instalación
python -c "from weasyprint import HTML; print('✓ OK')"

# ✓ Paso 9: Ejecutar conversión
python html_to_pdf_converter.py index_2.html

# ✓ Listo! Tu PDF está en: index_2_converted.pdf
```

---

## 9. REUTILIZACIÓN COMO PLANTILLA

Para usar el HTML como plantilla para futuras memorias:

```bash
# Método 1: Copiar archivo
cp index_2.html nueva_memoria_2025.html

# Método 2: Usar en script
python html_to_pdf_converter.py nueva_memoria_2025.html -o nueva_memoria_2025.pdf

# Método 3: Automatizar múltiples archivos
for archivo in *.html; do
    python html_to_pdf_converter.py "$archivo" \
        -o "output/${archivo%.html}.pdf"
done
```

---

## 10. REFERENCIAS Y DOCUMENTACIÓN

- **Pyenv**: https://github.com/pyenv/pyenv
- **WeasyPrint**: https://weasyprint.org/
- **Virtual Environments**: https://docs.python.org/3/venv/
- **CSS para impresión**: https://www.w3.org/TR/CSS2/page.html

---

**¡Listo! Has completado el tutorial de instalación y uso. 🎉**
