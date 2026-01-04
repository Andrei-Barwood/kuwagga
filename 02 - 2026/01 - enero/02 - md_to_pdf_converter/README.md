# 📄 Conversor Inteligente de Markdown a PDF

Aplicación que selecciona automáticamente el mejor método disponible para convertir archivos Markdown a PDF, evaluando las características del documento y los métodos instalados en el sistema.

## 🚀 Características

- ✅ **Selección automática inteligente** del mejor método según:
  - Métodos disponibles en el sistema
  - Características del documento (código, ecuaciones LaTeX, tablas, etc.)
  - Calidad y confiabilidad de cada método
- ✅ **Detección automática** de métodos instalados
- ✅ **Análisis del documento** para optimizar la conversión
- ✅ **Fallback automático** si un método falla
- ✅ **Manejo robusto de errores**
- ✅ **Output informativo** con colores (opcional)

## 📦 Instalación

### Opción 1: Instalar método recomendado (WeasyPrint)

```bash
pip install markdown weasyprint
```

### Opción 2: Instalar todas las dependencias

```bash
pip install -r requirements.txt
```

### Opción 3: Instalar métodos específicos

```bash
# Solo WeasyPrint (recomendado)
pip install markdown weasyprint

# Solo Pandoc (requiere también instalar pandoc en el sistema)
pip install pypandoc
# Luego instalar Pandoc: https://pandoc.org/installing.html

# Solo md2pdf (simple)
pip install md2pdf

# Solo ReportLab
pip install reportlab markdown beautifulsoup4
```

## 🎯 Uso

### Modo interactivo (recomendado para principiantes)

Ejecuta el script sin argumentos para entrar en modo interactivo:

```bash
python md_to_pdf.py
```

El script te guiará paso a paso:
1. **Sugerencia para macOS**: Te mostrará cómo copiar la ruta del archivo desde Finder
   - Abre Finder y navega hasta tu archivo Markdown
   - Haz clic derecho (o Control+clic) en el archivo
   - Mantén presionada la tecla Option (⌥)
   - Selecciona "Copiar [nombre] como nombre de ruta"
   - Pega la ruta en el programa (Cmd+V)
2. **Selección de destino**: Te preguntará si deseas guardar el PDF en:
   - La misma carpeta que el archivo Markdown (recomendado)
   - Un directorio específico que tú elijas

### Uso básico (línea de comandos)

```bash
python md_to_pdf.py documento.md
```

### Especificar archivo de salida

```bash
python md_to_pdf.py documento.md -o salida.pdf
```

### Forzar un método específico

```bash
python md_to_pdf.py documento.md --method weasyprint
```

### Modo silencioso

```bash
python md_to_pdf.py documento.md --quiet
```

### Modo verbose

```bash
python md_to_pdf.py documento.md --verbose
```

### Forzar modo interactivo

```bash
python md_to_pdf.py --interactive
```

## 📊 Métodos Disponibles

### 1. WeasyPrint ⭐ RECOMENDADO
- **Mejor para**: Documentos académicos con código
- **Calidad**: ⭐⭐⭐⭐⭐
- **Instalación**: `pip install markdown weasyprint`
- **Ventajas**:
  - Excelente renderizado de código con syntax highlighting
  - Soporte CSS completo
  - Genera PDFs profesionales
  - Maneja bien tablas y listas

### 2. Pandoc ⭐ MÁS POTENTE
- **Mejor para**: Documentos con ecuaciones LaTeX
- **Calidad**: ⭐⭐⭐⭐⭐
- **Instalación**: `pip install pypandoc` + instalar Pandoc en el sistema
- **Ventajas**:
  - El estándar de facto para conversión de documentos
  - Soporte completo de LaTeX para ecuaciones
  - Tabla de contenidos automática
  - Numeración de secciones

### 3. md2pdf ⭐ MÁS FÁCIL
- **Mejor para**: Conversión rápida sin complicaciones
- **Calidad**: ⭐⭐⭐
- **Instalación**: `pip install md2pdf`
- **Ventajas**:
  - Instalación simple
  - Sin dependencias externas
  - Funciona out-of-the-box

### 4. ReportLab ⭐ MÁXIMO CONTROL
- **Mejor para**: Diseño personalizado avanzado
- **Calidad**: ⭐⭐⭐⭐
- **Instalación**: `pip install reportlab markdown beautifulsoup4`
- **Ventajas**:
  - Control pixel-perfect del diseño
  - Ideal para documentos corporativos
  - Customización total

## 🔍 Cómo Funciona la Selección

La aplicación analiza:

