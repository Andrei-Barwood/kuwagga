#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Traductor de PDFs con Interfaz Gráfica
======================================

Aplicación para traducir documentos PDF de un idioma a otro,
preservando el formato básico y generando un nuevo PDF con el texto traducido.

Autor: Generado automáticamente
Fecha: Diciembre 2025
Requiere: pdfplumber, reportlab, deep-translator, tkinter
"""

import os
import sys

# Verificar versión de Python
if sys.version_info < (3, 6):
    print("Error: Se requiere Python 3.6 o superior.", file=sys.stderr)
    sys.exit(1)
import logging
import threading
import time
import hashlib
from pathlib import Path
from typing import Optional, List, Dict, Tuple
from concurrent.futures import ThreadPoolExecutor, as_completed
from functools import lru_cache

# ============================================================================
# INTERFAZ GRÁFICA - Tkinter
# ============================================================================
import tkinter as tk
from tkinter import ttk, filedialog, messagebox, scrolledtext

# ============================================================================
# PROCESAMIENTO DE PDFs
# ============================================================================
try:
    import pdfplumber
except ImportError:
    pdfplumber = None

try:
    from reportlab.lib.pagesizes import letter, A4
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib.units import inch, cm
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
    from reportlab.lib.enums import TA_JUSTIFY, TA_LEFT
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont
except ImportError:
    SimpleDocTemplate = None

# ============================================================================
# TRADUCCIÓN
# ============================================================================
try:
    from deep_translator import GoogleTranslator, DeeplTranslator, MyMemoryTranslator
except ImportError:
    GoogleTranslator = None

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
# IDIOMAS SOPORTADOS
# ============================================================================
IDIOMAS = {
    "Español": "es",
    "Inglés": "en",
    "Francés": "fr",
    "Alemán": "de",
    "Italiano": "it",
    "Portugués": "pt",
    "Ruso": "ru",
    "Chino (Simplificado)": "zh-CN",
    "Chino (Tradicional)": "zh-TW",
    "Japonés": "ja",
    "Coreano": "ko",
    "Árabe": "ar",
    "Hindi": "hi",
    "Holandés": "nl",
    "Polaco": "pl",
    "Turco": "tr",
    "Sueco": "sv",
    "Danés": "da",
    "Noruego": "no",
    "Finlandés": "fi",
    "Griego": "el",
    "Hebreo": "he",
    "Tailandés": "th",
    "Vietnamita": "vi",
    "Indonesio": "id",
    "Malayo": "ms",
    "Catalán": "ca",
    "Ucraniano": "uk",
    "Checo": "cs",
    "Rumano": "ro",
    "Húngaro": "hu",
    "Auto-detectar": "auto",
}

SERVICIOS_TRADUCCION = {
    "Google Translate": "google",
    "MyMemory": "mymemory",
    # "DeepL (requiere API key)": "deepl",
}


# ============================================================================
# CLASE: Caché de Traducciones
# ============================================================================
class CacheTraduccion:
    """
    Caché en memoria para evitar traducir el mismo texto múltiples veces.
    Útil cuando el PDF tiene texto repetido (encabezados, pies de página, etc.)
    """
    
    def __init__(self):
        self._cache: Dict[str, str] = {}
        self._hits = 0
        self._misses = 0
    
    def _generar_clave(self, texto: str, idioma_origen: str, idioma_destino: str) -> str:
        """Genera una clave única para el texto y par de idiomas."""
        contenido = f"{idioma_origen}:{idioma_destino}:{texto}"
        return hashlib.md5(contenido.encode('utf-8')).hexdigest()
    
    def obtener(self, texto: str, idioma_origen: str, idioma_destino: str) -> Optional[str]:
        """Obtiene una traducción del caché si existe."""
        clave = self._generar_clave(texto, idioma_origen, idioma_destino)
        if clave in self._cache:
            self._hits += 1
            return self._cache[clave]
        self._misses += 1
        return None
    
    def guardar(self, texto: str, traduccion: str, idioma_origen: str, idioma_destino: str):
        """Guarda una traducción en el caché."""
        clave = self._generar_clave(texto, idioma_origen, idioma_destino)
        self._cache[clave] = traduccion
    
    def estadisticas(self) -> Dict[str, int]:
        """Retorna estadísticas del caché."""
        return {
            "hits": self._hits,
            "misses": self._misses,
            "entradas": len(self._cache)
        }


# ============================================================================
# FUNCIONES DE EXTRACCIÓN DE TEXTO
# ============================================================================
def extraer_texto_pdf(ruta_pdf: str, paginas: Optional[List[int]] = None) -> List[Dict]:
    """
    Extrae el texto de un PDF página por página usando pdfplumber.
    
    Args:
        ruta_pdf: Ruta al archivo PDF
        paginas: Lista opcional de números de página (1-indexed) a extraer.
                 Si es None, extrae todas las páginas.
    
    Returns:
        Lista de diccionarios con información de cada página:
        [{"numero": 1, "texto": "...", "tiene_texto": True/False}, ...]
    """
    if pdfplumber is None:
        raise ImportError("pdfplumber no está instalado. Ejecuta: pip install pdfplumber")
    
    resultados = []
    
    with pdfplumber.open(ruta_pdf) as pdf:
        total_paginas = len(pdf.pages)
        logger.info(f"PDF abierto: {total_paginas} páginas detectadas")
        
        # Determinar qué páginas procesar
        if paginas:
            # Convertir a 0-indexed y validar
            indices = [p - 1 for p in paginas if 0 < p <= total_paginas]
        else:
            indices = range(total_paginas)
        
        for idx in indices:
            pagina = pdf.pages[idx]
            texto = pagina.extract_text() or ""
            
            # Detectar si la página parece ser una imagen escaneada (sin texto)
            tiene_texto = len(texto.strip()) > 10
            
            resultados.append({
                "numero": idx + 1,
                "texto": texto,
                "tiene_texto": tiene_texto,
                "ancho": pagina.width,
                "alto": pagina.height
            })
            
            if not tiene_texto:
                logger.warning(
                    f"Página {idx + 1}: Sin texto detectable. "
                    "Podría ser una imagen escaneada (requiere OCR con pytesseract)"
                )
    
    return resultados


def dividir_texto_en_chunks(texto: str, max_chars: int = 4500) -> List[str]:
    """
    Divide un texto largo en chunks más pequeños para la API de traducción.
    Intenta dividir por párrafos o oraciones para mantener el contexto.
    
    Args:
        texto: Texto a dividir
        max_chars: Máximo de caracteres por chunk (Google Translate: 5000)
    
    Returns:
        Lista de chunks de texto
    """
    if len(texto) <= max_chars:
        return [texto]
    
    chunks = []
    parrafos = texto.split('\n\n')
    chunk_actual = ""
    
    for parrafo in parrafos:
        # Si el párrafo solo cabe, añadirlo al chunk actual
        if len(chunk_actual) + len(parrafo) + 2 <= max_chars:
            if chunk_actual:
                chunk_actual += "\n\n" + parrafo
            else:
                chunk_actual = parrafo
        else:
            # Guardar chunk actual si existe
            if chunk_actual:
                chunks.append(chunk_actual)
            
            # Si el párrafo es muy largo, dividirlo por oraciones
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
                if sub_chunk:
                    chunk_actual = sub_chunk.strip()
                else:
                    chunk_actual = ""
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
    """
    Traduce un texto usando el servicio especificado con reintentos exponenciales.
    
    Args:
        texto: Texto a traducir
        idioma_origen: Código del idioma origen (ej: "en", "auto")
        idioma_destino: Código del idioma destino (ej: "es")
        servicio: Servicio de traducción ("google", "mymemory", "deepl")
        cache: Instancia opcional de CacheTraduccion
        max_reintentos: Número máximo de reintentos en caso de error
    
    Returns:
        Texto traducido
    """
    if GoogleTranslator is None:
        raise ImportError("deep-translator no está instalado. Ejecuta: pip install deep-translator")
    
    # Texto vacío o muy corto
    if not texto or len(texto.strip()) < 2:
        return texto
    
    # Verificar caché
    if cache:
        traduccion_cacheada = cache.obtener(texto, idioma_origen, idioma_destino)
        if traduccion_cacheada:
            logger.debug("Traducción obtenida del caché")
            return traduccion_cacheada
    
    # Seleccionar traductor
    if servicio == "google":
        traductor = GoogleTranslator(source=idioma_origen, target=idioma_destino)
    elif servicio == "mymemory":
        traductor = MyMemoryTranslator(source=idioma_origen, target=idioma_destino)
    elif servicio == "deepl":
        # DeepL requiere API key - no implementado en versión básica
        raise NotImplementedError("DeepL requiere una API key. Use Google o MyMemory.")
    else:
        traductor = GoogleTranslator(source=idioma_origen, target=idioma_destino)
    
    # Intentar traducción con reintentos exponenciales
    for intento in range(max_reintentos):
        try:
            traduccion = traductor.translate(texto)
            
            # Guardar en caché
            if cache and traduccion:
                cache.guardar(texto, traduccion, idioma_origen, idioma_destino)
            
            return traduccion or texto
            
        except Exception as e:
            tiempo_espera = (2 ** intento) + (0.1 * intento)  # Backoff exponencial
            logger.warning(
                f"Error en traducción (intento {intento + 1}/{max_reintentos}): {e}. "
                f"Reintentando en {tiempo_espera:.1f}s..."
            )
            time.sleep(tiempo_espera)
    
    # Si todos los reintentos fallan, devolver texto original
    logger.error(f"No se pudo traducir el texto después de {max_reintentos} intentos")
    return texto


def traducir_pagina(
    pagina_info: Dict,
    idioma_origen: str,
    idioma_destino: str,
    servicio: str,
    cache: CacheTraduccion,
    callback_progreso: callable = None
) -> Dict:
    """
    Traduce el contenido de una página completa.
    
    Args:
        pagina_info: Diccionario con información de la página
        idioma_origen: Código del idioma origen
        idioma_destino: Código del idioma destino
        servicio: Servicio de traducción
        cache: Instancia de CacheTraduccion
        callback_progreso: Función opcional para reportar progreso
    
    Returns:
        Diccionario con la página traducida
    """
    numero = pagina_info["numero"]
    texto_original = pagina_info["texto"]
    
    if not pagina_info["tiene_texto"]:
        logger.info(f"Página {numero}: Sin texto para traducir (posible imagen escaneada)")
        return {
            **pagina_info,
            "texto_traducido": "[Esta página no contiene texto extraíble. Podría ser una imagen escaneada que requiere OCR.]",
            "traducida": False
        }
    
    logger.info(f"Traduciendo página {numero}...")
    
    # Dividir en chunks si es necesario
    chunks = dividir_texto_en_chunks(texto_original)
    chunks_traducidos = []
    
    for i, chunk in enumerate(chunks):
        traduccion = traducir_texto(
            chunk,
            idioma_origen,
            idioma_destino,
            servicio,
            cache
        )
        chunks_traducidos.append(traduccion)
        
        # Pequeña pausa entre chunks para evitar rate limiting
        if i < len(chunks) - 1:
            time.sleep(0.3)
    
    texto_traducido = "\n\n".join(chunks_traducidos)
    
    if callback_progreso:
        callback_progreso(numero)
    
    return {
        **pagina_info,
        "texto_traducido": texto_traducido,
        "traducida": True
    }


# ============================================================================
# FUNCIONES DE GENERACIÓN DE PDF
# ============================================================================
def generar_pdf_traducido(
    paginas_traducidas: List[Dict],
    ruta_salida: str,
    titulo: str = "Documento Traducido"
) -> bool:
    """
    Genera un nuevo PDF con el texto traducido.
    
    Args:
        paginas_traducidas: Lista de páginas con texto traducido
        ruta_salida: Ruta donde guardar el PDF
        titulo: Título del documento
    
    Returns:
        True si se generó correctamente, False en caso de error
    """
    if SimpleDocTemplate is None:
        raise ImportError("reportlab no está instalado. Ejecuta: pip install reportlab")
    
    try:
        # Crear documento
        doc = SimpleDocTemplate(
            ruta_salida,
            pagesize=A4,
            rightMargin=2*cm,
            leftMargin=2*cm,
            topMargin=2*cm,
            bottomMargin=2*cm
        )
        
        # Estilos
        estilos = getSampleStyleSheet()
        
        # Estilo personalizado para el texto traducido
        estilo_texto = ParagraphStyle(
            'TextoTraducido',
            parent=estilos['Normal'],
            fontSize=11,
            leading=14,
            alignment=TA_JUSTIFY,
            spaceAfter=12
        )
        
        estilo_titulo_pagina = ParagraphStyle(
            'TituloPagina',
            parent=estilos['Heading2'],
            fontSize=12,
            spaceAfter=20,
            textColor='#666666'
        )
        
        # Construir contenido
        contenido = []
        
        for pagina in paginas_traducidas:
            numero = pagina["numero"]
            texto = pagina.get("texto_traducido", pagina["texto"])
            
            # Encabezado de página
            contenido.append(Paragraph(f"— Página {numero} —", estilo_titulo_pagina))
            
            # Procesar texto por párrafos
            parrafos = texto.split('\n')
            for parrafo in parrafos:
                parrafo = parrafo.strip()
                if parrafo:
                    # Escapar caracteres especiales de XML/HTML
                    parrafo_seguro = (
                        parrafo
                        .replace('&', '&amp;')
                        .replace('<', '&lt;')
                        .replace('>', '&gt;')
                    )
                    try:
                        contenido.append(Paragraph(parrafo_seguro, estilo_texto))
                    except Exception:
                        # Si falla el párrafo, añadir como texto plano
                        contenido.append(Paragraph(
                            parrafo_seguro[:500] + "..." if len(parrafo_seguro) > 500 else parrafo_seguro,
                            estilo_texto
                        ))
            
            # Salto de página después de cada página original
            contenido.append(PageBreak())
        
        # Generar PDF
        doc.build(contenido)
        logger.info(f"PDF generado exitosamente: {ruta_salida}")
        return True
        
    except Exception as e:
        logger.error(f"Error al generar PDF: {e}")
        return False


# ============================================================================
# CLASE: Aplicación Principal (GUI)
# ============================================================================
class AplicacionTraductorPDF:
    """
    Interfaz gráfica principal para el traductor de PDFs.
    """
    
    def __init__(self, root: tk.Tk):
        self.root = root
        self.root.title("Traductor de PDFs")
        self.root.geometry("800x700")
        self.root.minsize(700, 600)
        
        # Variables
        self.ruta_pdf = tk.StringVar()
        self.idioma_origen = tk.StringVar(value="Inglés")
        self.idioma_destino = tk.StringVar(value="Español")
        self.servicio = tk.StringVar(value="Google Translate")
        self.paginas_especificas = tk.StringVar()
        self.progreso = tk.DoubleVar(value=0)
        self.traduciendo = False
        self.cache = CacheTraduccion()
        
        # Construir interfaz
        self._crear_interfaz()
        
        # Verificar dependencias
        self._verificar_dependencias()
    
    def _crear_interfaz(self):
        """Construye todos los widgets de la interfaz."""
        
        # Frame principal con padding
        main_frame = ttk.Frame(self.root, padding="10")
        main_frame.pack(fill=tk.BOTH, expand=True)
        
        # ====== SECCIÓN: Selección de archivo ======
        frame_archivo = ttk.LabelFrame(main_frame, text="Archivo PDF", padding="10")
        frame_archivo.pack(fill=tk.X, pady=(0, 10))
        
        ttk.Entry(frame_archivo, textvariable=self.ruta_pdf, width=60).pack(side=tk.LEFT, fill=tk.X, expand=True)
        ttk.Button(frame_archivo, text="Examinar...", command=self._seleccionar_archivo).pack(side=tk.LEFT, padx=(10, 0))
        
        # ====== SECCIÓN: Configuración de idiomas ======
        frame_idiomas = ttk.LabelFrame(main_frame, text="Configuración de Traducción", padding="10")
        frame_idiomas.pack(fill=tk.X, pady=(0, 10))
        
        # Fila de idiomas
        frame_idiomas_row = ttk.Frame(frame_idiomas)
        frame_idiomas_row.pack(fill=tk.X)
        
        # Idioma origen
        ttk.Label(frame_idiomas_row, text="Idioma origen:").pack(side=tk.LEFT)
        combo_origen = ttk.Combobox(
            frame_idiomas_row,
            textvariable=self.idioma_origen,
            values=list(IDIOMAS.keys()),
            state="readonly",
            width=20
        )
        combo_origen.pack(side=tk.LEFT, padx=(5, 20))
        
        # Flecha
        ttk.Label(frame_idiomas_row, text="→").pack(side=tk.LEFT, padx=10)
        
        # Idioma destino
        ttk.Label(frame_idiomas_row, text="Idioma destino:").pack(side=tk.LEFT, padx=(10, 0))
        combo_destino = ttk.Combobox(
            frame_idiomas_row,
            textvariable=self.idioma_destino,
            values=[k for k in IDIOMAS.keys() if k != "Auto-detectar"],
            state="readonly",
            width=20
        )
        combo_destino.pack(side=tk.LEFT, padx=(5, 0))
        
        # Fila de servicio
        frame_servicio = ttk.Frame(frame_idiomas)
        frame_servicio.pack(fill=tk.X, pady=(10, 0))
        
        ttk.Label(frame_servicio, text="Servicio de traducción:").pack(side=tk.LEFT)
        combo_servicio = ttk.Combobox(
            frame_servicio,
            textvariable=self.servicio,
            values=list(SERVICIOS_TRADUCCION.keys()),
            state="readonly",
            width=25
        )
        combo_servicio.pack(side=tk.LEFT, padx=(5, 0))
        
        # ====== SECCIÓN: Páginas específicas ======
        frame_paginas = ttk.LabelFrame(main_frame, text="Páginas a Traducir (Opcional)", padding="10")
        frame_paginas.pack(fill=tk.X, pady=(0, 10))
        
        ttk.Label(frame_paginas, text="Páginas específicas (ej: 1,3,5-10):").pack(side=tk.LEFT)
        ttk.Entry(frame_paginas, textvariable=self.paginas_especificas, width=30).pack(side=tk.LEFT, padx=(10, 0))
        ttk.Label(frame_paginas, text="(Dejar vacío para todas)", foreground="gray").pack(side=tk.LEFT, padx=(10, 0))
        
        # ====== SECCIÓN: Botones de acción ======
        frame_botones = ttk.Frame(main_frame)
        frame_botones.pack(fill=tk.X, pady=(0, 10))
        
        self.btn_traducir = ttk.Button(
            frame_botones,
            text="▶ Iniciar Traducción",
            command=self._iniciar_traduccion,
            style="Accent.TButton"
        )
        self.btn_traducir.pack(side=tk.LEFT)
        
        self.btn_cancelar = ttk.Button(
            frame_botones,
            text="✕ Cancelar",
            command=self._cancelar_traduccion,
            state=tk.DISABLED
        )
        self.btn_cancelar.pack(side=tk.LEFT, padx=(10, 0))
        
        ttk.Button(
            frame_botones,
            text="Limpiar Log",
            command=self._limpiar_log
        ).pack(side=tk.RIGHT)
        
        # ====== SECCIÓN: Barra de progreso ======
        frame_progreso = ttk.Frame(main_frame)
        frame_progreso.pack(fill=tk.X, pady=(0, 10))
        
        self.lbl_progreso = ttk.Label(frame_progreso, text="Listo")
        self.lbl_progreso.pack(side=tk.LEFT)
        
        self.barra_progreso = ttk.Progressbar(
            frame_progreso,
            variable=self.progreso,
            maximum=100,
            mode='determinate'
        )
        self.barra_progreso.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(10, 0))
        
        # ====== SECCIÓN: Log de estado ======
        frame_log = ttk.LabelFrame(main_frame, text="Log de Estado", padding="10")
        frame_log.pack(fill=tk.BOTH, expand=True)
        
        self.txt_log = scrolledtext.ScrolledText(
            frame_log,
            wrap=tk.WORD,
            height=15,
            font=("Consolas", 10)
        )
        self.txt_log.pack(fill=tk.BOTH, expand=True)
        
        # Configurar tags para colores
        self.txt_log.tag_configure("info", foreground="#0066cc")
        self.txt_log.tag_configure("exito", foreground="#00aa00")
        self.txt_log.tag_configure("error", foreground="#cc0000")
        self.txt_log.tag_configure("aviso", foreground="#cc6600")
    
    def _verificar_dependencias(self):
        """Verifica que las dependencias necesarias estén instaladas."""
        faltantes = []
        
        if pdfplumber is None:
            faltantes.append("pdfplumber")
        if SimpleDocTemplate is None:
            faltantes.append("reportlab")
        if GoogleTranslator is None:
            faltantes.append("deep-translator")
        
        if faltantes:
            self._log(
                f"⚠️ Dependencias faltantes: {', '.join(faltantes)}\n"
                f"   Instalar con: pip install {' '.join(faltantes)}",
                "error"
            )
            self.btn_traducir.config(state=tk.DISABLED)
        else:
            self._log("✓ Todas las dependencias están instaladas correctamente", "exito")
    
    def _log(self, mensaje: str, tipo: str = "info"):
        """Añade un mensaje al log con formato."""
        timestamp = time.strftime("%H:%M:%S")
        self.txt_log.insert(tk.END, f"[{timestamp}] ", "info")
        self.txt_log.insert(tk.END, f"{mensaje}\n", tipo)
        self.txt_log.see(tk.END)
        self.root.update_idletasks()
    
    def _limpiar_log(self):
        """Limpia el área de log."""
        self.txt_log.delete(1.0, tk.END)
    
    def _seleccionar_archivo(self):
        """Abre diálogo para seleccionar archivo PDF."""
        ruta = filedialog.askopenfilename(
            title="Seleccionar PDF",
            filetypes=[("Archivos PDF", "*.pdf"), ("Todos los archivos", "*.*")]
        )
        if ruta:
            self.ruta_pdf.set(ruta)
            self._log(f"Archivo seleccionado: {os.path.basename(ruta)}")
    
    def _parsear_paginas(self, texto: str) -> Optional[List[int]]:
        """
        Parsea una cadena de páginas como "1,3,5-10" a una lista de números.
        """
        if not texto.strip():
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
    
    def _iniciar_traduccion(self):
        """Inicia el proceso de traducción en un hilo separado."""
        ruta = self.ruta_pdf.get()
        
        if not ruta:
            messagebox.showerror("Error", "Por favor, selecciona un archivo PDF")
            return
        
        if not os.path.exists(ruta):
            messagebox.showerror("Error", f"El archivo no existe: {ruta}")
            return
        
        # Parsear páginas específicas
        paginas = self._parsear_paginas(self.paginas_especificas.get())
        
        # Obtener códigos de idioma
        codigo_origen = IDIOMAS.get(self.idioma_origen.get(), "auto")
        codigo_destino = IDIOMAS.get(self.idioma_destino.get(), "es")
        servicio = SERVICIOS_TRADUCCION.get(self.servicio.get(), "google")
        
        if codigo_origen == codigo_destino and codigo_origen != "auto":
            messagebox.showwarning("Aviso", "El idioma origen y destino son iguales")
            return
        
        # Deshabilitar controles
        self.traduciendo = True
        self.btn_traducir.config(state=tk.DISABLED)
        self.btn_cancelar.config(state=tk.NORMAL)
        self.progreso.set(0)
        
        # Iniciar en hilo separado
        hilo = threading.Thread(
            target=self._proceso_traduccion,
            args=(ruta, codigo_origen, codigo_destino, servicio, paginas),
            daemon=True
        )
        hilo.start()
    
    def _proceso_traduccion(
        self,
        ruta_pdf: str,
        idioma_origen: str,
        idioma_destino: str,
        servicio: str,
        paginas: Optional[List[int]]
    ):
        """Proceso principal de traducción (ejecutado en hilo separado)."""
        try:
            # ====== PASO 1: Extraer texto ======
            self._log("📄 Extrayendo texto del PDF...", "info")
            self.lbl_progreso.config(text="Extrayendo texto...")
            
            try:
                paginas_extraidas = extraer_texto_pdf(ruta_pdf, paginas)
            except Exception as e:
                self._log(f"❌ Error al extraer texto: {e}", "error")
                self._finalizar_traduccion(exito=False)
                return
            
            total_paginas = len(paginas_extraidas)
            self._log(f"✓ {total_paginas} página(s) extraída(s)", "exito")
            
            # Verificar si hay texto para traducir
            paginas_con_texto = sum(1 for p in paginas_extraidas if p["tiene_texto"])
            if paginas_con_texto == 0:
                self._log(
                    "⚠️ El PDF no contiene texto extraíble. "
                    "Podría ser un documento escaneado que requiere OCR (pytesseract).",
                    "aviso"
                )
            
            # ====== PASO 2: Traducir páginas ======
            self._log(f"🌐 Traduciendo con {servicio.upper()}...", "info")
            self.lbl_progreso.config(text="Traduciendo...")
            
            paginas_traducidas = []
            
            def actualizar_progreso(num_pagina):
                progreso = (len(paginas_traducidas) / total_paginas) * 100
                self.progreso.set(progreso)
                self.lbl_progreso.config(text=f"Traduciendo página {num_pagina}...")
            
            # Traducir secuencialmente (para evitar rate limiting excesivo)
            for pagina in paginas_extraidas:
                if not self.traduciendo:
                    self._log("⚠️ Traducción cancelada por el usuario", "aviso")
                    self._finalizar_traduccion(exito=False)
                    return
                
                try:
                    pagina_traducida = traducir_pagina(
                        pagina,
                        idioma_origen,
                        idioma_destino,
                        servicio,
                        self.cache,
                        actualizar_progreso
                    )
                    paginas_traducidas.append(pagina_traducida)
                    self._log(f"  ✓ Página {pagina['numero']} traducida", "exito")
                except Exception as e:
                    self._log(f"  ❌ Error en página {pagina['numero']}: {e}", "error")
                    # Añadir página sin traducir
                    paginas_traducidas.append({
                        **pagina,
                        "texto_traducido": f"[Error de traducción: {e}]\n\n{pagina['texto']}",
                        "traducida": False
                    })
            
            # ====== PASO 3: Generar PDF ======
            self._log("📝 Generando PDF traducido...", "info")
            self.lbl_progreso.config(text="Generando PDF...")
            self.progreso.set(90)
            
            # Determinar ruta de salida
            directorio = os.path.dirname(ruta_pdf)
            nombre_base = os.path.splitext(os.path.basename(ruta_pdf))[0]
            ruta_salida = os.path.join(directorio, f"{nombre_base}_traducido.pdf")
            
            try:
                exito = generar_pdf_traducido(paginas_traducidas, ruta_salida)
                if exito:
                    self._log(f"✓ PDF guardado: {ruta_salida}", "exito")
                else:
                    self._log("❌ Error al generar el PDF", "error")
            except Exception as e:
                self._log(f"❌ Error al generar PDF: {e}", "error")
                exito = False
            
            # Estadísticas del caché
            stats = self.cache.estadisticas()
            if stats["hits"] > 0:
                self._log(
                    f"📊 Caché: {stats['hits']} hits, {stats['misses']} misses "
                    f"({stats['entradas']} entradas)",
                    "info"
                )
            
            self._finalizar_traduccion(exito=exito)
            
        except Exception as e:
            self._log(f"❌ Error inesperado: {e}", "error")
            import traceback
            logger.error(traceback.format_exc())
            self._finalizar_traduccion(exito=False)
    
    def _cancelar_traduccion(self):
        """Marca la traducción para cancelación."""
        self.traduciendo = False
        self._log("Cancelando traducción...", "aviso")
    
    def _finalizar_traduccion(self, exito: bool):
        """Restaura el estado de la interfaz después de la traducción."""
        self.traduciendo = False
        self.btn_traducir.config(state=tk.NORMAL)
        self.btn_cancelar.config(state=tk.DISABLED)
        
        if exito:
            self.progreso.set(100)
            self.lbl_progreso.config(text="¡Completado!")
            self._log("=" * 50, "info")
            self._log("🎉 ¡Traducción completada exitosamente!", "exito")
        else:
            self.lbl_progreso.config(text="Error o cancelado")


# ============================================================================
# PUNTO DE ENTRADA
# ============================================================================
def main():
    """Función principal que inicia la aplicación."""
    root = tk.Tk()
    
    # Configuración básica sin llamadas que puedan causar problemas de compatibilidad
    # en ciertas versiones de macOS
    try:
        # Usar estilo nativo del sistema si está disponible
        style = ttk.Style()
        if sys.platform == "darwin":
            style.theme_use("aqua")
        elif sys.platform == "win32":
            style.theme_use("vista")
        else:
            style.theme_use("clam")
    except tk.TclError:
        pass  # Usar tema por defecto si falla
    
    app = AplicacionTraductorPDF(root)
    root.mainloop()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nOperación cancelada por el usuario.", file=sys.stderr)
        sys.exit(130)
    except Exception as e:
        logger.exception("Error inesperado en la aplicación")
        print(f"Error inesperado: {e}", file=sys.stderr)
        sys.exit(1)

