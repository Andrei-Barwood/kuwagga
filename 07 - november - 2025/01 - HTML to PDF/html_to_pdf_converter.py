#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script para convertir HTML a PDF preservando estilos, fondos y colores
Con manejo inteligente de saltos de página para tablas
Diseñado para memorias de cálculo y documentos técnicos

Autor: Tutorial Python
Fecha: 2025
"""

import os
import sys
from pathlib import Path
from typing import Tuple, Optional
import logging
from datetime import datetime

# Importaciones necesarias
try:
    from weasyprint import HTML, CSS
    import math
except ImportError as e:
    print(f"❌ Error: Librería no instalada - {e}")
    print("Instala con: pip install weasyprint")
    sys.exit(1)


# ============================================================================
# CONFIGURACIÓN DE LOGGING
# ============================================================================

def setup_logging(log_file: str = "conversion.log") -> logging.Logger:
    """Configura logging para el script"""
    logger = logging.getLogger("HTMLtoPDFConverter")
    logger.setLevel(logging.DEBUG)
    
    # Handler para archivo
    file_handler = logging.FileHandler(log_file, encoding='utf-8')
    file_handler.setLevel(logging.DEBUG)
    
    # Handler para consola
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(logging.INFO)
    
    # Formato
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    file_handler.setFormatter(formatter)
    console_handler.setFormatter(formatter)
    
    logger.addHandler(file_handler)
    logger.addHandler(console_handler)
    
    return logger

logger = setup_logging()


# ============================================================================
# CONSTANTES DE CONFIGURACIÓN PDF
# ============================================================================

# Dimensiones de página (mm)
PAGE_WIDTH_MM = 210  # A4
PAGE_HEIGHT_MM = 297  # A4
MARGIN_TOP_MM = 15
MARGIN_BOTTOM_MM = 15
MARGIN_LEFT_MM = 15
MARGIN_RIGHT_MM = 15

# Área disponible para contenido
CONTENT_WIDTH_MM = PAGE_WIDTH_MM - MARGIN_LEFT_MM - MARGIN_RIGHT_MM
CONTENT_HEIGHT_MM = PAGE_HEIGHT_MM - MARGIN_TOP_MM - MARGIN_BOTTOM_MM

# Conversión: 1 pulgada = 25.4 mm, 1 pulgada = 96 px
# 1 mm = 96/25.4 ≈ 3.78 px
MM_TO_PX = 96 / 25.4
PX_TO_MM = 25.4 / 96

logger.info(f"Configuración PDF - A4: {PAGE_WIDTH_MM}x{PAGE_HEIGHT_MM}mm")
logger.info(f"Área de contenido: {CONTENT_WIDTH_MM}x{CONTENT_HEIGHT_MM}mm")


# ============================================================================
# INYECCIÓN DE CSS PARA MANEJO DE SALTOS DE PÁGINA
# ============================================================================

PAGE_BREAK_CSS = """
/* Estilos para control de saltos de página */
html, body {
    margin: 0;
    padding: 0;
}

@page {
    size: A4;
    margin: 15mm 15mm 15mm 15mm;
}

/* Prevenir saltos de página dentro de tablas */
table {
    page-break-inside: avoid;
    break-inside: avoid;
}

/* Prevenir saltos de página dentro de filas */
tr {
    page-break-inside: avoid;
    break-inside: avoid;
}

/* Mantener encabezados de tablas en primera página */
thead {
    display: table-header-group;
}

tfoot {
    display: table-footer-group;
}

/* Salto de página antes de secciones principales */
h1, h2 {
    page-break-after: avoid;
    break-after: avoid;
}

/* Evitar líneas viudas/huérfanas */
p {
    orphans: 3;
    widows: 3;
}

/* Código y bloques preformateados */
pre, code {
    page-break-inside: avoid;
    break-inside: avoid;
}

/* Evitar saltos antes de listas */
ul, ol {
    page-break-before: avoid;
    break-before: avoid;
}

