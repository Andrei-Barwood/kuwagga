# 📄 Guía Completa: Convertir Markdown a PDF

Este paquete contiene 4 scripts diferentes para convertir tu ensayo Markdown a PDF profesional.

## 🎯 Scripts Disponibles

### 1️⃣ **md_to_pdf_weasyprint.py** ⭐ RECOMENDADO
- **Mejor para**: Documentos académicos con código
- **Calidad**: ⭐⭐⭐⭐⭐
- **Instalación**: `pip install markdown weasyprint`
- **Ventajas**:
  - Excelente renderizado de código con syntax highlighting
  - Soporte CSS completo (control total de diseño)
  - Genera PDFs profesionales
  - Maneja bien tablas y listas
- **Uso**:
  ```bash
  python md_to_pdf_weasyprint.py StormV-Ensayo-Filosofia-Futurista-Aviacion-2026.md
  ```

### 2️⃣ **md_to_pdf_pandoc.py** ⭐ MÁS POTENTE
- **Mejor para**: Documentos con ecuaciones LaTeX
- **Calidad**: ⭐⭐⭐⭐⭐
- **Instalación**: 
  ```bash
  pip install pypandoc
  # Además requiere Pandoc instalado en el sistema:
  # Windows: choco install pandoc
  # Mac: brew install pandoc
  # Linux: sudo apt install pandoc
  ```
- **Ventajas**:
  - El estándar de facto para conversión de documentos
  - Soporte completo de LaTeX para ecuaciones
  - Tabla de contenidos automática
  - Numeración de secciones
- **Uso**:
  ```bash
  python md_to_pdf_pandoc.py StormV-Ensayo-Filosofia-Futurista-Aviacion-2026.md
  ```

### 3️⃣ **md_to_pdf_simple.py** ⭐ MÁS FÁCIL
- **Mejor para**: Conversión rápida sin complicaciones
- **Calidad**: ⭐⭐⭐
- **Instalación**: `pip install md2pdf`
- **Ventajas**:
  - Instalación simple
  - Sin dependencias externas
  - Funciona out-of-the-box
- **Limitaciones**:
  - Menor control sobre diseño
  - CSS básico
- **Uso**:
  ```bash
  python md_to_pdf_simple.py StormV-Ensayo-Filosofia-Futurista-Aviacion-2026.md
  ```

### 4️⃣ **md_to_pdf_reportlab.py** ⭐ MÁXIMO CONTROL
- **Mejor para**: Diseño personalizado avanzado
- **Calidad**: ⭐⭐⭐⭐
- **Instalación**: `pip install reportlab markdown beautifulsoup4`
- **Ventajas**:
  - Control pixel-perfect del diseño
  - Ideal para documentos corporativos
  - Customización total
- **Limitaciones**:
  - Más complejo de modificar
  - Requiere conocer API de ReportLab
- **Uso**:
  ```bash
  python md_to_pdf_reportlab.py StormV-Ensayo-Filosofia-Futurista-Aviacion-2026.md
  ```

---

## 🚀 Instalación Rápida (método recomendado)

```bash
# Opción 1: WeasyPrint (mejor balance calidad/simplicidad)
pip install markdown weasyprint

# Ejecutar
python md_to_pdf_weasyprint.py StormV-Ensayo-Filosofia-Futurista-Aviacion-2026.md
```

---

## 📦 Instalar todas las dependencias

```bash
# Crear entorno virtual (recomendado)
python -m venv venv
source venv/bin/activate  # Linux/Mac
# o
venv\Scripts\activate  # Windows

# Instalar todas las bibliotecas
pip install markdown weasyprint pypandoc md2pdf reportlab beautifulsoup4

# Si usas Pandoc, instalarlo también:
# https://pandoc.org/installing.html
```

---

## 🎨 Personalizar el Estilo

### Modificar CSS en WeasyPrint

Edita el archivo `md_to_pdf_weasyprint.py` y busca la sección `css = """`:

