#!/usr/bin/env python3
"""
Convertir Markdown a PDF usando Pandoc
Instalación: pip install pypandoc
Requiere: pandoc instalado en el sistema (https://pandoc.org/installing.html)
"""

import pypandoc
from pathlib import Path
import sys

def markdown_to_pdf_pandoc(md_file, output_pdf=None):
    if output_pdf is None:
        output_pdf = Path(md_file).stem + '.pdf'

    # Opciones de Pandoc para PDF académico
    extra_args = [
        '--pdf-engine=xelatex',  # Motor LaTeX
        '--variable', 'geometry:margin=2.5cm',
        '--variable', 'fontsize=11pt',
        '--variable', 'documentclass=article',
        '--variable', 'papersize=a4',
        '--highlight-style=tango',  # Syntax highlighting
        '--toc',  # Tabla de contenidos
        '--number-sections',  # Numerar secciones
        '-V', 'colorlinks=true',
        '-V', 'linkcolor=blue',
        '-V', 'urlcolor=blue'
    ]

    try:
        pypandoc.convert_file(
            md_file,
            'pdf',
            outputfile=output_pdf,
            extra_args=extra_args
        )
        print(f"✅ PDF creado: {output_pdf}")
    except RuntimeError as e:
        print(f"❌ Error: {e}")
        print("Asegúrate de tener Pandoc instalado: https://pandoc.org/installing.html")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Uso: python md_to_pdf_pandoc.py archivo.md")
        sys.exit(1)
    markdown_to_pdf_pandoc(sys.argv[1])
