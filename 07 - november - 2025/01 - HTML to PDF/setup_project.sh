#!/bin/bash
# ============================================================================
# setup_project.sh - Script de configuración automática
# ============================================================================
# Uso: bash setup_project.sh
# Este script configura todo el proyecto automáticamente

set -e  # Salir si algún comando falla

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para imprimir mensajes
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }

# Encabezado
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  HTML to PDF Converter - Setup Automático              ║${NC}"
echo -e "${BLUE}║  Configuración completa del proyecto                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================================
# Paso 1: Verificar requisitos del sistema
# ============================================================================
print_info "Paso 1: Verificando requisitos del sistema..."

if ! command -v python3 &> /dev/null; then
    print_error "Python3 no está instalado"
    exit 1
fi
PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
print_success "Python3 encontrado: $PYTHON_VERSION"

if ! command -v pip3 &> /dev/null; then
    print_error "pip3 no está instalado"
    exit 1
fi
print_success "pip3 encontrado"

# ============================================================================
# Paso 2: Verificar/instalar Pyenv (opcional)
# ============================================================================
print_info "Paso 2: Verificando Pyenv..."

if command -v pyenv &> /dev/null; then
    PYENV_VERSION=$(pyenv --version)
    print_success "Pyenv encontrado: $PYENV_VERSION"
else
    print_warning "Pyenv no está instalado (opcional)"
    print_info "Para instalar: https://github.com/pyenv/pyenv"
fi

# ============================================================================
# Paso 3: Crear estructura de directorios
# ============================================================================
print_info "Paso 3: Creando estructura de directorios..."

mkdir -p scripts data output logs
print_success "Directorios creados:
  - scripts/    (scripts Python)
  - data/       (archivos de entrada)
  - output/     (archivos de salida)
  - logs/       (archivos de log)"

# ============================================================================
# Paso 4: Crear entorno virtual
# ============================================================================
print_info "Paso 4: Creando entorno virtual..."

if [ -d "venv" ]; then
    print_warning "Entorno virtual ya existe"
    read -p "¿Deseas recrearlo? (s/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        rm -rf venv
        python3 -m venv venv
        print_success "Entorno virtual recreado"
    fi
else
    python3 -m venv venv
    print_success "Entorno virtual creado"
fi

# ============================================================================
# Paso 5: Activar entorno virtual
# ============================================================================
print_info "Paso 5: Activando entorno virtual..."

source venv/bin/activate
print_success "Entorno virtual activado"

# ============================================================================
# Paso 6: Actualizar pip y setuptools
# ============================================================================
print_info "Paso 6: Actualizando pip y setuptools..."

pip install --upgrade pip setuptools wheel > /dev/null 2>&1
print_success "pip, setuptools y wheel actualizados"

# ============================================================================
# Paso 7: Instalar dependencias del sistema (si es posible)
# ============================================================================
print_info "Paso 7: Verificando dependencias del sistema..."

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    print_info "Sistema operativo: Linux"
    if command -v apt-get &> /dev/null; then
        print_info "Instalando dependencias de sistema (requiere sudo)..."
        sudo apt-get update > /dev/null 2>&1
        sudo apt-get install -y \
            libcairo2-dev \
            libpango-1.0-0 \
            libpango-cairo-1.0-0 \
            libgdk-pixbuf2.0-0 \
            libffi-dev \
            fonts-liberation \
            fonts-noto \
            2>/dev/null || true
        print_success "Dependencias de sistema instaladas"
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    print_info "Sistema operativo: macOS"
    if command -v brew &> /dev/null; then
        print_info "Instalando dependencias con Homebrew..."
        brew install cairo pango gdk-pixbuf libffi > /dev/null 2>&1 || true
        print_success "Dependencias instaladas"
    else
        print_warning "Homebrew no encontrado. Instálalo desde: https://brew.sh"
    fi
else
    print_warning "No se pueden instalar automáticamente las dependencias del sistema"
fi