```python
css = """
    @page {
        size: A4;
        margin: 2.5cm 2cm;  # Ajustar márgenes
    }
    body {
        font-family: Georgia, serif;  # Cambiar fuente
        font-size: 11pt;  # Cambiar tamaño
        line-height: 1.6;  # Ajustar interlineado
    }
    h1 {
        color: #1a1a1a;  # Color de encabezados
        font-size: 24pt;  # Tamaño de títulos
    }
"""
```

### Agregar portada

Añade al inicio del archivo Markdown:

```markdown
---
title: StormV - Ensayo Filosófico-Técnico
author: [Tu Nombre]
date: Enero 2026
---

# Portada

**StormV: Filosofía Futurista y Aviación 2026**

*Un ensayo sobre la intersección de programación, posthumanismo y tecnología aeronáutica*

---
```

---

## 🔧 Troubleshooting

### Error: "ModuleNotFoundError: No module named 'weasyprint'"
**Solución**: `pip install weasyprint`

### Error: "OSError: cannot load library 'gobject-2.0-0'"
**Solución (Windows)**: 
```bash
pip install --upgrade weasyprint
# O usar método alternativo (Pandoc o Simple)
```

### Error: "Pandoc not found"
**Solución**: Instalar Pandoc desde https://pandoc.org/installing.html

### PDF sale con mal formato
**Solución**: 
1. Verifica que el archivo .md tenga encoding UTF-8
2. Usa WeasyPrint o Pandoc para mejor calidad
3. Revisa que no haya caracteres especiales problemáticos

---

## 📊 Comparación de Métodos

| Método | Calidad | Facilidad | Velocidad | Ecuaciones LaTeX | Código |
|--------|---------|-----------|-----------|------------------|--------|
| WeasyPrint | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Pandoc | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| Simple | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐ | ⭐⭐⭐ |
| ReportLab | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ |

---

## 💡 Recomendación Final

**Para tu ensayo StormV** (documento académico de 22,000 palabras con código Python):

1. **Primera opción**: `md_to_pdf_weasyprint.py`
   - Excelente balance calidad/facilidad
   - Renderiza código perfectamente
   - Instalación simple

2. **Segunda opción**: `md_to_pdf_pandoc.py`
   - Si necesitas LaTeX avanzado
   - Si quieres tabla de contenidos automática
   - Requiere instalación de Pandoc

3. **Opción rápida**: `md_to_pdf_simple.py`
   - Para pruebas rápidas
   - Menor calidad pero funcional

---

## 📝 Ejemplo de Uso Completo

```bash
# 1. Instalar dependencias
pip install markdown weasyprint

# 2. Convertir a PDF
python md_to_pdf_weasyprint.py StormV-Ensayo-Filosofia-Futurista-Aviacion-2026.md

# 3. El PDF se generará en el mismo directorio:
# StormV-Ensayo-Filosofia-Futurista-Aviacion-2026.pdf

# 4. Verificar resultado
# Abre el PDF con tu lector favorito
```

---

## 🎓 Notas para Documento Académico

Tu ensayo incluye:
- ✅ 18 partes estructuradas
- ✅ Código Python con syntax highlighting
- ✅ Referencias bibliográficas
- ✅ Ecuaciones (formato LaTeX con \( \))
- ✅ Tablas y listas
- ✅ Citas en blockquotes

**WeasyPrint** maneja todo esto perfectamente. El PDF resultante será:
- Formato A4
- Márgenes profesionales (2.5cm)
- Numeración de páginas
- Encabezados jerárquicos
- Código con fondo gris y borde azul
- Fuente Georgia (serif académico)

---

## 📮 Soporte

Si encuentras problemas:
1. Verifica versiones: `pip list | grep -i weasyprint`
2. Prueba método alternativo (Pandoc o Simple)
3. Revisa encoding del archivo MD: debe ser UTF-8

---

**¡Listo para generar tu PDF profesional! 🚀**