1. **Métodos disponibles**: Detecta qué métodos están instalados
2. **Características del documento**:
   - Código (bloques de código, inline code)
   - Ecuaciones LaTeX
   - Tablas
   - Imágenes
   - Matemáticas avanzadas
   - Longitud del documento
3. **Scoring**: Asigna un score a cada método según su adecuación
4. **Selección**: Elige el método con mayor score
5. **Fallback**: Si falla, intenta métodos alternativos automáticamente

## 📝 Ejemplos

### Ejemplo 1: Modo interactivo

```bash
$ python md_to_pdf.py

======================================================================
📄 MODO INTERACTIVO - Conversión Markdown a PDF
======================================================================

💡 SUGERENCIA:
   1. Abre Finder y navega hasta tu archivo Markdown
   2. Haz clic derecho (o Control+clic) en el archivo
   3. Mantén presionada la tecla Option (⌥)
   4. Selecciona 'Copiar [nombre] como nombre de ruta'
   5. Pega la ruta aquí (Cmd+V)

📋 Pega la ruta del archivo Markdown (o presiona Enter para cancelar):
   /Users/usuario/Documentos/mi_documento.md

======================================================================
📁 DESTINO DEL ARCHIVO PDF
======================================================================

¿Dónde deseas guardar el PDF convertido?

   1. En la misma carpeta que el archivo Markdown (recomendado)
   2. En un directorio específico

   Selecciona una opción (1 o 2, Enter para opción 1): 1

🔍 Detectando métodos disponibles...
  ✅ Weasyprint disponible
🔍 Analizando documento...
  Características detectadas: has_code, has_tables, is_long
🎯 Método seleccionado: Weasyprint (score: 25)
🔄 Convirtiendo con WeasyPrint...
✅ ÉXITO: PDF generado con WeasyPrint
📁 Ubicación: /Users/usuario/Documentos/mi_documento.pdf
📊 Tamaño: 2.45 MB
```

### Ejemplo 2: Conversión simple (línea de comandos)

```bash
$ python md_to_pdf.py mi_documento.md

🔍 Detectando métodos disponibles...
  ✅ Weasyprint disponible
  ✅ Pandoc disponible
  ❌ md2pdf no disponible
  ❌ Reportlab no disponible
🔍 Analizando documento...
  Características detectadas: has_code, has_tables, is_long
🎯 Método seleccionado: Weasyprint (score: 25)
🔄 Convirtiendo con WeasyPrint...
✅ ÉXITO: PDF generado con WeasyPrint
📁 Ubicación: /ruta/a/mi_documento.pdf
📊 Tamaño: 2.45 MB
```

### Ejemplo 3: Forzar método específico

```bash
$ python md_to_pdf.py documento.md --method pandoc

📌 Usando método preferido: pandoc
🔄 Convirtiendo con Pandoc...
✅ ÉXITO: PDF generado con Pandoc
```

## 🔧 Troubleshooting

### Error: "No se encontró ningún método de conversión disponible"

**Solución**: Instalar al menos un método:
```bash
pip install markdown weasyprint
```

### Error: "WeasyPrint no instalado"

**Solución**: 
```bash
pip install markdown weasyprint
```

### Error: "Pandoc not found"

**Solución**: 
1. Instalar pypandoc: `pip install pypandoc`
2. Instalar Pandoc en el sistema: https://pandoc.org/installing.html

### Error: "OSError: cannot load library 'gobject-2.0-0'" (Windows)

**Solución**: 
- Usar otro método (Pandoc o md2pdf)
- O actualizar WeasyPrint: `pip install --upgrade weasyprint`

### PDF sale con mal formato

**Soluciones**:
1. Verificar que el archivo .md tenga encoding UTF-8
2. Usar WeasyPrint o Pandoc para mejor calidad
3. Revisar que no haya caracteres especiales problemáticos

## 📚 Scripts Individuales

Si prefieres usar un método específico directamente, también están disponibles:

- `md_to_pdf_weasyprint.py` - Solo WeasyPrint
- `md_to_pdf_pandoc.py` - Solo Pandoc
- `md_to_pdf_simple.py` - Solo md2pdf
- `md_to_pdf_reportlab.py` - Solo ReportLab
- `md_to_pdf_auto.py` - Versión anterior (menos inteligente)

## 🎨 Personalización

Para personalizar estilos CSS, edita el método correspondiente en `md_to_pdf.py` o usa los scripts individuales.

## 📄 Licencia

Este proyecto es de código abierto y está disponible para uso libre.

## 🤝 Contribuciones

Las mejoras y correcciones son bienvenidas. Si encuentras problemas o tienes sugerencias, por favor reporta issues o envía pull requests.

---

**¡Listo para convertir tus documentos Markdown a PDF de forma inteligente! 🚀**

