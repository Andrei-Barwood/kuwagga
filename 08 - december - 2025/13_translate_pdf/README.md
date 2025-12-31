# 📄 Traductor de PDFs

Aplicación con interfaz gráfica para traducir documentos PDF de un idioma a otro, preservando el formato básico y generando un nuevo PDF con el texto traducido.

![Python](https://img.shields.io/badge/Python-3.8+-blue.svg)
![Platform](https://img.shields.io/badge/Platform-macOS%20|%20Windows%20|%20Linux-lightgrey.svg)

## ✨ Características

- **Interfaz gráfica intuitiva** con tkinter
- **Múltiples servicios de traducción**: Google Translate, MyMemory
- **35+ idiomas soportados** incluyendo español, inglés, francés, alemán, chino, japonés, etc.
- **Preservación de formato**: mantiene la estructura por páginas
- **Traducción selectiva**: opción para traducir solo páginas específicas
- **Caché inteligente**: evita re-traducir texto repetido (encabezados, pies de página)
- **Reintentos automáticos** con backoff exponencial para manejar límites de API
- **Detección de PDFs escaneados**: avisa cuando se requiere OCR
- **Log detallado** del proceso de traducción

## 📋 Requisitos

- Python 3.8 o superior
- tkinter (generalmente incluido con Python)
- Conexión a internet (para servicios de traducción)

## 🚀 Instalación

### 1. Clonar o descargar el proyecto

```bash
cd /ruta/al/proyecto/13_translate_pdf
```

### 2. Crear entorno virtual (recomendado)

```bash
python3 -m venv venv
source venv/bin/activate  # macOS/Linux
# o en Windows:
# venv\Scripts\activate
```

### 3. Instalar dependencias

```bash
pip install -r requirements.txt
```

### 4. Verificar tkinter (si es necesario)

En **macOS** y **Windows**, tkinter viene incluido con Python.

En **Linux** (Ubuntu/Debian):
```bash
sudo apt install python3-tk
```

## 💻 Uso

### Ejecutar la aplicación

```bash
python translate_pdf.py
```

### Pasos para traducir un PDF:

1. **Seleccionar archivo**: Haz clic en "Examinar..." y elige el PDF a traducir
2. **Configurar idiomas**: Selecciona el idioma origen y destino
3. **Elegir servicio**: Google Translate (recomendado) o MyMemory
4. **Páginas específicas** (opcional): Ingresa rangos como `1,3,5-10` o deja vacío para todas
5. **Iniciar**: Clic en "▶ Iniciar Traducción"

El PDF traducido se guardará en la misma carpeta con el sufijo `_traducido.pdf`.

### Ejemplo de uso desde terminal (sin GUI)

```python
from translate_pdf import extraer_texto_pdf, traducir_texto, generar_pdf_traducido

# Extraer texto
paginas = extraer_texto_pdf("documento.pdf")

# Traducir cada página
for pagina in paginas:
    pagina["texto_traducido"] = traducir_texto(
        pagina["texto"],
        idioma_origen="en",
        idioma_destino="es",
        servicio="google"
    )

# Generar PDF
generar_pdf_traducido(paginas, "documento_traducido.pdf")
```

## 🌐 Idiomas Soportados

| Idioma | Código | Idioma | Código |
|--------|--------|--------|--------|
| Español | es | Inglés | en |
| Francés | fr | Alemán | de |
| Italiano | it | Portugués | pt |
| Ruso | ru | Chino (Simp.) | zh-CN |
| Japonés | ja | Coreano | ko |
| Árabe | ar | Hindi | hi |
| Holandés | nl | Polaco | pl |
| Turco | tr | Sueco | sv |
| Griego | el | Hebreo | he |
| ... y más | | | |

## 📁 Estructura del Proyecto

```
13_translate_pdf/
├── translate_pdf.py    # Aplicación principal
├── requirements.txt    # Dependencias Python
└── README.md          # Este archivo
```

## ⚠️ Limitaciones y Notas

### PDFs Escaneados
Los PDFs que son imágenes escaneadas (sin texto seleccionable) **no pueden ser traducidos directamente**. La aplicación detectará esto y mostrará un aviso. Para estos casos, se requiere OCR:

```bash
# Instalar Tesseract OCR
brew install tesseract tesseract-lang  # macOS
sudo apt install tesseract-ocr         # Ubuntu

# Instalar binding de Python
pip install pytesseract Pillow
```

### Límites de API
- **Google Translate**: ~5000 caracteres por solicitud
- **MyMemory**: 10,000 caracteres/día (gratuito), más con API key

La aplicación divide automáticamente textos largos y aplica pausas entre solicitudes para evitar bloqueos.

### Formato del PDF Generado
El PDF traducido mantiene la separación por páginas pero usa un formato de texto estándar. No preserva:
- Fuentes originales exactas
- Imágenes del PDF original
- Diseño de múltiples columnas
- Tablas complejas

## 🔧 Solución de Problemas

### "No module named 'tkinter'"
```bash
# Ubuntu/Debian
sudo apt install python3-tk

# Fedora
sudo dnf install python3-tkinter

# macOS (reinstalar Python con soporte tk)
brew install python-tk
```

### "pdfplumber no puede abrir el PDF"
- Verificar que el PDF no esté protegido con contraseña
- Intentar abrir el PDF con otro visor para confirmar que no está corrupto

### Traducción muy lenta
- Los servicios gratuitos tienen límites de velocidad
- La aplicación incluye pausas automáticas para evitar bloqueos
- Considera usar páginas específicas para documentos grandes

## 📝 Licencia

Este proyecto es de uso libre. Siéntete libre de modificarlo y distribuirlo.

## 🙏 Créditos

- [pdfplumber](https://github.com/jsvine/pdfplumber) - Extracción de texto de PDFs
- [reportlab](https://www.reportlab.com/) - Generación de PDFs
- [deep-translator](https://github.com/nidhaloff/deep-translator) - API de traducción

