#!/usr/bin/env python3
"""
Aplicación inteligente de conversión Markdown a PDF
Selecciona automáticamente el mejor método disponible según:
- Métodos instalados en el sistema
- Características del documento (código, ecuaciones LaTeX, tablas, etc.)
- Calidad y confiabilidad de cada método
"""

import sys
import os
from pathlib import Path
from typing import Optional, Tuple, List, Dict
import subprocess
import re

# Colores para output (opcional)
try:
    from colorama import init, Fore, Style
    init(autoreset=True)
    HAS_COLORAMA = True
except ImportError:
    HAS_COLORAMA = False
    # Fallback sin colores
    class Fore:
        GREEN = YELLOW = RED = BLUE = CYAN = RESET = ""
    class Style:
        BRIGHT = RESET_ALL = ""


class MarkdownToPDFConverter:
    """Conversor inteligente de Markdown a PDF"""
    
    def __init__(self, verbose: bool = True):
        self.verbose = verbose
        self.available_methods = []
        self.detected_features = {}
        
    def log(self, message: str, level: str = "info"):
        """Log con colores opcionales"""
        if not self.verbose:
            return
            
        colors = {
            "info": Fore.CYAN,
            "success": Fore.GREEN,
            "warning": Fore.YELLOW,
            "error": Fore.RED,
            "debug": Fore.BLUE
        }
        color = colors.get(level, "")
        print(f"{color}{message}{Style.RESET_ALL}")
    
    def check_method_available(self, method_name: str) -> bool:
        """Verifica si un método está disponible"""
        checks = {
            "weasyprint": self._check_weasyprint,
            "pandoc": self._check_pandoc,
            "md2pdf": self._check_md2pdf,
            "reportlab": self._check_reportlab
        }
        
        if method_name in checks:
            return checks[method_name]()
        return False
    
    def _check_weasyprint(self) -> bool:
        """Verifica si WeasyPrint está disponible"""
        try:
            import markdown
            from weasyprint import HTML, CSS
            return True
        except ImportError:
            return False
    
    def _check_pandoc(self) -> bool:
        """Verifica si Pandoc está disponible"""
        try:
            import pypandoc
            # Verificar que pandoc esté instalado en el sistema
            result = subprocess.run(
                ['pandoc', '--version'],
                capture_output=True,
                text=True,
                timeout=5
            )
            return result.returncode == 0
        except (ImportError, FileNotFoundError, subprocess.TimeoutExpired):
            return False
    
    def _check_md2pdf(self) -> bool:
        """Verifica si md2pdf está disponible"""
        try:
            from md2pdf.core import md2pdf
            return True
        except ImportError:
            return False
    
    def _check_reportlab(self) -> bool:
        """Verifica si ReportLab está disponible"""
        try:
            from reportlab.lib.pagesizes import A4
            import markdown
            from bs4 import BeautifulSoup
            return True
        except ImportError:
            return False
    
    def detect_document_features(self, md_file: Path) -> Dict[str, bool]:
        """Analiza el documento para detectar características especiales"""
        features = {
            "has_code": False,
            "has_latex": False,
            "has_tables": False,
            "has_images": False,
            "has_math": False,
            "is_long": False
        }
        
        try:
            with open(md_file, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Detectar código
            features["has_code"] = bool(re.search(r'```[\s\S]*?```', content) or 
                                       re.search(r'`[^`]+`', content))
            
            # Detectar LaTeX/ecuaciones
            features["has_latex"] = bool(re.search(r'\$[^$]+\$', content) or
                                         re.search(r'\\\(.*?\\\)', content) or
                                         re.search(r'\\\[.*?\\\]', content))
            
            # Detectar tablas
            features["has_tables"] = bool(re.search(r'\|.*\|', content))
            
            # Detectar imágenes
            features["has_images"] = bool(re.search(r'!\[.*?\]\(.*?\)', content))
            
            # Detectar matemáticas avanzadas
            features["has_math"] = features["has_latex"] or bool(
                re.search(r'\\begin\{.*?\}', content) or
                re.search(r'\\frac\{', content) or
                re.search(r'\\sum|\\int|\\prod', content)
            )
            
            # Detectar documentos largos (>5000 palabras)
            word_count = len(content.split())
            features["is_long"] = word_count > 5000
            
        except Exception as e:
            self.log(f"⚠️  Error al analizar documento: {e}", "warning")
        
        return features
    
    def score_method_for_document(self, method: str, features: Dict[str, bool]) -> int:
        """Evalúa qué tan adecuado es un método para el documento"""
        scores = {
            "weasyprint": {
                "has_code": 10,
                "has_tables": 8,
                "has_images": 9,
                "has_latex": 5,
                "has_math": 3,
                "is_long": 8,
                "base": 7
            },
            "pandoc": {
                "has_code": 8,
                "has_tables": 9,
                "has_images": 8,
                "has_latex": 10,
                "has_math": 10,
                "is_long": 9,
                "base": 8
            },
            "md2pdf": {
                "has_code": 5,
                "has_tables": 6,
                "has_images": 6,
                "has_latex": 2,
                "has_math": 1,
                "is_long": 6,
                "base": 5
            },
            "reportlab": {
                "has_code": 7,
                "has_tables": 7,
                "has_images": 7,
                "has_latex": 4,
                "has_math": 3,
                "is_long": 7,
                "base": 6
            }
        }
        
        if method not in scores:
            return 0
        
        method_scores = scores[method]
        total_score = method_scores.get("base", 0)
        
        for feature, has_feature in features.items():
            if has_feature and feature in method_scores:
                total_score += method_scores[feature]
        
        return total_score
    
    def detect_available_methods(self) -> List[str]:
        """Detecta qué métodos están disponibles"""
        methods = ["weasyprint", "pandoc", "md2pdf", "reportlab"]
        available = []
        
        self.log("🔍 Detectando métodos disponibles...", "info")
        
        for method in methods:
            if self.check_method_available(method):
                available.append(method)
                self.log(f"  ✅ {method.capitalize()} disponible", "success")
            else:
                self.log(f"  ❌ {method.capitalize()} no disponible", "debug")
        
        return available
    
    def convert_with_weasyprint(self, md_file: Path, output_pdf: Path) -> Tuple[bool, str]:
        """Convierte usando WeasyPrint"""
        try:
            import markdown
            from weasyprint import HTML, CSS
            
            self.log("🔄 Convirtiendo con WeasyPrint...", "info")
            
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
            
            full_html = f'<!DOCTYPE html><html><head><meta charset="utf-8"></head><body>{html}</body></html>'
            HTML(string=full_html).write_pdf(str(output_pdf), stylesheets=[CSS(string=css)])
            
            return True, "WeasyPrint"
            
        except ImportError as e:
            return False, f"WeasyPrint no instalado: {e}"
        except Exception as e:
            return False, f"Error con WeasyPrint: {e}"
    
    def convert_with_pandoc(self, md_file: Path, output_pdf: Path) -> Tuple[bool, str]:
        """Convierte usando Pandoc"""
        try:
            import pypandoc
            
            self.log("🔄 Convirtiendo con Pandoc...", "info")
            
            extra_args = [
                '--pdf-engine=xelatex',
                '--variable', 'geometry:margin=2.5cm',
                '--variable', 'fontsize=11pt',
                '--variable', 'documentclass=article',
                '--variable', 'papersize=a4',
                '--highlight-style=tango',
                '--toc',
                '--number-sections',
                '-V', 'colorlinks=true',
                '-V', 'linkcolor=blue',
                '-V', 'urlcolor=blue'
            ]
            
            # Si hay ecuaciones LaTeX, usar mejor motor
            if self.detected_features.get("has_math"):
                extra_args.append('--mathml')
            
            pypandoc.convert_file(
                str(md_file),
                'pdf',
                outputfile=str(output_pdf),
                extra_args=extra_args
            )
            
            return True, "Pandoc"
            
        except ImportError:
            return False, "pypandoc no instalado"
        except RuntimeError as e:
            if "pandoc" in str(e).lower():
                return False, "Pandoc no encontrado en el sistema"
            return False, f"Error con Pandoc: {e}"
        except Exception as e:
            return False, f"Error con Pandoc: {e}"
    
    def convert_with_md2pdf(self, md_file: Path, output_pdf: Path) -> Tuple[bool, str]:
        """Convierte usando md2pdf"""
        try:
            from md2pdf.core import md2pdf
            
            self.log("🔄 Convirtiendo con md2pdf...", "info")
            
            md2pdf(str(output_pdf), md_file_path=str(md_file))
            
            return True, "md2pdf"
            
        except ImportError:
            return False, "md2pdf no instalado"
        except Exception as e:
            return False, f"Error con md2pdf: {e}"
    
    def convert_with_reportlab(self, md_file: Path, output_pdf: Path) -> Tuple[bool, str]:
        """Convierte usando ReportLab"""
        try:
            from reportlab.lib.pagesizes import A4
            from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
            from reportlab.lib.units import cm
            from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak, Preformatted
            from reportlab.lib.enums import TA_JUSTIFY
            import markdown
            from bs4 import BeautifulSoup
            
            self.log("🔄 Convirtiendo con ReportLab...", "info")
            
            with open(md_file, 'r', encoding='utf-8') as f:
                md_content = f.read()
            
            html = markdown.markdown(md_content, extensions=['extra', 'fenced_code'])
            soup = BeautifulSoup(html, 'html.parser')
            
            doc = SimpleDocTemplate(
                str(output_pdf),
                pagesize=A4,
                leftMargin=2*cm,
                rightMargin=2*cm,
                topMargin=2.5*cm,
                bottomMargin=2.5*cm
            )
            
            styles = getSampleStyleSheet()
            styles.add(ParagraphStyle(
                name='Justify',
                parent=styles['BodyText'],
                alignment=TA_JUSTIFY,
                fontSize=11,
                leading=14
            ))
            
            story = []
            
            for element in soup.find_all(['h1', 'h2', 'h3', 'p', 'pre', 'code', 'blockquote', 'ul', 'ol', 'li']):
                if element.name == 'h1':
                    story.append(PageBreak())
                    story.append(Paragraph(element.get_text(), styles['Heading1']))
                    story.append(Spacer(1, 0.5*cm))
                elif element.name == 'h2':
                    story.append(Paragraph(element.get_text(), styles['Heading2']))
                    story.append(Spacer(1, 0.3*cm))
                elif element.name == 'h3':
                    story.append(Paragraph(element.get_text(), styles['Heading3']))
                    story.append(Spacer(1, 0.2*cm))
                elif element.name in ['pre', 'code']:
                    story.append(Preformatted(element.get_text(), styles['Code']))
                    story.append(Spacer(1, 0.3*cm))
                elif element.name == 'p':
                    story.append(Paragraph(element.get_text(), styles['Justify']))
                    story.append(Spacer(1, 0.2*cm))
            
            doc.build(story)
            
            return True, "ReportLab"
            
        except ImportError as e:
            return False, f"ReportLab o dependencias no instaladas: {e}"
        except Exception as e:
            return False, f"Error con ReportLab: {e}"
    
    def convert(self, md_file: str, output_pdf: Optional[str] = None, 
                preferred_method: Optional[str] = None) -> bool:
        """Convierte Markdown a PDF usando el mejor método disponible"""
        
        md_path = Path(md_file)
        
        # Validar archivo de entrada
        if not md_path.exists():
            self.log(f"❌ Error: Archivo no encontrado: {md_file}", "error")
            return False
        
        if not md_path.suffix.lower() in ['.md', '.markdown']:
            self.log(f"⚠️  Advertencia: El archivo no tiene extensión .md o .markdown", "warning")
        
        # Determinar archivo de salida
        if output_pdf is None:
            output_pdf = md_path.with_suffix('.pdf')
        else:
            output_pdf = Path(output_pdf)
        
        self.log("=" * 70, "info")
        self.log(f"📄 Archivo de entrada: {md_path.absolute()}", "info")
        self.log(f"📄 Archivo de salida: {output_pdf.absolute()}", "info")
        self.log("=" * 70, "info")
        
        # Detectar características del documento
        self.log("🔍 Analizando documento...", "info")
        self.detected_features = self.detect_document_features(md_path)
        
        detected = [k for k, v in self.detected_features.items() if v]
        if detected:
            self.log(f"  Características detectadas: {', '.join(detected)}", "info")
        else:
            self.log("  Documento simple sin características especiales", "info")
        
        # Detectar métodos disponibles
        available_methods = self.detect_available_methods()
        
        if not available_methods:
            self.log("=" * 70, "error")
            self.log("❌ ERROR: No se encontró ningún método de conversión disponible", "error")
            self.log("", "error")
            self.log("💡 SOLUCIONES:", "error")
            self.log("", "error")
            self.log("1. Instalar WeasyPrint (recomendado):", "error")
            self.log("   pip install markdown weasyprint", "error")
            self.log("", "error")
            self.log("2. Instalar Pandoc:", "error")
            self.log("   pip install pypandoc", "error")
            self.log("   Luego instalar Pandoc: https://pandoc.org/installing.html", "error")
            self.log("", "error")
            self.log("3. Instalar md2pdf (simple):", "error")
            self.log("   pip install md2pdf", "error")
            return False
        
        # Seleccionar mejor método
        if preferred_method and preferred_method in available_methods:
            selected_method = preferred_method
            self.log(f"📌 Usando método preferido: {selected_method}", "info")
        else:
            # Calcular scores para cada método disponible
            method_scores = {}
            for method in available_methods:
                score = self.score_method_for_document(method, self.detected_features)
                method_scores[method] = score
                self.log(f"  {method.capitalize()}: score {score}", "debug")
            
            # Ordenar por score
            sorted_methods = sorted(method_scores.items(), key=lambda x: x[1], reverse=True)
            selected_method = sorted_methods[0][0]
            
            self.log(f"🎯 Método seleccionado: {selected_method.capitalize()} (score: {sorted_methods[0][1]})", "success")
        
        # Convertir usando el método seleccionado
        converters = {
            "weasyprint": self.convert_with_weasyprint,
            "pandoc": self.convert_with_pandoc,
            "md2pdf": self.convert_with_md2pdf,
            "reportlab": self.convert_with_reportlab
        }
        
        success, message = converters[selected_method](md_path, output_pdf)
        
        if success:
            self.log("=" * 70, "success")
            self.log(f"✅ ÉXITO: PDF generado con {message}", "success")
            self.log(f"📁 Ubicación: {output_pdf.absolute()}", "success")
            
            # Mostrar tamaño del archivo
            try:
                size_bytes = output_pdf.stat().st_size
                size_mb = size_bytes / 1024 / 1024
                if size_mb < 1:
                    size_kb = size_bytes / 1024
                    self.log(f"📊 Tamaño: {size_kb:.2f} KB", "success")
                else:
                    self.log(f"📊 Tamaño: {size_mb:.2f} MB", "success")
            except Exception:
                pass
            
            return True
        else:
            self.log("=" * 70, "error")
            self.log(f"❌ Error con {selected_method}: {message}", "error")
            
            # Intentar métodos alternativos
            remaining_methods = [m for m in available_methods if m != selected_method]
            if remaining_methods:
                self.log("", "warning")
                self.log("🔄 Intentando métodos alternativos...", "warning")
                
                for alt_method in remaining_methods:
                    self.log(f"  Intentando {alt_method}...", "info")
                    success, message = converters[alt_method](md_path, output_pdf)
                    if success:
                        self.log("=" * 70, "success")
                        self.log(f"✅ ÉXITO: PDF generado con {message}", "success")
                        self.log(f"📁 Ubicación: {output_pdf.absolute()}", "success")
                        return True
                    else:
                        self.log(f"  ❌ {alt_method} falló: {message}", "error")
            
            self.log("=" * 70, "error")
            self.log("❌ FALLO: No se pudo generar el PDF con ningún método", "error")
            return False


def get_input_file_interactive() -> Optional[str]:
    """Modo interactivo para obtener el archivo de entrada"""
    import platform
    
    is_macos = platform.system() == 'Darwin'
    
    print("=" * 70)
    print("📄 MODO INTERACTIVO - Conversión Markdown a PDF")
    print("=" * 70)
    print()
    
    if is_macos:
        print("💡 SUGERENCIA:")
        print("   1. Abre Finder y navega hasta tu archivo Markdown")
        print("   2. Haz clic derecho (o Control+clic) en el archivo")
        print("   3. Mantén presionada la tecla Option (⌥)")
        print("   4. Selecciona 'Copiar [nombre] como nombre de ruta'")
        print("   5. Pega la ruta aquí (Cmd+V)")
        print()
    else:
        print("💡 INSTRUCCIONES:")
        print("   Copia la ruta completa del archivo Markdown")
        print("   y pégala aquí")
        print()
    
    print("📋 Pega la ruta del archivo Markdown (o presiona Enter para cancelar):")
    print("   ", end="", flush=True)
    
    try:
        user_input = input().strip()
        
        if not user_input:
            print("❌ Operación cancelada")
            return None
        
        # Limpiar la ruta (puede venir con comillas o espacios)
        user_input = user_input.strip('"').strip("'").strip()
        
        # Expandir ~ y variables de entorno
        user_input = os.path.expanduser(user_input)
        user_input = os.path.expandvars(user_input)
        
        # Convertir a Path para mejor manejo
        file_path = Path(user_input)
        
        # Verificar que el archivo existe
        if not file_path.exists():
            print(f"❌ Error: El archivo no existe: {user_input}")
            print(f"   Ruta absoluta intentada: {file_path.absolute()}")
            return None
        
        # Verificar que es un archivo (no un directorio)
        if not file_path.is_file():
            print(f"❌ Error: La ruta no es un archivo: {user_input}")
            return None
        
        # Normalizar la ruta
        user_input = str(file_path.resolve())
        
        # Verificar que es un archivo markdown
        if not user_input.lower().endswith(('.md', '.markdown')):
            print(f"⚠️  Advertencia: El archivo no tiene extensión .md o .markdown")
            respuesta = input("   ¿Continuar de todas formas? (s/n): ").strip().lower()
            if respuesta not in ['s', 'si', 'sí', 'y', 'yes']:
                return None
        
        return user_input
        
    except KeyboardInterrupt:
        print("\n❌ Operación cancelada por el usuario")
        return None
    except Exception as e:
        print(f"❌ Error: {e}")
        return None


def get_output_directory_interactive(input_file: str) -> Optional[str]:
    """Pregunta al usuario dónde guardar el PDF"""
    print()
    print("=" * 70)
    print("📁 DESTINO DEL ARCHIVO PDF")
    print("=" * 70)
    print()
    print("¿Dónde deseas guardar el PDF convertido?")
    print()
    print("   1. En la misma carpeta que el archivo Markdown (recomendado)")
    print("   2. En un directorio específico")
    print()
    
    try:
        respuesta = input("   Selecciona una opción (1 o 2, Enter para opción 1): ").strip()
        
        if not respuesta or respuesta == '1':
            # Usar la misma carpeta que el archivo de origen
            return None
        elif respuesta == '2':
            # Pedir directorio específico
            print()
            print("📂 Ingresa la ruta del directorio donde deseas guardar el PDF:")
            print("   ", end="", flush=True)
            
            directorio = input().strip().strip('"').strip("'")
            
            if not directorio:
                print("⚠️  No se ingresó directorio, usando carpeta de origen")
                return None
            
            # Expandir ~ y variables de entorno
            directorio = os.path.expanduser(directorio)
            directorio = os.path.expandvars(directorio)
            
            dir_path = Path(directorio)
            
            # Verificar que el directorio existe
            if not dir_path.exists():
                print(f"❌ Error: El directorio no existe: {directorio}")
                respuesta2 = input("   ¿Deseas crearlo? (s/n): ").strip().lower()
                if respuesta2 in ['s', 'si', 'sí', 'y', 'yes']:
                    try:
                        dir_path.mkdir(parents=True, exist_ok=True)
                        print(f"✅ Directorio creado: {dir_path.absolute()}")
                    except Exception as e:
                        print(f"❌ Error creando directorio: {e}")
                        return None
                else:
                    print("⚠️  Usando carpeta de origen")
                    return None
            
            if not dir_path.is_dir():
                print(f"❌ Error: La ruta no es un directorio: {directorio}")
                print("⚠️  Usando carpeta de origen")
                return None
            
            # Retornar la ruta completa del PDF
            input_path = Path(input_file)
            pdf_name = input_path.stem + '.pdf'
            return str(dir_path / pdf_name)
        else:
            print("⚠️  Opción no válida, usando carpeta de origen")
            return None
            
    except KeyboardInterrupt:
        print("\n⚠️  Usando carpeta de origen")
        return None
    except Exception as e:
        print(f"⚠️  Error: {e}, usando carpeta de origen")
        return None


def main():
    """Función principal"""
    import argparse
    import platform
    
    parser = argparse.ArgumentParser(
        description='Conversor inteligente de Markdown a PDF',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Ejemplos:
  %(prog)s documento.md
  %(prog)s documento.md -o salida.pdf
  %(prog)s documento.md --method weasyprint
  %(prog)s documento.md --quiet
  %(prog)s                    (modo interactivo)
        """
    )
    
    parser.add_argument('input_file', nargs='?', help='Archivo Markdown a convertir (opcional, modo interactivo si no se especifica)')
    parser.add_argument('-o', '--output', help='Archivo PDF de salida (opcional)')
    parser.add_argument('-m', '--method', 
                       choices=['weasyprint', 'pandoc', 'md2pdf', 'reportlab'],
                       help='Método preferido de conversión')
    parser.add_argument('-q', '--quiet', action='store_true',
                       help='Modo silencioso (menos output)')
    parser.add_argument('-v', '--verbose', action='store_true',
                       help='Modo verbose (más detalles)')
    parser.add_argument('-i', '--interactive', action='store_true',
                       help='Forzar modo interactivo')
    
    args = parser.parse_args()
    
    # Determinar si usar modo interactivo
    use_interactive = args.interactive or (args.input_file is None)
    
    input_file = args.input_file
    output_file = args.output
    
    # Modo interactivo
    if use_interactive:
        input_file = get_input_file_interactive()
        if input_file is None:
            sys.exit(1)
        
        # Si no se especificó output en línea de comandos, preguntar
        if output_file is None:
            output_file = get_output_directory_interactive(input_file)
    
    converter = MarkdownToPDFConverter(verbose=not args.quiet)
    
    success = converter.convert(
        input_file,
        output_file,
        args.method
    )
    
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()

