#!/bin/zsh
# setup_weasyprint_mac.zsh
# Script para instalar y reparar dependencias de WeasyPrint en macOS
# Compatible con Homebrew (Intel y Apple Silicon)

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_section() {
    echo ""
    echo "${BLUE}================================================================${NC}"
    echo "${BLUE}$1${NC}"
    echo "${BLUE}================================================================${NC}"
}

print_ok() { echo "${GREEN}✓ $1${NC}"; }
print_warn() { echo "${YELLOW}⚠️ $1${NC}"; }
print_err() { echo "${RED}✗ $1${NC}"; }

print_section "1. Detectando Homebrew..."
if ! command -v brew > /dev/null; then
    print_err "Homebrew no está instalado. Instálalo desde https://brew.sh/"
    exit 1
else
    print_ok "Homebrew encontrado: $(brew --version | head -n1)"
fi

print_section "2. Actualizando Homebrew y fórmulas..."
brew update && brew upgrade

print_section "3. Instalando dependencias del sistema para WeasyPrint..."
brew install cairo pango gdk-pixbuf libffi pygobject3 gtk+3 || brew reinstall cairo pango gdk-pixbuf libffi pygobject3 gtk+3

print_section "4. (Opcional) Instalando XQuartz si necesitas soporte GTK extra..."
if ! command -v Xquartz > /dev/null && ! [ -d "/Applications/Utilities/XQuartz.app" ]; then
    print_warn "XQuartz no detectado. Recomendado para algunos sistemas."
    print_warn "Descárgalo e instálalo manualmente si trabajas con SVG o gráficos complejos:"
    print_warn "https://www.xquartz.org/"
else
    print_ok "XQuartz ya está instalado."
fi

print_section "5. Verificando variables de entorno HOMBREW..."
BREW_PREFIX=$(brew --prefix)
if [[ "$BREW_PREFIX" == "/opt/homebrew" ]]; then
    # Apple Silicon (M1/M2/M3)
    print_ok "Apple Silicon detectado."
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    source ~/.zprofile
else
    print_ok "Intel detectado."
    echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
    source ~/.zprofile
fi

print_section "6. Reinstalando WeasyPrint en tu entorno virtual..."
if [[ -d "venv" ]]; then
    source venv/bin/activate
    pip install --force-reinstall weasyprint
    deactivate
    print_ok "WeasyPrint reinstalado dentro de venv."
else
    print_warn "No se encontró el entorno virtual venv. Ejecuta: python3 -m venv venv && source venv/bin/activate"
fi

print_section "7. Prueba rápida de importación (WeasyPrint)..."
source venv/bin/activate
python -c "from weasyprint import HTML; print('✓ WeasyPrint importado correctamente')" && print_ok "Listo para convertir HTML a PDF."
deactivate

print_section "8. Verifica que las librerías estén enlazadas correctamente..."
for lib in cairo pango gobject-2.0 gdk_pixbuf-2.0 ffi; do
    brew list "$lib" &>/dev/null && print_ok "$lib instalado" || print_warn "$lib FALTA"
done

print_section "9. Consejos finales"
echo "${GREEN}Si WeasyPrint aún falla con OSError, reinicia tu terminal y repite la activación del entorno:${NC}"
echo "${YELLOW}"
echo "source venv/bin/activate"
echo "python html_to_pdf_converter.py index_2.html"
echo "${NC}"

print_ok "Proceso completado. Intenta tu conversión de nuevo."
