#!/usr/bin/env python3
"""
Convertir Markdown a PDF - Método simple
Instalación: pip install md2pdf
"""

from md2pdf.core import md2pdf
from pathlib import Path
import sys

def markdown_to_pdf_simple(md_file, output_pdf=None):
    if output_pdf is None:
        output_pdf = Path(md_file).stem + '.pdf'

    # CSS básico
    css = """
    body { font-family: Georgia; font-size: 11pt; line-height: 1.6; }
    h1 { font-size: 24pt; border-bottom: 2px solid #333; }
    h2 { font-size: 18pt; margin-top: 20pt; }
    code { background: #f4f4f4; padding: 2px 5px; }
    pre { background: #f8f8f8; padding: 10px; border-left: 3px solid #4a90e2; }
    """

    md2pdf(
        output_pdf,
        md_file_path=md_file,
        css_file_path=None,
        base_url=None
    )
    print(f"✅ PDF creado: {output_pdf}")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Uso: python md_to_pdf_simple.py archivo.md")
        sys.exit(1)
    markdown_to_pdf_simple(sys.argv[1])
