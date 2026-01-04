#!/usr/bin/env python3
"""
Convertir Markdown a PDF usando WeasyPrint
Instalación: pip install markdown weasyprint
"""

import markdown
from weasyprint import HTML, CSS
from pathlib import Path

def markdown_to_pdf(md_file, output_pdf=None):
    md_path = Path(md_file)
    
    if not md_path.exists():
        print(f"❌ Error: Archivo no encontrado: {md_file}")
        return False
    
    try:
        # Leer markdown
        with open(md_path, 'r', encoding='utf-8') as f:
            md_content = f.read()
    except Exception as e:
        print(f"❌ Error leyendo archivo: {e}")
        return False

    try:
        # Convertir MD a HTML
        html_content = markdown.markdown(
            md_content,
            extensions=['extra', 'codehilite', 'toc', 'fenced_code']
        )
    except Exception as e:
        print(f"❌ Error convirtiendo Markdown: {e}")
        return False

    # CSS académico
    css = """
    @page {
        size: A4;
        margin: 2.5cm 2cm;
        @bottom-center { content: counter(page); }
    }
    body {
        font-family: Georgia, serif;
        font-size: 11pt;
        line-height: 1.6;
        color: #222;
        text-align: justify;
    }
    h1 {
        font-size: 24pt;
        margin-top: 30pt;
        border-bottom: 2pt solid #333;
        padding-bottom: 10pt;
        page-break-before: always;
    }
    h2 { 
        font-size: 18pt; 
        margin-top: 20pt; 
        color: #2a2a2a; 
    }
    h3 { 
        font-size: 14pt; 
        margin-top: 15pt; 
        color: #3a3a3a; 
    }
    code {
        font-family: 'Courier New', monospace;
        font-size: 9pt;
        background: #f4f4f4;
        padding: 2pt 4pt;
        border-radius: 3pt;
    }
    pre {
        background: #f8f8f8;
        border-left: 3pt solid #4a90e2;
        padding: 10pt;
        font-size: 9pt;
        overflow-x: auto;
        page-break-inside: avoid;
    }
    pre code {
        background: transparent;
        padding: 0;
    }
    blockquote {
        font-style: italic;
        border-left: 3pt solid #ccc;
        padding-left: 15pt;
        color: #555;
        margin: 15pt 0;
    }
    table {
        border-collapse: collapse;
        margin: 15pt 0;
        width: 100%;
    }
    th {
        background: #4a90e2;
        color: white;
        padding: 8pt;
        border: 1pt solid #ddd;
        text-align: left;
    }
    td {
        padding: 6pt;
        border: 1pt solid #ddd;
    }
    img {
        max-width: 100%;
        height: auto;
        margin: 15pt 0;
    }
    """

    full_html = f'<!DOCTYPE html><html><head><meta charset="utf-8"></head><body>{html_content}</body></html>'

    if output_pdf is None:
        output_pdf = md_path.with_suffix('.pdf')
    else:
        output_pdf = Path(output_pdf)

    try:
        HTML(string=full_html).write_pdf(str(output_pdf), stylesheets=[CSS(string=css)])
        print(f"✅ PDF creado: {output_pdf.absolute()}")
        return True
    except Exception as e:
        print(f"❌ Error generando PDF: {e}")
        return False

if __name__ == '__main__':
    import sys
    if len(sys.argv) < 2:
        print("Uso: python md_to_pdf_weasyprint.py archivo.md [salida.pdf]")
        sys.exit(1)
    
    output = sys.argv[2] if len(sys.argv) > 2 else None
    success = markdown_to_pdf(sys.argv[1], output)
    sys.exit(0 if success else 1)