/* Espaciado adaptado para impresión */
@media print {
    body {
        background: white !important;
    }
    
    .main-container {
        box-shadow: none !important;
        margin: 0 !important;
        padding: 0 !important;
    }
}
"""


# ============================================================================
# ANÁLISIS DE CONTENIDO Y CÁLCULOS DE DIMENSIONAMIENTO
# ============================================================================

class ContentAnalyzer:
    """Analiza HTML para optimizar saltos de página"""
    
    def __init__(self, html_path: str):
        self.html_path = html_path
        self.html_content = self._load_html()
        logger.info(f"HTML cargado: {html_path}")
    
    def _load_html(self) -> str:
        """Carga el contenido HTML"""
        try:
            with open(self.html_path, 'r', encoding='utf-8') as f:
                return f.read()
        except FileNotFoundError:
            logger.error(f"Archivo no encontrado: {self.html_path}")
            raise
        except Exception as e:
            logger.error(f"Error al leer HTML: {e}")
            raise
    
    def analyze_tables(self) -> dict:
        """Analiza tablas en el HTML"""
        import re
        
        tables = re.findall(r'<table[^>]*>(.*?)</table>', self.html_content, re.DOTALL)
        analysis = {
            'total_tables': len(tables),
            'tables': []
        }
        
        for idx, table in enumerate(tables, 1):
            rows = len(re.findall(r'<tr', table))
            cells = len(re.findall(r'<td|<th', table))
            
            analysis['tables'].append({
                'id': idx,
                'rows': rows,
                'cells': cells,
                'avg_cells_per_row': cells // max(rows, 1)
            })
            
            logger.info(f"Tabla {idx}: {rows} filas, {cells} celdas")
        
        return analysis
    
    def get_statistics(self) -> dict:
        """Obtiene estadísticas generales del documento"""
        import re
        
        headings = len(re.findall(r'<h[1-6]', self.html_content))
        paragraphs = len(re.findall(r'<p[^>]*>', self.html_content))
        images = len(re.findall(r'<img', self.html_content))
        
        return {
            'headings': headings,
            'paragraphs': paragraphs,
            'images': images,
            'tables': len(re.findall(r'<table', self.html_content))
        }


# ============================================================================
# INYECCIÓN DE CSS EN HTML
# ============================================================================

def inject_page_break_css(html_content: str) -> str:
    """Inyecta CSS de control de saltos de página"""
    # Buscar si ya existe un <style>
    import re
    
    if '<style' in html_content:
        # Inyectar dentro del primer <style> existente
        pattern = r'(<style[^>]*>)'
        replacement = rf'\1\n{PAGE_BREAK_CSS}'
        html_content = re.sub(pattern, replacement, html_content, count=1)
    else:
        # Crear nuevo <style> en el <head>
        if '<head>' in html_content:
            head_close = html_content.find('</head>')
            if head_close != -1:
                html_content = (
                    html_content[:head_close] +
                    f'\n<style>\n{PAGE_BREAK_CSS}\n</style>\n' +
                    html_content[head_close:]
                )
    
    logger.info("CSS de control de saltos de página inyectado")
    return html_content


# ============================================================================
# CONVERSIÓN HTML A PDF
# ============================================================================

class HTMLtoPDFConverter:
    """Convierte HTML a PDF con control de saltos de página"""
    
    def __init__(self, html_path: str, output_path: Optional[str] = None):
        self.html_path = html_path
        self.output_path = output_path or self._generate_output_path()
        self.analyzer = ContentAnalyzer(html_path)
        
        logger.info(f"Entrada: {self.html_path}")
        logger.info(f"Salida: {self.output_path}")
    
    def _generate_output_path(self) -> str:
        """Genera ruta de salida basada en entrada"""
        input_path = Path(self.html_path)
        output_dir = input_path.parent
        output_name = input_path.stem + "_converted.pdf"
        return str(output_dir / output_name)
    
    def _validate_html(self) -> bool:
        """Valida que el HTML sea accesible"""
        if not os.path.exists(self.html_path):
            logger.error(f"Archivo no encontrado: {self.html_path}")
            return False
        
        if not self.html_path.endswith(('.html', '.htm')):
            logger.warning(f"Extensión inesperada: {self.html_path}")
        
        return True
    
    def calculate_table_heights(self) -> dict:
        """Calcula alturas aproximadas de tablas para planificación de saltos"""
        analysis = self.analyzer.analyze_tables()
        
        # Estimaciones (pueden ajustarse según estilos CSS reales)
        ROW_HEIGHT_MM = 8  # altura estimada por fila
        HEADER_HEIGHT_MM = 10  # altura estimada del encabezado
        
        results = {}
        for table in analysis['tables']:
            total_height = (
                HEADER_HEIGHT_MM +
                (table['rows'] - 1) * ROW_HEIGHT_MM
            )
            
            # Comparar con altura disponible
            pages_needed = math.ceil(total_height / CONTENT_HEIGHT_MM)
            fits_in_page = total_height <= CONTENT_HEIGHT_MM
            
            results[table['id']] = {
                'rows': table['rows'],
                'estimated_height_mm': total_height,
                'pages_needed': pages_needed,
                'fits_in_page': fits_in_page,
                'warning': not fits_in_page
            }
            
            if fits_in_page:
                logger.info(
                    f"Tabla {table['id']}: {total_height:.1f}mm "
                    f"(cabe en página)"
                )
            else:
                logger.warning(
                    f"Tabla {table['id']}: {total_height:.1f}mm "
                    f"(requiere {pages_needed} páginas)"
                )
        
        return results
    
    def convert(self, enable_css_injection: bool = True) -> Tuple[bool, str]:
        """
        Realiza la conversión de HTML a PDF
        
        Args:
            enable_css_injection: Si True, inyecta CSS de control de saltos
        
        Returns:
            Tupla (éxito: bool, mensaje: str)
        """
        try:
            # Validar entrada
            if not self._validate_html():
                return False, "Archivo HTML inválido"
            
            logger.info("=" * 70)
            logger.info("INICIANDO CONVERSIÓN HTML → PDF")
            logger.info("=" * 70)
            
            # Analizar contenido
            stats = self.analyzer.get_statistics()
            logger.info(f"Estadísticas del documento:")
            logger.info(f"  - Encabezados: {stats['headings']}")
            logger.info(f"  - Párrafos: {stats['paragraphs']}")
            logger.info(f"  - Tablas: {stats['tables']}")
            logger.info(f"  - Imágenes: {stats['images']}")
            
            # Calcular dimensionamiento de tablas
            logger.info("\nAnálisis de tablas:")
            table_analysis = self.calculate_table_heights()
            
            # Cargar HTML
            html_content = self.analyzer.html_content
            
            # Inyectar CSS si está habilitado
            if enable_css_injection:
                html_content = inject_page_break_css(html_content)
            
            # Guardar HTML modificado temporalmente (para debugging)
            temp_html = self.html_path.replace('.html', '_temp.html')
            with open(temp_html, 'w', encoding='utf-8') as f:
                f.write(html_content)
            logger.info(f"HTML temporal guardado: {temp_html}")
            
            # Convertir con WeasyPrint
            logger.info("\nConvirtiendo a PDF con WeasyPrint...")
            logger.info(f"Formato: A4 ({PAGE_WIDTH_MM}x{PAGE_HEIGHT_MM}mm)")
            logger.info(f"Márgenes: {MARGIN_TOP_MM}mm (superior), "
                       f"{MARGIN_BOTTOM_MM}mm (inferior), "
                       f"{MARGIN_LEFT_MM}mm (lateral)")
            
            HTML(string=html_content).write_pdf(
                self.output_path,
                zoom=1.0,
                presentational_hints=True
            )
            
            logger.info(f"✓ PDF generado exitosamente")
            
            # Verificar archivo de salida
            if os.path.exists(self.output_path):
                file_size_kb = os.path.getsize(self.output_path) / 1024
                logger.info(f"Tamaño del archivo: {file_size_kb:.1f} KB")
                logger.info("=" * 70)
                
                return True, f"Conversión exitosa: {self.output_path}"
            else:
                return False, "PDF no fue creado"
        
        except ImportError as e:
            logger.error(f"Error de importación: {e}")
            return False, f"Librería requerida no disponible: {e}"
        except Exception as e:
            logger.error(f"Error durante conversión: {e}", exc_info=True)
            return False, f"Error: {e}"


# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

def main():
    """Función principal"""
    import argparse
    
    parser = argparse.ArgumentParser(
        description='Convierte HTML a PDF preservando estilos y colores',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Ejemplos de uso:
  python html_to_pdf_converter.py index_2.html
  python html_to_pdf_converter.py index_2.html -o memoria_2025.pdf
  python html_to_pdf_converter.py index_2.html --no-css-injection
        """
    )
    
    parser.add_argument(
        'html_file',
        help='Ruta del archivo HTML a convertir'
    )
    
    parser.add_argument(
        '-o', '--output',
        help='Ruta del archivo PDF de salida (opcional)',
        default=None
    )
    
    parser.add_argument(
        '--no-css-injection',
        action='store_true',
        help='Desactiva inyección de CSS de control de saltos'
    )
    
    parser.add_argument(
        '--log-file',
        default='conversion.log',
        help='Archivo de log (default: conversion.log)'
    )
    
    args = parser.parse_args()
    
    # Crear convertidor
    converter = HTMLtoPDFConverter(args.html_file, args.output)
    
    # Realizar conversión
    success, message = converter.convert(
        enable_css_injection=not args.no_css_injection
    )
    
    # Mostrar resultado
    if success:
        print(f"\n✓ {message}")
        return 0
    else:
        print(f"\n❌ {message}")
        return 1


if __name__ == '__main__':
    sys.exit(main())
