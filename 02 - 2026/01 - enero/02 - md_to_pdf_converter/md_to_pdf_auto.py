#!/usr/bin/env python3
"""
Conversor automático Markdown → PDF
Intenta múltiples métodos en orden de preferencia
"""

import sys
from pathlib import Path

def try_weasyprint(md_file, output_pdf):
    """Método 1: WeasyPrint (recomendado)"""
    try:
        import markdown
        from weasyprint import HTML, CSS

        print("🔄 Intentando conversión con WeasyPrint...")

        with open(md_file, 'r', encoding='utf-8') as f:
            md_content = f.read()

        html = markdown.markdown(
            md_content,
            extensions=['extra', 'codehilite', 'toc', 'fenced_code']
        )

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
        h2 { font-size: 18pt; margin-top: 20pt; color: #2a2a2a; }
        h3 { font-size: 14pt; margin-top: 15pt; color: #3a3a3a; }
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
        blockquote {
            font-style: italic;
            border-left: 3pt solid #ccc;
            padding-left: 15pt;
            color: #555;
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
        }
        td {
            padding: 6pt;
            border: 1pt solid #ddd;
        }
        """

        full_html = f'<!DOCTYPE html><html><head><meta charset="utf-8"></head><body>{html}</body></html>'
        HTML(string=full_html).write_pdf(output_pdf, stylesheets=[CSS(string=css)])

        print(f"✅ PDF creado exitosamente con WeasyPrint: {output_pdf}")
        return True
    except ImportError:
        print("❌ WeasyPrint no instalado. Instalar con: pip install markdown weasyprint")
        return False
    except Exception as e:
        print(f"❌ Error con WeasyPrint: {e}")
        return False

def try_pandoc(md_file, output_pdf):
    """Método 2: Pandoc"""
    try:
        import pypandoc

        print("🔄 Intentando conversión con Pandoc...")

        pypandoc.convert_file(
            md_file,
            'pdf',
            outputfile=output_pdf,
            extra_args=[
                '--pdf-engine=xelatex',
                '--variable', 'geometry:margin=2.5cm',
                '--variable', 'fontsize=11pt',
                '--highlight-style=tango'
            ]
        )

        print(f"✅ PDF creado exitosamente con Pandoc: {output_pdf}")
        return True
    except ImportError:
        print("❌ pypandoc no instalado. Instalar con: pip install pypandoc")
        return False
    except RuntimeError:
        print("❌ Pandoc no encontrado. Instalar desde: https://pandoc.org/installing.html")
        return False
    except Exception as e:
        print(f"❌ Error con Pandoc: {e}")
        return False

def try_simple(md_file, output_pdf):
    """Método 3: md2pdf (simple)"""
    try:
        from md2pdf.core import md2pdf

        print("🔄 Intentando conversión con md2pdf...")

        md2pdf(output_pdf, md_file_path=md_file)

        print(f"✅ PDF creado exitosamente con md2pdf: {output_pdf}")
        return True
    except ImportError:
        print("❌ md2pdf no instalado. Instalar con: pip install md2pdf")
        return False
    except Exception as e:
        print(f"❌ Error con md2pdf: {e}")
        return False

def convert_md_to_pdf(md_file):
    """Intenta convertir MD a PDF usando múltiples métodos"""

    if not Path(md_file).exists():
        print(f"❌ Error: Archivo no encontrado: {md_file}")
        return False

    output_pdf = Path(md_file).stem + '.pdf'

    print(f"📄 Convirtiendo: {md_file}")
    print(f"📄 Salida: {output_pdf}")
    print("=" * 70)

    # Intentar métodos en orden de preferencia
    methods = [
        ("WeasyPrint", try_weasyprint),
        ("Pandoc", try_pandoc),
        ("md2pdf", try_simple)
    ]

    for method_name, method_func in methods:
        if method_func(md_file, output_pdf):
            print("=" * 70)
            print(f"🎉 ÉXITO: PDF generado con {method_name}")
            print(f"📁 Ubicación: {Path(output_pdf).absolute()}")

            # Mostrar tamaño del archivo
            size_mb = Path(output_pdf).stat().st_size / 1024 / 1024
            print(f"📊 Tamaño: {size_mb:.2f} MB")
            return True
        print()

    print("=" * 70)
    print("❌ FALLO: No se pudo generar el PDF con ningún método")
    print()
    print("💡 SOLUCIONES:")
    print("1. Instalar WeasyPrint (recomendado):")
    print("   pip install markdown weasyprint")
    print()
    print("2. Instalar Pandoc:")
    print("   pip install pypandoc")
    print("   Luego instalar Pandoc: https://pandoc.org/installing.html")
    print()
    print("3. Instalar md2pdf (simple):")
    print("   pip install md2pdf")

    return False

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Uso: python md_to_pdf_auto.py archivo.md")
        sys.exit(1)

    success = convert_md_to_pdf(sys.argv[1])
    sys.exit(0 if success else 1)