# ============================================================================
# Paso 8: Instalar requisitos de Python
# ============================================================================
print_info "Paso 8: Instalando requisitos de Python..."

if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
    print_success "Requisitos instalados"
else
    print_warning "requirements.txt no encontrado"
    print_info "Instalando WeasyPrint manualmente..."
    pip install weasyprint==61.0 requests lxml python-dotenv Pillow fonttools
    print_success "Dependencias instaladas"
fi

# ============================================================================
# Paso 9: Verificar instalación
# ============================================================================
print_info "Paso 9: Verificando instalación..."

if python -c "from weasyprint import HTML, CSS; print('OK')" 2>/dev/null; then
    print_success "WeasyPrint instalado correctamente"
else
    print_error "Error al instalar WeasyPrint"
    print_info "Intenta: pip install --force-reinstall weasyprint"
    exit 1
fi

# ============================================================================
# Paso 10: Crear archivo .env
# ============================================================================
print_info "Paso 10: Creando archivo de configuración..."

if [ ! -f ".env" ]; then
    cat > .env << 'EOF'
# Configuración del proyecto HTML to PDF
# Estos valores pueden ser modificados según necesidad

# Formato del PDF (A4, Letter, etc.)
PDF_FORMAT=A4

# Márgenes en milímetros
MARGIN_TOP=15
MARGIN_BOTTOM=15
MARGIN_LEFT=15
MARGIN_RIGHT=15

# Inyección automática de CSS para control de saltos
INJECT_PAGE_BREAK_CSS=true

# Archivo de log
LOG_FILE=conversion.log

# Zoom del PDF (1.0 = 100%)
PDF_ZOOM=1.0

# Presentational hints (true/false)
PRESENTATIONAL_HINTS=true
EOF
    print_success ".env creado"
else
    print_warning ".env ya existe"
fi

# ============================================================================
# Paso 11: Mostrar instrucciones de uso
# ============================================================================
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ SETUP COMPLETADO EXITOSAMENTE                      ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

print_success "El proyecto está listo para usar"
echo ""
echo -e "${BLUE}📖 PRÓXIMOS PASOS:${NC}"
echo ""
echo "1. Copiar tu archivo HTML a la carpeta 'data/':"
echo "   cp tu_archivo.html data/"
echo ""
echo "2. Copiar el script de conversión a 'scripts/':"
echo "   cp html_to_pdf_converter.py scripts/"
echo ""
echo "3. Ejecutar conversión:"
echo "   source venv/bin/activate"
echo "   python scripts/html_to_pdf_converter.py data/tu_archivo.html"
echo ""
echo "4. El PDF se creará en:"
echo "   output/tu_archivo.pdf"
echo ""
echo -e "${BLUE}📚 DOCUMENTACIÓN:${NC}"
echo "  • Tutorial completo: TUTORIAL_COMPLETO.md"
echo "  • Cálculos de dimensionamiento: CALCULOS_DIMENSIONAMIENTO.md"
echo "  • Configuración: .env"
echo ""
echo -e "${BLUE}❓ AYUDA:${NC}"
echo "  • Ver logs: tail -f conversion.log"
echo "  • Ver últimos errores: grep ERROR conversion.log"
echo ""

# ============================================================================
# Paso 12: Crear script de lanzamiento rápido
# ============================================================================
if [ ! -f "run_conversion.sh" ]; then
    cat > run_conversion.sh << 'EOF'
#!/bin/bash
# Script rápido para ejecutar conversiones

source venv/bin/activate

if [ $# -lt 1 ]; then
    echo "Uso: ./run_conversion.sh archivo.html [salida.pdf]"
    exit 1
fi

INPUT=$1
OUTPUT=${2:-"output/${INPUT%.html}.pdf"}

python scripts/html_to_pdf_converter.py "data/$INPUT" -o "$OUTPUT"
EOF
    chmod +x run_conversion.sh
    print_success "Script de lanzamiento creado: run_conversion.sh"
fi

echo ""
print_success "¡Listo! Puedes empezar a convertir tus archivos HTML a PDF"
echo ""
