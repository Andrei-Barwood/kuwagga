#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Traductor de PDFs - Versión Línea de Comandos
=============================================

Versión CLI del traductor de PDFs, sin dependencia de tkinter.
Útil cuando tkinter tiene problemas de compatibilidad con macOS.

Uso:
    python3 translate_pdf_cli.py documento.pdf -d es
    python3 translate_pdf_cli.py documento.pdf -o en -d es -p 1,3,5-10

Autor: Generado automáticamente
Fecha: Diciembre 2025
"""

import os
import sys
import argparse
import logging
import time
import hashlib
from typing import Optional, List, Dict

# ============================================================================
# CONFIGURACIÓN DE LOGGING
# ============================================================================
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%H:%M:%S'
)
logger = logging.getLogger(__name__)

# ============================================================================
# PROCESAMIENTO DE PDFs
# ============================================================================
try:
    import pdfplumber
except ImportError:
    pdfplumber = None
    logger.error("pdfplumber no instalado. Ejecuta: pip install pdfplumber")

try:
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib.units import cm
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
    from reportlab.lib.enums import TA_JUSTIFY
except ImportError:
    SimpleDocTemplate = None
    logger.error("reportlab no instalado. Ejecuta: pip install reportlab")

# ============================================================================
# TRADUCCIÓN
# ============================================================================
try:
    from deep_translator import GoogleTranslator, MyMemoryTranslator
except ImportError:
    GoogleTranslator = None
    logger.error("deep-translator no instalado. Ejecuta: pip install deep-translator")


# ============================================================================
# IDIOMAS SOPORTADOS
# ============================================================================
IDIOMAS = {
    "es": "Español",
    "en": "Inglés", 
    "fr": "Francés",
    "de": "Alemán",
    "it": "Italiano",
    "pt": "Portugués",
    "ru": "Ruso",
    "zh-CN": "Chino (Simplificado)",
    "zh-TW": "Chino (Tradicional)",
    "ja": "Japonés",
    "ko": "Coreano",
    "ar": "Árabe",
    "hi": "Hindi",
    "nl": "Holandés",
    "pl": "Polaco",
    "tr": "Turco",
    "sv": "Sueco",
    "da": "Danés",
    "no": "Noruego",
    "fi": "Finlandés",
    "el": "Griego",
    "he": "Hebreo",
    "th": "Tailandés",
    "vi": "Vietnamita",
    "id": "Indonesio",
    "ms": "Malayo",
    "ca": "Catalán",
    "uk": "Ucraniano",
    "cs": "Checo",
    "ro": "Rumano",
    "hu": "Húngaro",
    "auto": "Auto-detectar",
}


# ============================================================================
# CLASE: Caché de Traducciones
# ============================================================================
class CacheTraduccion:
    """Caché en memoria para evitar traducir el mismo texto múltiples veces."""
    
    def __init__(self):
        self._cache: Dict[str, str] = {}
        self._hits = 0
        self._misses = 0
    
    def _generar_clave(self, texto: str, idioma_origen: str, idioma_destino: str) -> str:
        contenido = f"{idioma_origen}:{idioma_destino}:{texto}"
        return hashlib.md5(contenido.encode('utf-8')).hexdigest()
    
    def obtener(self, texto: str, idioma_origen: str, idioma_destino: str) -> Optional[str]:
        clave = self._generar_clave(texto, idioma_origen, idioma_destino)
        if clave in self._cache:
            self._hits += 1
            return self._cache[clave]
        self._misses += 1
        return None
    
    def guardar(self, texto: str, traduccion: str, idioma_origen: str, idioma_destino: str):
        clave = self._generar_clave(texto, idioma_origen, idioma_destino)
        self._cache[clave] = traduccion
    
    def estadisticas(self) -> Dict[str, int]:
        return {"hits": self._hits, "misses": self._misses, "entradas": len(self._cache)}


# ============================================================================
# FUNCIONES DE EXTRACCIÓN
# ============================================================================
def extraer_texto_pdf(ruta_pdf: str, paginas: Optional[List[int]] = None) -> List[Dict]:
    """Extrae el texto de un PDF página por página."""
    if pdfplumber is None:
        raise ImportError("pdfplumber no está instalado")
    
    resultados = []
    
    with pdfplumber.open(ruta_pdf) as pdf:
        total_paginas = len(pdf.pages)
        print(f"📄 PDF abierto: {total_paginas} páginas detectadas")
        
        if paginas:
            indices = [p - 1 for p in paginas if 0 < p <= total_paginas]
        else:
            indices = range(total_paginas)
        
        for idx in indices:
            pagina = pdf.pages[idx]
            texto = pagina.extract_text() or ""
            tiene_texto = len(texto.strip()) > 10
            
            resultados.append({
                "numero": idx + 1,
                "texto": texto,
                "tiene_texto": tiene_texto,
            })
            
            if not tiene_texto:
                print(f"  ⚠️  Página {idx + 1}: Sin texto (posible imagen escaneada)")
    
    return resultados


def dividir_texto_en_chunks(texto: str, max_chars: int = 4500) -> List[str]:
    """Divide texto largo en chunks para la API."""
    if len(texto) <= max_chars:
        return [texto]
    
    chunks = []
    parrafos = texto.split('\n\n')
    chunk_actual = ""
    
    for parrafo in parrafos:
        if len(chunk_actual) + len(parrafo) + 2 <= max_chars:
            chunk_actual = chunk_actual + "\n\n" + parrafo if chunk_actual else parrafo
        else:
            if chunk_actual:
                chunks.append(chunk_actual)
            
            if len(parrafo) > max_chars:
                oraciones = parrafo.replace('. ', '.|').split('|')
                sub_chunk = ""
                for oracion in oraciones:
                    if len(sub_chunk) + len(oracion) + 1 <= max_chars:
                        sub_chunk += oracion + " "
                    else:
                        if sub_chunk:
                            chunks.append(sub_chunk.strip())
                        sub_chunk = oracion + " "
                chunk_actual = sub_chunk.strip() if sub_chunk else ""
            else:
                chunk_actual = parrafo
    
    if chunk_actual:
        chunks.append(chunk_actual)
    
    return chunks


# ============================================================================
# FUNCIONES DE TRADUCCIÓN
# ============================================================================
def traducir_texto(
    texto: str,
    idioma_origen: str,
    idioma_destino: str,
    servicio: str = "google",
    cache: Optional[CacheTraduccion] = None,
    max_reintentos: int = 3
) -> str:
    """Traduce texto con reintentos exponenciales."""
    if GoogleTranslator is None:
        raise ImportError("deep-translator no está instalado")
    
    if not texto or len(texto.strip()) < 2:
        return texto
    
    # Verificar caché
    if cache:
        traduccion_cacheada = cache.obtener(texto, idioma_origen, idioma_destino)
        if traduccion_cacheada:
            return traduccion_cacheada
    
    # Seleccionar traductor
    if servicio == "google":
        traductor = GoogleTranslator(source=idioma_origen, target=idioma_destino)
    elif servicio == "mymemory":
        traductor = MyMemoryTranslator(source=idioma_origen, target=idioma_destino)
    else:
        traductor = GoogleTranslator(source=idioma_origen, target=idioma_destino)
    
    # Reintentos exponenciales
    for intento in range(max_reintentos):
        try:
            traduccion = traductor.translate(texto)
            if cache and traduccion:
                cache.guardar(texto, traduccion, idioma_origen, idioma_destino)
            return traduccion or texto
        except Exception as e:
            tiempo_espera = (2 ** intento) + (0.1 * intento)
            print(f"    ⚠️  Error (intento {intento + 1}/{max_reintentos}): {e}")
            print(f"       Reintentando en {tiempo_espera:.1f}s...")
            time.sleep(tiempo_espera)
    
    print(f"    ❌ No se pudo traducir después de {max_reintentos} intentos")
    return texto


def traducir_pagina(
    pagina_info: Dict,
    idioma_origen: str,
    idioma_destino: str,
    servicio: str,
    cache: CacheTraduccion
) -> Dict:
    """Traduce una página completa."""
    numero = pagina_info["numero"]
    texto_original = pagina_info["texto"]
    
    if not pagina_info["tiene_texto"]:
        return {
            **pagina_info,
            "texto_traducido": "[Página sin texto extraíble - posible imagen escaneada]",
            "traducida": False
        }
    
    chunks = dividir_texto_en_chunks(texto_original)
    chunks_traducidos = []
    
    for i, chunk in enumerate(chunks):
        traduccion = traducir_texto(chunk, idioma_origen, idioma_destino, servicio, cache)
        chunks_traducidos.append(traduccion)
        if i < len(chunks) - 1:
            time.sleep(0.3)
    
    return {
        **pagina_info,
        "texto_traducido": "\n\n".join(chunks_traducidos),
        "traducida": True
    }


# ============================================================================
# GENERACIÓN DE PDF
# ============================================================================
def generar_pdf_traducido(paginas_traducidas: List[Dict], ruta_salida: str) -> bool:
    """Genera PDF con texto traducido."""
    if SimpleDocTemplate is None:
        raise ImportError("reportlab no está instalado")
    
    try:
        doc = SimpleDocTemplate(
            ruta_salida,
            pagesize=A4,
            rightMargin=2*cm,
            leftMargin=2*cm,
            topMargin=2*cm,
            bottomMargin=2*cm
        )
        
        estilos = getSampleStyleSheet()
        
        estilo_texto = ParagraphStyle(
            'TextoTraducido',
            parent=estilos['Normal'],
            fontSize=11,
            leading=14,
            alignment=TA_JUSTIFY,
            spaceAfter=12
        )
        
        estilo_titulo = ParagraphStyle(
            'TituloPagina',
            parent=estilos['Heading2'],
            fontSize=12,
            spaceAfter=20,
            textColor='#666666'
        )
        
        contenido = []
        
        for pagina in paginas_traducidas:
            numero = pagina["numero"]
            texto = pagina.get("texto_traducido", pagina["texto"])
            
            contenido.append(Paragraph(f"— Página {numero} —", estilo_titulo))
            
            parrafos = texto.split('\n')
            for parrafo in parrafos:
                parrafo = parrafo.strip()
                if parrafo:
                    parrafo_seguro = (
                        parrafo
                        .replace('&', '&amp;')
                        .replace('<', '&lt;')
                        .replace('>', '&gt;')
                    )
                    try:
                        contenido.append(Paragraph(parrafo_seguro, estilo_texto))
                    except Exception:
                        texto_corto = parrafo_seguro[:500] + "..." if len(parrafo_seguro) > 500 else parrafo_seguro
                        contenido.append(Paragraph(texto_corto, estilo_texto))
            
            contenido.append(PageBreak())
        
        doc.build(contenido)
        return True
        
    except Exception as e:
        print(f"❌ Error al generar PDF: {e}")
        return False


# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================
def parsear_paginas(texto: str) -> Optional[List[int]]:
    """Parsea '1,3,5-10' a lista de enteros."""
    if not texto or not texto.strip():
        return None
    
    paginas = []
    partes = texto.replace(" ", "").split(",")
    
    for parte in partes:
        if "-" in parte:
            try:
                inicio, fin = parte.split("-")
                paginas.extend(range(int(inicio), int(fin) + 1))
            except ValueError:
                continue
        else:
            try:
                paginas.append(int(parte))
            except ValueError:
                continue
    
    return sorted(set(paginas)) if paginas else None


def main():
    parser = argparse.ArgumentParser(
        description="Traductor de PDFs - Versión CLI",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Ejemplos:
  python3 translate_pdf_cli.py documento.pdf -d es
  python3 translate_pdf_cli.py libro.pdf -o en -d es -s google
  python3 translate_pdf_cli.py manual.pdf -d fr -p 1,3,5-10

Idiomas soportados:
  es (Español), en (Inglés), fr (Francés), de (Alemán), it (Italiano),
  pt (Portugués), ru (Ruso), zh-CN (Chino), ja (Japonés), ko (Coreano),
  ar (Árabe), hi (Hindi), nl (Holandés), pl (Polaco), tr (Turco),
  auto (Auto-detectar idioma origen)
        """
    )
    
    parser.add_argument("pdf", help="Ruta al archivo PDF a traducir")
    parser.add_argument("-o", "--origen", default="auto", help="Idioma origen (default: auto)")
    parser.add_argument("-d", "--destino", required=True, help="Idioma destino (requerido)")
    parser.add_argument("-s", "--servicio", default="google", choices=["google", "mymemory"],
                        help="Servicio de traducción (default: google)")
    parser.add_argument("-p", "--paginas", default="", help="Páginas específicas: 1,3,5-10")
    parser.add_argument("-O", "--output", default="", help="Ruta del PDF de salida (opcional)")
    
    args = parser.parse_args()
    
    # Validar archivo
    if not os.path.exists(args.pdf):
        print(f"❌ Archivo no encontrado: {args.pdf}")
        sys.exit(1)
    
    # Validar idiomas
    if args.origen not in IDIOMAS:
        print(f"❌ Idioma origen no válido: {args.origen}")
        print(f"   Opciones: {', '.join(IDIOMAS.keys())}")
        sys.exit(1)
    
    if args.destino not in IDIOMAS or args.destino == "auto":
        print(f"❌ Idioma destino no válido: {args.destino}")
        print(f"   Opciones: {', '.join(k for k in IDIOMAS.keys() if k != 'auto')}")
        sys.exit(1)
    
    # Verificar dependencias
    if pdfplumber is None or SimpleDocTemplate is None or GoogleTranslator is None:
        print("❌ Faltan dependencias. Ejecuta:")
        print("   pip install pdfplumber reportlab deep-translator")
        sys.exit(1)
    
    # Parsear páginas
    paginas = parsear_paginas(args.paginas)
    
    # Determinar ruta de salida
    if args.output:
        ruta_salida = args.output
    else:
        directorio = os.path.dirname(args.pdf) or "."
        nombre_base = os.path.splitext(os.path.basename(args.pdf))[0]
        ruta_salida = os.path.join(directorio, f"{nombre_base}_traducido.pdf")
    
    cache = CacheTraduccion()
    
    print("=" * 60)
    print("📚 TRADUCTOR DE PDFs - CLI")
    print("=" * 60)
    print(f"📄 Archivo:  {args.pdf}")
    print(f"🌐 Idiomas:  {IDIOMAS[args.origen]} → {IDIOMAS[args.destino]}")
    print(f"🔧 Servicio: {args.servicio.upper()}")
    if paginas:
        print(f"📑 Páginas:  {args.paginas}")
    print(f"💾 Salida:   {ruta_salida}")
    print("=" * 60)
    print()
    
    # PASO 1: Extraer texto
    print("📄 PASO 1: Extrayendo texto del PDF...")
    try:
        paginas_extraidas = extraer_texto_pdf(args.pdf, paginas)
    except Exception as e:
        print(f"❌ Error al extraer texto: {e}")
        sys.exit(1)
    
    total_paginas = len(paginas_extraidas)
    print(f"   ✓ {total_paginas} página(s) extraída(s)")
    print()
    
    # PASO 2: Traducir
    print("🌐 PASO 2: Traduciendo páginas...")
    paginas_traducidas = []
    
    for i, pagina in enumerate(paginas_extraidas, 1):
        print(f"   [{i}/{total_paginas}] Página {pagina['numero']}...", end=" ", flush=True)
        try:
            pagina_traducida = traducir_pagina(
                pagina, args.origen, args.destino, args.servicio, cache
            )
            paginas_traducidas.append(pagina_traducida)
            if pagina_traducida["traducida"]:
                print("✓")
            else:
                print("⚠️  (sin texto)")
        except Exception as e:
            print(f"❌ Error: {e}")
            paginas_traducidas.append({
                **pagina,
                "texto_traducido": f"[Error: {e}]\n\n{pagina['texto']}",
                "traducida": False
            })
    
    print()
    
    # PASO 3: Generar PDF
    print("📝 PASO 3: Generando PDF traducido...")
    try:
        exito = generar_pdf_traducido(paginas_traducidas, ruta_salida)
        if exito:
            print(f"   ✓ PDF guardado: {ruta_salida}")
        else:
            print("   ❌ Error al generar PDF")
            sys.exit(1)
    except Exception as e:
        print(f"   ❌ Error: {e}")
        sys.exit(1)
    
    # Estadísticas
    stats = cache.estadisticas()
    print()
    print("=" * 60)
    print("🎉 ¡TRADUCCIÓN COMPLETADA!")
    print("=" * 60)
    if stats["hits"] > 0:
        print(f"📊 Caché: {stats['hits']} hits, {stats['misses']} misses")
    print(f"💾 Archivo: {ruta_salida}")
    print()


if __name__ == "__main__":
    main()



