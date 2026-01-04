#!/usr/bin/env python3
"""
Convertir Markdown a PDF usando ReportLab + markdown
Instalación: pip install reportlab markdown
Máximo control sobre el diseño
"""

from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak, Preformatted
from reportlab.lib.enums import TA_JUSTIFY
import markdown
from bs4 import BeautifulSoup
from pathlib import Path
import sys

def markdown_to_pdf_reportlab(md_file, output_pdf=None):
    if output_pdf is None:
        output_pdf = Path(md_file).stem + '.pdf'

    # Leer markdown
    with open(md_file, 'r', encoding='utf-8') as f:
        md_content = f.read()

    # Convertir a HTML
    html = markdown.markdown(md_content, extensions=['extra', 'fenced_code'])
    soup = BeautifulSoup(html, 'html.parser')

    # Crear PDF
    doc = SimpleDocTemplate(
        output_pdf,
        pagesize=A4,
        leftMargin=2*cm,
        rightMargin=2*cm,
        topMargin=2.5*cm,
        bottomMargin=2.5*cm
    )

    # Estilos
    styles = getSampleStyleSheet()
    styles.add(ParagraphStyle(
        name='Justify',
        parent=styles['BodyText'],
        alignment=TA_JUSTIFY,
        fontSize=11,
        leading=14
    ))

    story = []

    # Procesar elementos HTML
    for element in soup.find_all(['h1', 'h2', 'h3', 'p', 'pre', 'code']):
        try:
            text = element.get_text(strip=True)
            if not text:
                continue
                
            if element.name == 'h1':
                story.append(PageBreak())
                story.append(Paragraph(text, styles['Heading1']))
                story.append(Spacer(1, 0.5*cm))
            elif element.name == 'h2':
                story.append(Paragraph(text, styles['Heading2']))
                story.append(Spacer(1, 0.3*cm))
            elif element.name == 'h3':
                story.append(Paragraph(text, styles['Heading3']))
                story.append(Spacer(1, 0.2*cm))
            elif element.name in ['pre', 'code']:
                story.append(Preformatted(text, styles['Code']))
                story.append(Spacer(1, 0.3*cm))
            elif element.name == 'p':
                story.append(Paragraph(text, styles['Justify']))
                story.append(Spacer(1, 0.2*cm))
        except Exception as e:
            # Continuar si hay error con un elemento específico
            print(f"⚠️  Advertencia: Error procesando elemento {element.name}: {e}")
            continue

    doc.build(story)
    print(f"✅ PDF creado: {output_pdf}")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Uso: python md_to_pdf_reportlab.py archivo.md")
        sys.exit(1)
    markdown_to_pdf_reportlab(sys.argv[1])
