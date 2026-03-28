#!/usr/bin/env python3
"""
Audio/Video Conversion Tool v2.0 - Python Implementation
Conversión completa de archivos de audio entre formatos
Reimplementación completa en Python 3 para mayor flexibilidad y robustez
"""

import os
import sys
import subprocess
import shutil
import argparse
import signal
from pathlib import Path
from typing import List, Tuple, Optional, Dict
import time
import threading
import tempfile
import json
import re
import atexit
from datetime import datetime

# ============================================================================
# CONFIGURACIÓN Y CONSTANTES
# ============================================================================

# Configuración de calidad
QUALITY_MODE = "vbr"
VBR_QUALITY = 0
CBR_BITRATE = "320k"
VIDEO_CRF = 18
VIDEO_PRESET = "slow"
VIDEO_RESOLUTION = "1920:1080"

# Resoluciones disponibles para M4A → MP4
RESOLUTION_PROFILES = {
    "1": {
        "name": "480p (854x480)",
        "resolution": "854:480",
        "preset": "fast",
        "crf": 23,
        "speed_factor": 0.15,
        "size_factor": 2.0,
        "description": "Ideal para dispositivos móviles antiguos, transmisiones de bajo ancho de banda, o cuando el espacio en disco es limitado. Compatible con la mayoría de reproductores."
    },
    "2": {
        "name": "720p (1280x720)",
        "resolution": "1280:720",
        "preset": "medium",
        "crf": 23,
        "speed_factor": 0.4,
        "size_factor": 4.0,
        "description": "Estándar HD. Perfecto para tablets, laptops y monitores pequeños. Balance entre calidad y tamaño de archivo. Recomendado para contenido educativo o podcasts."
    },
    "3": {
        "name": "1080p (1920x1080) - Recomendado",
        "resolution": "1920:1080",
        "preset": "medium",
        "crf": 23,
        "speed_factor": 0.8,
        "size_factor": 7.5,
        "description": "Full HD estándar. Excelente para YouTube, streaming en general, y visualización en monitores y televisores modernos. Mejor relación calidad/tamaño."
    },
    "4": {
        "name": "1080p Alta Calidad (1920x1080)",
        "resolution": "1920:1080",
        "preset": "slow",
        "crf": 18,
        "speed_factor": 2.0,
        "size_factor": 10.0,
        "description": "Full HD con máxima calidad (casi lossless). Ideal para archivo maestro, edición profesional, o cuando la calidad visual es prioritaria sobre el tamaño."
    },
    "5": {
        "name": "1440p (2560x1440)",
        "resolution": "2560:1440",
        "preset": "medium",
        "crf": 23,
        "speed_factor": 1.2,
        "size_factor": 12.0,
        "description": "QHD/2K. Perfecto para monitores de alta resolución, contenido profesional, o cuando necesitas más detalle que 1080p sin llegar a 4K."
    },
    "6": {
        "name": "4K (3840x2160)",
        "resolution": "3840:2160",
        "preset": "slow",
        "crf": 23,
        "speed_factor": 2.5,
        "size_factor": 20.0,
        "description": "Ultra HD. Máxima resolución disponible. Ideal para televisores 4K, producción profesional, o cuando buscas la mejor calidad posible. Requiere más tiempo y espacio."
    },
}

# Configuración para álbum unificado (modo 4)
SILENCE_DURATION = 2
MP3_BITRATE = "320k"
ALBUM_NAME = ""

# Configuración para FLAC de alta resolución (modo 5)
FLAC_SAMPLE_RATE = 192000
FLAC_BIT_DEPTH = 32
FLAC_COMPRESSION = 8

# Variables globales
INTERRUPTED = False
TMP_FILES = []
TMP_DIRS = []
AUDIO_SOURCE_EXTENSIONS = {'.wav', '.flac', '.aiff', '.aif'}
AUDIO_SOURCE_FORMATS_LABEL = "WAV/AIFF/FLAC"
HIRES_AUDIO_SOURCE_EXTENSIONS = AUDIO_SOURCE_EXTENSIONS | {'.mp3', '.m4a'}
HIRES_AUDIO_SOURCE_FORMATS_LABEL = "WAV/AIFF/FLAC/MP3/M4A"
LOSSY_AUDIO_SOURCE_EXTENSIONS = {'.mp3', '.m4a'}

# ============================================================================
# COLORES Y FORMATO (Paleta: Forest Green)
# ============================================================================

class Colors:
    DARK_GREEN = '\033[38;5;65m'
    MEDIUM_GREEN = '\033[38;5;71m'
    LIGHT_GREEN = '\033[38;5;79m'
    LIME = '\033[38;5;156m'
    YELLOW_GREEN = '\033[38;5;192m'
    DARK_FOREST = '\033[38;5;22m'
    NC = '\033[0m'
    BOLD = '\033[1m'

SPINNER_FRAMES = ['🎵', '🎶', '🎸', '🎹', '🎺', '🎷', '🥁', '🎻']
MUSIC_NOTES = ['♪', '♫', '♬', '♩']

# ============================================================================
# FUNCIONES DE UTILIDAD
# ============================================================================

def print_header(msg: str):
    print(f"\n{Colors.LIME}{Colors.BOLD}═══ {msg} ═══{Colors.NC}\n")


def print_info(msg: str):
    print(f"{Colors.MEDIUM_GREEN}ℹ{Colors.NC}  {msg}")


def print_success(msg: str):
    print(f"{Colors.LIGHT_GREEN}✓{Colors.NC}  {msg}")


def print_error(msg: str):
    print(f"{Colors.DARK_GREEN}✗{Colors.NC}  {msg}", file=sys.stderr)


def print_warning(msg: str):
    print(f"{Colors.YELLOW_GREEN}⚠{Colors.NC}  {msg}")


def get_file_size(path: Path) -> str:
    try:
        size = path.stat().st_size
        for unit in ['B', 'K', 'M', 'G']:
            if size < 1024.0:
                return f"{size:.1f}{unit}" if size < 10 else f"{int(size)}{unit}"
            size /= 1024.0
        return f"{size:.1f}T"
    except Exception:
        return "0B"


def format_duration(seconds: float) -> str:
    try:
        secs = int(float(seconds))
        mins = secs // 60
        secs = secs % 60
        hours = mins // 60
        mins = mins % 60
        if hours > 0:
            return f"{hours}:{mins:02d}:{secs:02d}"
        return f"{mins:02d}:{secs:02d}"
    except Exception:
        return "00:00"


def confirm(prompt: str = "¿Continuar?") -> bool:
    while True:
        try:
            response = input(f"{Colors.YELLOW_GREEN}{prompt} (s/n): {Colors.NC}").strip().lower()
            if response in ['s', 'y', 'sí', 'yes', 'si']:
                return True
            elif response in ['n', 'no']:
                return False
            else:
                print(f"    {Colors.DARK_GREEN}⚠ Opción no válida. Escribe 's' (sí) o 'n' (no){Colors.NC}")
        except (EOFError, KeyboardInterrupt):
            return False


def check_dependencies() -> bool:
    missing = []
    if not shutil.which('ffmpeg'):
        missing.append('ffmpeg')
    if not shutil.which('ffprobe'):
        missing.append('ffprobe')
    if missing:
        print_error(f"Dependencias faltantes: {', '.join(missing)}")
        print_info("Instalar con: brew install ffmpeg")
        return False
    return True


def select_folder() -> Optional[Path]:
    """Seleccionar carpeta pidiendo al usuario que pegue la ruta desde Finder"""
    print_info("Selecciona la carpeta en Finder y copia la ruta de acceso.")
    print(f"    {Colors.YELLOW_GREEN}→ En Finder: Cmd+Opt+C para copiar la ruta{Colors.NC}")
    print(f"    {Colors.YELLOW_GREEN}→ O arrastra la carpeta a Terminal y presiona Tab{Colors.NC}")
    print()
    
    while True:
        try:
            folder_input = input(f"{Colors.YELLOW_GREEN}Pega la ruta de la carpeta (o Enter para cancelar): {Colors.NC}").strip()
            
            if not folder_input:
                print_warning("Operación cancelada.")
                return None
            
            # Limpiar la entrada (remover comillas si las hay, espacios al inicio/final)
            folder_input = folder_input.strip().strip('"').strip("'")
            
            # Expandir ~ si se usa
            folder_input = folder_input.replace('~', str(Path.home()))
            
            folder = Path(folder_input).expanduser().resolve()
            
            if folder.exists() and folder.is_dir():
                print_success(f"Carpeta seleccionada: {folder}")
                return folder
            else:
                print_error(f"La carpeta no existe o no es válida: {folder_input}")
                print(f"    {Colors.MEDIUM_GREEN}Por favor, verifica la ruta e intenta de nuevo.{Colors.NC}")
                print()
        except (EOFError, KeyboardInterrupt):
            print()
            print_warning("Operación cancelada.")
            return None
        except Exception as e:
            print_error(f"Error al procesar la ruta: {e}")
            print(f"    {Colors.MEDIUM_GREEN}Por favor, verifica la ruta e intenta de nuevo.{Colors.NC}")
            print()


def select_output_folder(default_dir: Path) -> Optional[Path]:
    """
    Seleccionar carpeta de destino pidiendo al usuario que pegue la ruta desde Finder.
    Si se presiona Enter, usa el directorio por defecto (directorio actual/source).
    
    Args:
        default_dir: Directorio por defecto a usar si se presiona Enter
    
    Returns:
        Path de la carpeta seleccionada, o default_dir si se presiona Enter, o None si se cancela
    """
    print_info("Selecciona la carpeta de destino en Finder y copia la ruta de acceso.")
    print(f"    {Colors.YELLOW_GREEN}→ En Finder: Cmd+Opt+C para copiar la ruta{Colors.NC}")
    print(f"    {Colors.YELLOW_GREEN}→ O arrastra la carpeta a Terminal y presiona Tab{Colors.NC}")
    print(f"    {Colors.MEDIUM_GREEN}→ O presiona Enter para utilizar el directorio actual{Colors.NC}")
    print()
    print(f"    {Colors.LIME}Directorio actual:{Colors.NC} {Colors.LIGHT_GREEN}{default_dir}{Colors.NC}")
    print()
    
    while True:
        try:
            folder_input = input(f"{Colors.YELLOW_GREEN}Pega la ruta de la carpeta de destino (Enter=directorio actual): {Colors.NC}").strip()
            
            # Si es Enter (vacío), usar el directorio por defecto
            if not folder_input:
                print()
                print_success(f"Usando directorio actual: {default_dir}")
                print()
                return default_dir
            
            # Limpiar la entrada (remover comillas si las hay, espacios al inicio/final)
            folder_input = folder_input.strip().strip('"').strip("'")
            
            # Expandir ~ si se usa
            folder_input = folder_input.replace('~', str(Path.home()))
            
            folder = Path(folder_input).expanduser().resolve()
            
            if folder.exists() and folder.is_dir():
                print()
                print_success(f"Carpeta de destino seleccionada: {folder}")
                print()
                return folder
            else:
                print_error(f"La carpeta no existe o no es válida: {folder_input}")
                print(f"    {Colors.MEDIUM_GREEN}Por favor, verifica la ruta e intenta de nuevo.{Colors.NC}")
                print()
        except (EOFError, KeyboardInterrupt):
            print()
            print_warning("Operación cancelada.")
            return None
        except Exception as e:
            print_error(f"Error al procesar la ruta: {e}")
            print(f"    {Colors.MEDIUM_GREEN}Por favor, verifica la ruta e intenta de nuevo.{Colors.NC}")
            print()


def collect_audio_files(directory: Path, recursive: bool = False,
                        extensions: Optional[set] = None) -> List[Path]:
    """Recolecta archivos de audio por extensión (filtrado estricto)."""
    ext_set = {ext.lower() for ext in (extensions or AUDIO_SOURCE_EXTENSIONS)}
    if not directory.exists() or not directory.is_dir():
        return []
    pattern_iter = directory.rglob("*") if recursive else directory.glob("*")
    files = [p for p in pattern_iter if p.is_file() and p.suffix.lower() in ext_set]
    return sorted(files, key=lambda p: str(p).lower())


def parse_number_selection(raw_selection: str, min_value: int, max_value: int) -> Optional[List[int]]:
    """
    Parsea selección numérica con coma y rangos.
    Ejemplos válidos: "1,3,5", "2-4", "1,4-6".
    Retorna lista ordenada sin duplicados o None si hay error.
    """
    if not raw_selection:
        return []

    selected_numbers = set()
    parts = [part.strip() for part in raw_selection.split(',') if part.strip()]
    if not parts:
        return []

    for part in parts:
        if '-' in part:
            bounds = [b.strip() for b in part.split('-', 1)]
            if len(bounds) != 2 or not bounds[0].isdigit() or not bounds[1].isdigit():
                return None
            start = int(bounds[0])
            end = int(bounds[1])
            if start > end:
                return None
            if start < min_value or end > max_value:
                return None
            selected_numbers.update(range(start, end + 1))
        else:
            if not part.isdigit():
                return None
            value = int(part)
            if value < min_value or value > max_value:
                return None
            selected_numbers.add(value)

    return sorted(selected_numbers)


def select_audio_source_files(source_dir: Path,
                              extensions: Optional[set] = None,
                              formats_label: Optional[str] = None,
                              filter_note: Optional[str] = None) -> Optional[List[Path]]:
    """
    Selecciona la fuente de archivos de audio:
    - Directorio actual
    - Uno de los subdirectorios con archivos compatibles
    - Todos los subdirectorios compatibles

    Solo considera extensiones en `extensions` (por defecto WAV/AIFF/FLAC).
    """
    ext_set = {ext.lower() for ext in (extensions or AUDIO_SOURCE_EXTENSIONS)}
    label = formats_label or AUDIO_SOURCE_FORMATS_LABEL
    current_dir_files = collect_audio_files(source_dir, recursive=False, extensions=ext_set)

    print_header("Origen de Archivos de Audio")
    print_info(f"Filtro activo: {label}.")
    if filter_note:
        print_info(filter_note)
    print_info(f"Directorio actual: {len(current_dir_files)} archivo(s) compatible(s).")
    print()

    explore_subdirs = confirm("¿Deseas explorar subdirectorios disponibles en esta carpeta?")
    print()
    if not explore_subdirs:
        return current_dir_files

    subdirs_with_files = []
    for child in sorted(source_dir.iterdir(), key=lambda p: p.name.lower()):
        if child.is_dir():
            child_files = collect_audio_files(child, recursive=True, extensions=ext_set)
            if child_files:
                subdirs_with_files.append((child, child_files))

    if not subdirs_with_files:
        print_warning(f"No se encontraron subdirectorios con archivos {label}.")
        return current_dir_files

    total_subdir_files = sum(len(files) for _, files in subdirs_with_files)

    print(f"    {Colors.LIME}Fuentes disponibles:{Colors.NC}")
    print(f"  {Colors.LIME}0){Colors.NC} Directorio actual ({len(current_dir_files)} archivo(s))")
    for idx, (subdir, files) in enumerate(subdirs_with_files, 1):
        rel_name = subdir.relative_to(source_dir)
        print(f"  {Colors.LIME}{idx}){Colors.NC} {rel_name}/ ({len(files)} archivo(s))")
    all_option = len(subdirs_with_files) + 1
    print(f"  {Colors.LIME}{all_option}){Colors.NC} Todos los subdirectorios ({total_subdir_files} archivo(s))")
    print(f"  {Colors.LIME}b){Colors.NC} Modo batch subdirectorios (selección múltiple)")
    print()
    print(f"    {Colors.YELLOW_GREEN}💡 Enter = directorio actual{Colors.NC}")
    print(f"    {Colors.YELLOW_GREEN}💡 En modo batch puedes usar: 1,3,5 o rangos 1-4{Colors.NC}")
    print()

    while True:
        try:
            choice = input(f"{Colors.YELLOW_GREEN}▶ Selecciona origen (0-{all_option}): {Colors.NC}").strip()

            if not choice or choice == "0":
                print_success(f"Usando directorio actual: {len(current_dir_files)} archivo(s)")
                print()
                return current_dir_files

            if choice.lower() == "b":
                print()
                print_info("Modo batch de subdirectorios activado.")
                print(f"    {Colors.MEDIUM_GREEN}Selecciona varios subdirectorios en una sola ejecución.{Colors.NC}")
                print(f"    {Colors.MEDIUM_GREEN}Ejemplos: 1,3,5  |  2-6  |  1,4-7,10{Colors.NC}")
                print(f"    {Colors.YELLOW_GREEN}Enter = todos los subdirectorios{Colors.NC}")
                print()

                batch_choice = input(
                    f"{Colors.YELLOW_GREEN}▶ Subdirectorios batch (1-{len(subdirs_with_files)}): {Colors.NC}"
                ).strip()

                if not batch_choice:
                    selected_indices = list(range(1, len(subdirs_with_files) + 1))
                else:
                    selected_indices = parse_number_selection(
                        batch_choice, min_value=1, max_value=len(subdirs_with_files)
                    )
                    if selected_indices is None:
                        print_error(
                            f"Selección inválida. Usa números entre 1 y {len(subdirs_with_files)}, "
                            "separados por comas o rangos (ej: 1,3,5 o 2-4)."
                        )
                        print()
                        continue

                selected_files = []
                selected_names = []
                for idx in selected_indices:
                    subdir, files = subdirs_with_files[idx - 1]
                    selected_files.extend(files)
                    selected_names.append(str(subdir.relative_to(source_dir)))

                print_success(
                    f"Modo batch: {len(selected_indices)} subdirectorio(s), "
                    f"{len(selected_files)} archivo(s) seleccionado(s)."
                )
                for name in selected_names:
                    print(f"    {Colors.MEDIUM_GREEN}• {name}/{Colors.NC}")
                print()
                return selected_files

            if not choice.isdigit():
                print_error(f"Opción inválida. Ingresa un número entre 0 y {all_option}, o 'b' para batch.")
                continue

            selected = int(choice)
            if selected == all_option:
                selected_files = []
                for _, files in subdirs_with_files:
                    selected_files.extend(files)
                print_success(f"Usando todos los subdirectorios: {len(selected_files)} archivo(s)")
                print()
                return selected_files

            if 1 <= selected <= len(subdirs_with_files):
                selected_subdir, selected_files = subdirs_with_files[selected - 1]
                rel_name = selected_subdir.relative_to(source_dir)
                print_success(f"Subdirectorio seleccionado: {rel_name}/ ({len(selected_files)} archivo(s))")
                print()
                return selected_files

            print_error(f"Opción inválida. Ingresa un número entre 0 y {all_option}.")
        except (EOFError, KeyboardInterrupt):
            return None


def get_source_bucket_dir(source_dir: Path, audio_file: Path) -> Path:
    """
    Retorna el directorio "bucket" del archivo:
    - source_dir para archivos en el directorio raíz
    - primer subdirectorio bajo source_dir para archivos en subcarpetas
    """
    try:
        source_resolved = source_dir.resolve()
        file_resolved = audio_file.resolve()
        rel = file_resolved.relative_to(source_resolved)
        if len(rel.parts) <= 1:
            return source_resolved
        return source_resolved / rel.parts[0]
    except Exception:
        return audio_file.parent.resolve()


def resolve_output_dir_for_file(source_dir: Path, selected_output_dir: Path,
                                audio_file: Path, subdir_name: str) -> Path:
    """
    Resuelve el directorio de salida por archivo.

    Si el destino seleccionado es el directorio actual (source_dir):
    - Archivos del raíz -> source_dir/masters
    - Archivos de subdirectorios -> <subdirectorio>/subdir_name

    Si no es el directorio actual:
    - Crea carpeta en destino con el nombre de la carpeta origen del archivo.
      Ejemplos:
      - Archivo en source_dir -> selected_output_dir/source_dir.name
      - Archivo en source_dir/subX -> selected_output_dir/subX
    """
    try:
        source_resolved = source_dir.resolve()
        selected_resolved = selected_output_dir.resolve()
    except Exception:
        source_resolved = source_dir
        selected_resolved = selected_output_dir

    bucket_dir = get_source_bucket_dir(source_resolved, audio_file)

    if selected_resolved != source_resolved:
        return selected_resolved / bucket_dir.name

    if bucket_dir == source_resolved:
        return source_resolved / "masters"
    return bucket_dir / subdir_name


def get_audio_duration(file_path: Path) -> Optional[float]:
    try:
        result = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration',
                                '-of', 'default=nw=1:nk=1', str(file_path)],
                               capture_output=True, text=True)
        if result.returncode == 0:
            return float(result.stdout.strip())
    except Exception:
        pass
    return None


def estimate_output_size(duration_minutes: float, profile: dict, audio_size_mb: float) -> float:
    """Estima el tamaño del archivo MP4 de salida en MB"""
    # Tamaño base del video (MB por minuto según resolución y CRF)
    video_size = duration_minutes * profile["size_factor"]
    # Agregar tamaño del audio (normalmente se copia sin cambios)
    # El audio se incluye directamente en el MP4
    return video_size + audio_size_mb


def estimate_conversion_time(duration_minutes: float, profile: dict) -> float:
    """Estima el tiempo de conversión en minutos"""
    # Tiempo base: duración del video * factor de velocidad
    # El factor de velocidad depende del preset y resolución
    base_time = duration_minutes * profile["speed_factor"]
    return base_time


def format_time_estimate(minutes: float) -> str:
    """Formatea el tiempo estimado de forma legible"""
    if minutes < 1:
        return f"{int(minutes * 60)} segundos"
    elif minutes < 60:
        return f"{int(minutes)} minutos"
    else:
        hours = int(minutes // 60)
        mins = int(minutes % 60)
        return f"{hours}h {mins}m"


def estimate_audio_output_size(duration_seconds: float, sample_rate: int, bit_depth: int,
                               channels: int = 2, output_format: str = 'flac',
                               compression_level: int = 8, codec: str = None) -> float:
    """
    Estima el tamaño del archivo de audio de salida en MB
    
    Args:
        duration_seconds: Duración del audio en segundos
        sample_rate: Sample rate de salida (Hz)
        bit_depth: Bit depth de salida (16 o 24)
        channels: Número de canales (default: 2 para estéreo)
        output_format: 'wav', 'flac', o 'wav_compressed'
        compression_level: Nivel de compresión (0-12 para FLAC, varía para WAV comprimido)
        codec: Codec para WAV comprimido (ej: 'adpcm_ms', 'gsm_ms')
    
    Returns:
        Tamaño estimado en MB
    """
    # Calcular tamaño base WAV sin comprimir (PCM)
    bytes_per_sample = bit_depth // 8
    wav_size_bytes = duration_seconds * sample_rate * bytes_per_sample * channels
    wav_size_mb = wav_size_bytes / (1024 * 1024)
    
    if output_format == 'wav':
        # WAV sin comprimir: tamaño completo
        return wav_size_mb
    elif output_format == 'wav_compressed':
        # WAV comprimido: aplicar ratio según codec
        compression_ratios = {
            'adpcm_ms': 0.25,      # ~25% del tamaño PCM
            'adpcm_ima_wav': 0.25,  # ~25% del tamaño PCM
            'gsm_ms': 0.20,         # ~20% del tamaño PCM
            'pcm_alaw': 0.50,        # ~50% del tamaño PCM
            'pcm_mulaw': 0.50,       # ~50% del tamaño PCM
        }
        ratio = compression_ratios.get(codec, 0.30)  # Default: 30% si codec desconocido
        return wav_size_mb * ratio
    elif output_format == 'flac':
        # FLAC: aplicar ratio según nivel de compresión
        if compression_level <= 2:
            ratio = 0.75  # ~70-80% del tamaño WAV
        elif compression_level <= 5:
            ratio = 0.65  # ~60-70% del tamaño WAV
        elif compression_level <= 8:
            ratio = 0.55  # ~50-60% del tamaño WAV
        else:  # 9-12
            ratio = 0.50  # ~45-55% del tamaño WAV
        return wav_size_mb * ratio
    else:
        # Default: retornar tamaño WAV
        return wav_size_mb


def estimate_mp3_output_size(duration_seconds: float, bitrate_kbps: int = 320) -> float:
    """
    Estima el tamaño del archivo MP3 de salida en MB
    
    Args:
        duration_seconds: Duración del audio en segundos
        bitrate_kbps: Bitrate en kbps (128, 192, 256, 320)
    
    Returns:
        Tamaño estimado en MB
    """
    # Tamaño MP3 = (bitrate en kbps * duración en segundos) / 8 / 1024
    # Dividir entre 8 para convertir bits a bytes, y entre 1024 para convertir KB a MB
    size_mb = (bitrate_kbps * duration_seconds) / (8 * 1024)
    return size_mb


def calculate_max_bitrate_for_size(duration_seconds: float, max_size_mb: float = 200.0) -> int:
    """
    Calcula el bitrate máximo en kbps para que el MP3 no supere el tamaño máximo
    
    Args:
        duration_seconds: Duración del audio en segundos
        max_size_mb: Tamaño máximo permitido en MB (default: 200MB para Ditto)
    
    Returns:
        Bitrate máximo en kbps (redondeado hacia abajo)
    """
    if duration_seconds <= 0:
        return 320  # Default si no se puede calcular
    
    # Despejar bitrate de la fórmula: size_mb = (bitrate * duration) / (8 * 1024)
    # bitrate = (size_mb * 8 * 1024) / duration
    max_bitrate = (max_size_mb * 8 * 1024) / duration_seconds
    
    # Redondear hacia abajo y limitar a valores estándar
    max_bitrate = int(max_bitrate)
    
    # Ajustar a bitrates estándar MP3 (128, 192, 256, 320)
    if max_bitrate >= 320:
        return 320
    elif max_bitrate >= 256:
        return 256
    elif max_bitrate >= 192:
        return 192
    elif max_bitrate >= 128:
        return 128
    else:
        return 128  # Mínimo recomendado


def estimate_432hz_conversion_time(duration_seconds: float, output_format: str = 'flac',
                                   compression_level: int = 8, bitrate_kbps: int = 320) -> float:
    """
    Estima el tiempo de conversión a 432Hz en minutos
    
    Args:
        duration_seconds: Duración del audio en segundos
        output_format: 'wav', 'flac', 'wav_compressed', o 'mp3'
        compression_level: Nivel de compresión (afecta tiempo de encoding para FLAC)
        bitrate_kbps: Bitrate en kbps para MP3 (afecta tiempo de encoding)
    
    Returns:
        Tiempo estimado en minutos
    """
    duration_minutes = duration_seconds / 60.0
    
    # Factor base para procesamiento (pitch shift + resampling)
    base_factor = 0.15  # ~15% de la duración del audio
    
    # Ajustar según formato de salida
    if output_format == 'wav':
        # WAV sin comprimir: más rápido (solo copia PCM)
        encoding_factor = 0.05
    elif output_format == 'wav_compressed':
        # WAV comprimido: compresión rápida
        encoding_factor = 0.10
    elif output_format == 'flac':
        # FLAC: tiempo depende del nivel de compresión
        if compression_level <= 2:
            encoding_factor = 0.10  # Compresión rápida
        elif compression_level <= 5:
            encoding_factor = 0.15  # Compresión media
        elif compression_level <= 8:
            encoding_factor = 0.20  # Compresión lenta
        else:  # 9-12
            encoding_factor = 0.30  # Compresión muy lenta
    elif output_format == 'mp3':
        # MP3: tiempo depende del bitrate (mayor bitrate = más tiempo)
        if bitrate_kbps <= 128:
            encoding_factor = 0.08  # Compresión rápida
        elif bitrate_kbps <= 192:
            encoding_factor = 0.10  # Compresión media
        elif bitrate_kbps <= 256:
            encoding_factor = 0.12  # Compresión lenta
        else:  # 320kbps
            encoding_factor = 0.15  # Compresión más lenta (máxima calidad)
    else:
        encoding_factor = 0.15
    
    total_factor = base_factor + encoding_factor
    return duration_minutes * total_factor


def select_audio_file_for_estimation(m4a_files: List[Path]) -> Optional[Path]:
    """
    Permite al usuario seleccionar un archivo de la lista para usar como referencia en las estimaciones.
    Retorna:
    - Path del archivo seleccionado si se selecciona un archivo específico
    - Path("__BATCH__") si se presiona Enter (batch mode)
    - None si se cancela (Ctrl+C)
    """
    """Permite al usuario seleccionar un archivo de la lista para usar como referencia en las estimaciones"""
    print_header("Selecciona Archivo para Estimación")
    print()
    print(f"    {Colors.LIME}📊 ¿Qué hace esta sección?{Colors.NC}")
    print(f"    {Colors.MEDIUM_GREEN}Esta sección te permite seleccionar un archivo de referencia para calcular{Colors.NC}")
    print(f"    {Colors.MEDIUM_GREEN}estimaciones precisas de tiempo y tamaño antes de convertir todos tus archivos.{Colors.NC}")
    print()
    print(f"    {Colors.LIME}🔢 Cálculos que se realizan:{Colors.NC}")
    print(f"    {Colors.MEDIUM_GREEN}• {Colors.LIGHT_GREEN}Tamaño estimado del video:{Colors.NC} Se calcula basado en:")
    print(f"      - Duración del audio (minutos)")
    print(f"      - Resolución seleccionada (480p, 720p, 1080p, 1440p, 4K)")
    print(f"      - Calidad de compresión (CRF)")
    print(f"      - Tamaño del archivo de audio original")
    print()
    print(f"    {Colors.MEDIUM_GREEN}• {Colors.LIGHT_GREEN}Tiempo estimado de conversión:{Colors.NC} Se calcula basado en:")
    print(f"      - Duración del audio")
    print(f"      - Preset de codificación (fast, medium, slow)")
    print(f"      - Resolución seleccionada")
    print(f"      - Complejidad del procesamiento de video")
    print()
    print(f"    {Colors.LIME}💡 Ejemplo práctico:{Colors.NC}")
    print(f"    {Colors.MEDIUM_GREEN}Si seleccionas un archivo de 30 minutos y eliges 1080p:{Colors.NC}")
    print(f"    {Colors.YELLOW_GREEN}→ Tamaño estimado:{Colors.NC} ~225MB (vs ~29MB del audio original)")
    print(f"    {Colors.YELLOW_GREEN}→ Tiempo estimado:{Colors.NC} ~24 minutos de procesamiento")
    print(f"    {Colors.MEDIUM_GREEN}Esto te ayuda a planificar el tiempo y espacio en disco necesarios.{Colors.NC}")
    print()
    print(f"    {Colors.LIME}📋 Selecciona un archivo de la lista:{Colors.NC}")
    print()
    print(f"    {Colors.YELLOW_GREEN}💡 O presiona Enter para ver el estimativo de todos los archivos{Colors.NC}")
    print(f"    {Colors.MEDIUM_GREEN}   Así puedes decidir si procedes a convertir uno por uno,{Colors.NC}")
    print(f"    {Colors.MEDIUM_GREEN}   o si mejor procesas todo el directorio de un intento.{Colors.NC}")
    print()
    
    # Mostrar lista numerada de archivos
    for i, audio_file in enumerate(m4a_files, 1):
        duration = get_audio_duration(audio_file)
        duration_str = format_duration(duration) if duration else "N/A"
        size_str = get_file_size(audio_file)
        print(f"  {Colors.LIME}{i}){Colors.NC} {Colors.LIGHT_GREEN}{audio_file.name}{Colors.NC}")
        print(f"      {Colors.MEDIUM_GREEN}Duración:{Colors.NC} {duration_str} | {Colors.MEDIUM_GREEN}Tamaño:{Colors.NC} {size_str}")
    
    print()
    
    # Solicitar selección
    while True:
        try:
            choice = input(f"{Colors.YELLOW_GREEN}▶ Selecciona archivo (1-{len(m4a_files)}) o Enter: {Colors.NC}").strip()
            
            # Si es Enter (vacío), retornar Path especial para indicar modo de estimación completa
            if not choice:
                print()
                print_success(f"Estimando el proceso de todos los archivos en un intento{Colors.NC}")
                print()
                return Path("__BATCH__")
            
            try:
                index = int(choice) - 1
                if 0 <= index < len(m4a_files):
                    selected_file = m4a_files[index]
                    print()
                    print_success(f"Archivo seleccionado: {Colors.LIGHT_GREEN}{selected_file.name}{Colors.NC}")
                    print()
                    return selected_file
                else:
                    print_error(f"Opción inválida. Selecciona un número del 1 al {len(m4a_files)}.")
            except ValueError:
                print_error(f"Por favor ingresa un número del 1 al {len(m4a_files)} o presiona Enter para batch.")
        except (EOFError, KeyboardInterrupt):
            return None


def show_batch_estimations(m4a_files: List[Path], resolution_profile: dict) -> None:
    """Muestra estimaciones individuales y totales para todos los archivos en modo batch"""
    print_header("Estimaciones por Archivo (Modo Batch)")
    print()
    
    total_duration_min = 0
    total_size_mb = 0
    total_time_min = 0
    
    # Calcular estimaciones para cada archivo
    file_estimations = []
    for audio_file in m4a_files:
        duration = get_audio_duration(audio_file)
        if duration:
            duration_min = duration / 60.0
            audio_size_mb = audio_file.stat().st_size / (1024 * 1024)
            est_size_mb = estimate_output_size(duration_min, resolution_profile, audio_size_mb)
            est_time_min = estimate_conversion_time(duration_min, resolution_profile)
            
            file_estimations.append({
                'file': audio_file,
                'duration': duration,
                'duration_min': duration_min,
                'audio_size_mb': audio_size_mb,
                'est_size_mb': est_size_mb,
                'est_time_min': est_time_min
            })
            
            total_duration_min += duration_min
            total_size_mb += est_size_mb
            total_time_min += est_time_min
    
    # Mostrar tabla de estimaciones individuales
    print(f"    {Colors.LIME}{'Archivo':<30} {'Duración':<12} {'Tamaño Audio':<15} {'Tamaño Video Est.':<18} {'Tiempo Est.':<15}{Colors.NC}")
    print(f"    {Colors.DARK_GREEN}{'-' * 90}{Colors.NC}")
    
    for est in file_estimations:
        duration_str = format_duration(est['duration'])
        audio_size_str = get_file_size(est['file'])
        
        if est['est_size_mb'] < 1024:
            video_size_str = f"{est['est_size_mb']:.1f}MB"
        else:
            video_size_str = f"{est['est_size_mb']/1024:.1f}GB"
        
        time_str = format_time_estimate(est['est_time_min'])
        
        file_name = est['file'].name[:28] + ".." if len(est['file'].name) > 30 else est['file'].name
        print(f"    {Colors.LIGHT_GREEN}{file_name:<30}{Colors.NC} {duration_str:<12} {audio_size_str:<15} {video_size_str:<18} {time_str:<15}")
    
    print()
    print(f"    {Colors.DARK_GREEN}{'-' * 90}{Colors.NC}")
    
    # Mostrar totales
    total_duration_str = format_time_estimate(total_duration_min)
    if total_size_mb < 1024:
        total_size_str = f"{total_size_mb:.1f}MB"
    else:
        total_size_str = f"{total_size_mb/1024:.1f}GB"
    total_time_str = format_time_estimate(total_time_min)
    
    print(f"    {Colors.LIME}{'TOTALES':<30} {total_duration_str:<12} {'':<15} {total_size_str:<18} {total_time_str:<15}{Colors.NC}")
    print()


def show_432hz_estimations(audio_files: List[Path], output_format: str, sample_rate: int,
                           bit_depth: int, compression_level: int = 8, codec: str = None) -> None:
    """
    Muestra estimaciones individuales y totales para conversión a 432Hz
    
    Args:
        audio_files: Lista de archivos de audio a convertir
        output_format: 'wav', 'flac', o 'wav_compressed'
        sample_rate: Sample rate de salida (Hz)
        bit_depth: Bit depth de salida (16 o 24)
        compression_level: Nivel de compresión (0-12)
        codec: Codec para WAV comprimido (opcional)
    """
    print_header("Estimaciones de Conversión a 432Hz")
    print()
    
    # Mostrar configuración seleccionada
    format_names = {
        'wav': 'WAV (PCM sin comprimir)',
        'wav_compressed': f'WAV Comprimido ({codec or "N/A"})',
        'flac': 'FLAC'
    }
    sr_display = "96kHz" if sample_rate == 96000 else ("48kHz" if sample_rate == 48000 else ("44.1kHz" if sample_rate == 44100 else f"{sample_rate}Hz"))
    
    print(f"    {Colors.LIME}Formato:{Colors.NC}        {Colors.LIGHT_GREEN}{format_names.get(output_format, output_format)}{Colors.NC}")
    print(f"    {Colors.LIME}Sample Rate:{Colors.NC}    {Colors.LIGHT_GREEN}{sr_display}{Colors.NC}")
    print(f"    {Colors.LIME}Bit Depth:{Colors.NC}      {Colors.LIGHT_GREEN}{bit_depth}-bit{Colors.NC}")
    if output_format in ['flac', 'wav_compressed']:
        print(f"    {Colors.LIME}Compresión:{Colors.NC}     {Colors.LIGHT_GREEN}Nivel {compression_level}{Colors.NC}")
    print()
    
    total_duration_min = 0
    total_original_size_mb = 0
    total_estimated_size_mb = 0
    total_time_min = 0
    
    # Calcular estimaciones para cada archivo
    file_estimations = []
    for audio_file in audio_files:
        duration = get_audio_duration(audio_file)
        if duration:
            duration_min = duration / 60.0
            original_size_mb = audio_file.stat().st_size / (1024 * 1024)
            
            # Estimar tamaño de salida
            est_size_mb = estimate_audio_output_size(
                duration, sample_rate, bit_depth, channels=2,
                output_format=output_format, compression_level=compression_level,
                codec=codec
            )
            
            # Estimar tiempo de conversión
            est_time_min = estimate_432hz_conversion_time(
                duration, output_format, compression_level
            )
            
            file_estimations.append({
                'file': audio_file,
                'duration': duration,
                'duration_min': duration_min,
                'original_size_mb': original_size_mb,
                'estimated_size_mb': est_size_mb,
                'estimated_time_min': est_time_min
            })
            
            total_duration_min += duration_min
            total_original_size_mb += original_size_mb
            total_estimated_size_mb += est_size_mb
            total_time_min += est_time_min
    
    # Mostrar tabla de estimaciones individuales
    print(f"    {Colors.LIME}{'Archivo':<30} {'Duración':<12} {'Tamaño Orig.':<15} {'Tamaño Est.':<18} {'Tiempo Est.':<15}{Colors.NC}")
    print(f"    {Colors.DARK_GREEN}{'-' * 90}{Colors.NC}")
    
    for est in file_estimations:
        duration_str = format_duration(est['duration'])
        original_size_str = get_file_size(est['file'])
        
        if est['estimated_size_mb'] < 1024:
            estimated_size_str = f"{est['estimated_size_mb']:.1f}MB"
        else:
            estimated_size_str = f"{est['estimated_size_mb']/1024:.1f}GB"
        
        time_str = format_time_estimate(est['estimated_time_min'])
        
        file_name = est['file'].name[:28] + ".." if len(est['file'].name) > 30 else est['file'].name
        print(f"    {Colors.LIGHT_GREEN}{file_name:<30}{Colors.NC} {duration_str:<12} {original_size_str:<15} {estimated_size_str:<18} {time_str:<15}")
    
    print()
    print(f"    {Colors.DARK_GREEN}{'-' * 90}{Colors.NC}")
    
    # Mostrar totales
    total_duration_str = format_time_estimate(total_duration_min)
    
    if total_original_size_mb < 1024:
        total_original_str = f"{total_original_size_mb:.1f}MB"
    else:
        total_original_str = f"{total_original_size_mb/1024:.1f}GB"
    
    if total_estimated_size_mb < 1024:
        total_estimated_str = f"{total_estimated_size_mb:.1f}MB"
    else:
        total_estimated_str = f"{total_estimated_size_mb/1024:.1f}GB"
    
    total_time_str = format_time_estimate(total_time_min)
    
    print(f"    {Colors.LIME}{'TOTALES':<30} {total_duration_str:<12} {total_original_str:<15} {total_estimated_str:<18} {total_time_str:<15}{Colors.NC}")
    print()


def select_resolution_profile(audio_file: Path, cover_image: Path, show_estimations: bool = True) -> Optional[dict]:
    """Muestra un menú para seleccionar la resolución"""
    duration = get_audio_duration(audio_file)
    if not duration:
        print_error("No se pudo determinar la duración del audio")
        return None
    
    duration_minutes = duration / 60.0
    audio_size_mb = audio_file.stat().st_size / (1024 * 1024)
    
    print_header("Selecciona Resolución de Video")
    
    if show_estimations:
        print(f"    {Colors.LIME}Archivo:{Colors.NC} {Colors.LIGHT_GREEN}{audio_file.name}{Colors.NC}")
        print(f"    {Colors.LIME}Duración:{Colors.NC} {Colors.LIGHT_GREEN}{format_duration(duration)}{Colors.NC}")
        print(f"    {Colors.LIME}Tamaño audio:{Colors.NC} {Colors.LIGHT_GREEN}{get_file_size(audio_file)}{Colors.NC}")
        print()
    
    # Mostrar opciones
    for key, profile in RESOLUTION_PROFILES.items():
        rec_mark = " ⭐" if "Recomendado" in profile["name"] else ""
        print(f"  {Colors.LIME}{key}){Colors.NC} {profile['name']}{rec_mark}")
        print(f"      {Colors.MEDIUM_GREEN}{profile['description']}{Colors.NC}")
        
        # Solo mostrar estimaciones si show_estimations es True
        if show_estimations:
            est_size_mb = estimate_output_size(duration_minutes, profile, audio_size_mb)
            est_time_min = estimate_conversion_time(duration_minutes, profile)
            
            if est_size_mb < 1024:
                size_str = f"{est_size_mb:.1f}MB"
            else:
                size_str = f"{est_size_mb/1024:.1f}GB"
            
            if est_time_min < 5:
                time_color = Colors.LIGHT_GREEN
            elif est_time_min < 15:
                time_color = Colors.YELLOW_GREEN
            else:
                time_color = Colors.DARK_GREEN
            
            print(f"      {Colors.MEDIUM_GREEN}📦 Tamaño estimado:{Colors.NC} {Colors.LIGHT_GREEN}{size_str}{Colors.NC}")
            print(f"      {Colors.MEDIUM_GREEN}⏱️  Tiempo estimado:{Colors.NC} {time_color}{format_time_estimate(est_time_min)}{Colors.NC}")
        
        print()
    
    # Solicitar selección
    while True:
        try:
            choice = input(f"{Colors.YELLOW_GREEN}▶ Selecciona resolución (1-6): {Colors.NC}").strip()
            if choice in RESOLUTION_PROFILES:
                selected = RESOLUTION_PROFILES[choice]
                
                if show_estimations:
                    # Mostrar resumen de la selección solo si estamos en modo individual
                    est_size_mb = estimate_output_size(duration_minutes, selected, audio_size_mb)
                    est_time_min = estimate_conversion_time(duration_minutes, selected)
                    
                    if est_size_mb < 1024:
                        size_str = f"{est_size_mb:.1f}MB"
                    else:
                        size_str = f"{est_size_mb/1024:.1f}GB"
                    
                    print()
                    print_info(f"Resolución seleccionada: {selected['name']}")
                    print(f"    {Colors.LIME}📦 Tamaño estimado:{Colors.NC} {Colors.LIGHT_GREEN}{size_str}{Colors.NC}")
                    print(f"    {Colors.LIME}⏱️  Tiempo estimado:{Colors.NC} {Colors.YELLOW_GREEN}{format_time_estimate(est_time_min)}{Colors.NC}")
                    print()
                else:
                    print()
                    print_info(f"Resolución seleccionada: {selected['name']}")
                    print()
                
                return selected
            else:
                print_error(f"Opción inválida. Selecciona un número del 1 al 6.")
        except (EOFError, KeyboardInterrupt):
            return None


def get_audio_info(file_path: Path) -> Dict:
    info = {'duration': None, 'sample_rate': None, 'bit_depth': None, 'codec': None, 'bitrate': None}
    try:
        info['duration'] = get_audio_duration(file_path)
        result = subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'a:0',
                                '-show_entries', 'stream=sample_rate,bits_per_sample,bits_per_raw_sample,codec_name,bit_rate',
                                '-of', 'json', str(file_path)],
                               capture_output=True, text=True)
        if result.returncode == 0:
            data = json.loads(result.stdout)
            stream = data.get('streams', [{}])[0]
            info['sample_rate'] = stream.get('sample_rate')
            info['bit_depth'] = stream.get('bits_per_sample') or stream.get('bits_per_raw_sample')
            info['codec'] = stream.get('codec_name')
            info['bitrate'] = stream.get('bit_rate')
    except Exception:
        pass
    return info


def get_effective_flac_bit_depth(requested_bit_depth: int) -> int:
    """
    FLAC en FFmpeg acepta sample_fmt s32 para el proceso, pero el archivo FLAC
    final queda efectivamente en 24-bit. Por eso normalizamos cualquier
    solicitud >16-bit a 24-bit para reporting/copia inteligente.
    """
    return 16 if requested_bit_depth == 16 else 24


def print_bit_depth_guide(sample_rate: int):
    """
    Muestra una guía práctica para elegir bit depth, con ejemplos concretos
    y cómo se relaciona con exportación a 192kHz.
    """
    print_header("Guía Rápida de Bit Depth")
    print()
    print(f"    {Colors.LIME}Concepto clave:{Colors.NC}")
    print(f"    {Colors.MEDIUM_GREEN}• Sample rate (Hz) = cuántas muestras por segundo.{Colors.NC}")
    print(f"    {Colors.MEDIUM_GREEN}• Bit depth = precisión de cada muestra (rango dinámico).{Colors.NC}")
    print()
    print(f"    {Colors.LIME}Diferencias principales:{Colors.NC}")
    print(f"    {Colors.LIGHT_GREEN}16-bit:{Colors.NC} ~96 dB de rango dinámico. Entrega final y máxima compatibilidad.")
    print(f"    {Colors.LIGHT_GREEN}24-bit:{Colors.NC} ~144 dB de rango dinámico. Estándar de producción/mastering.")
    print(f"    {Colors.LIGHT_GREEN}32-bit:{Colors.NC} mayor margen para procesamiento interno (headroom).")
    print()
    print(f"    {Colors.LIME}Ejemplo exportando a 192kHz (estéreo, 10s, sin compresión):{Colors.NC}")
    print(f"    {Colors.MEDIUM_GREEN}• 16-bit @ 192kHz: ~7.3 MB{Colors.NC}")
    print(f"    {Colors.MEDIUM_GREEN}• 24-bit @ 192kHz: ~11.0 MB{Colors.NC}")
    print(f"    {Colors.MEDIUM_GREEN}• 32-bit @ 192kHz: ~14.6 MB{Colors.NC}")
    print()
    print(f"    {Colors.LIME}Relación con 192kHz:{Colors.NC}")
    print(f"    {Colors.MEDIUM_GREEN}A 192kHz tienes 192000 muestras/segundo por canal.{Colors.NC}")
    print(f"    {Colors.MEDIUM_GREEN}El bit depth define cuánta resolución tiene cada una de esas muestras.{Colors.NC}")
    print()
    if sample_rate == 192000:
        print(f"    {Colors.YELLOW_GREEN}✔ Configuración actual: exportación a 192kHz.{Colors.NC}")
    else:
        print(f"    {Colors.YELLOW_GREEN}ℹ Configuración actual: {sample_rate}Hz. El ejemplo anterior usa 192kHz como referencia hi-res.{Colors.NC}")
    print(f"    {Colors.YELLOW_GREEN}⚠ En este flujo FFmpeg/FLAC termina en 24-bit efectivo aunque se solicite 32-bit.{Colors.NC}")
    print()

# ============================================================================
# ANIMACIONES
# ============================================================================

def equalizer_animation(frame: int) -> str:
    bars = 8
    heights = ['▁', '▃', '▅', '▆', '█']
    colors = [Colors.DARK_GREEN, Colors.MEDIUM_GREEN, Colors.LIGHT_GREEN, Colors.LIME]
    output = ""
    for i in range(bars):
        height_idx = (frame + i) % 5
        bar_char = heights[height_idx]
        color = colors[i % len(colors)]
        output += f"{color}{bar_char}{Colors.NC}"
    return output


def audio_wave_animation(frame: int) -> str:
    waves = []
    phases = [0, 1, 2, 3, 4, 3, 2, 1]
    heights = ['▁', '▂', '▄', '▆']
    colors = [Colors.DARK_GREEN, Colors.MEDIUM_GREEN, Colors.LIGHT_GREEN, Colors.LIME]
    for i in range(12):
        phase = phases[(frame + i) % len(phases)]
        waves.append(heights[phase])
    output = f"{Colors.LIME}🎧{Colors.NC} "
    for i, wave in enumerate(waves):
        color = colors[i % len(colors)]
        output += f"{color}{wave}{Colors.NC}"
    output += f" {Colors.LIME}🎧{Colors.NC}"
    return output


def animated_progress_bar(current: int, total: int, label: str, width: int = 35):
    percent = int(current * 100 / total)
    filled = int(current * width / total)
    empty = width - filled
    spinner = SPINNER_FRAMES[current % len(SPINNER_FRAMES)]
    note = MUSIC_NOTES[current % len(MUSIC_NOTES)]
    bar = f"{Colors.LIGHT_GREEN}{'█' * (filled - 1) if filled > 0 else ''}{Colors.NC}"
    if filled > 0:
        bar += f"{Colors.LIME}{note}{Colors.NC}"
    bar += f"{Colors.DARK_FOREST}{'░' * empty}{Colors.NC}"
    print(f"\r    {spinner} {Colors.DARK_FOREST}[{Colors.NC}{bar}{Colors.DARK_FOREST}]{Colors.NC} "
          f"{Colors.LIME}{percent:3d}%{Colors.NC} {Colors.MEDIUM_GREEN}{label}{Colors.NC} "
          f"{Colors.YELLOW_GREEN}({current}/{total}){Colors.NC}  ", end='', flush=True)


def animate_conversion(filename: str, stop_event: threading.Event, messages: List[str]):
    frame = 0
    while not stop_event.is_set():
        msg_idx = (frame // 8) % len(messages)
        eq_anim = equalizer_animation(frame)
        msg = messages[msg_idx]
        print(f"\r    {Colors.YELLOW_GREEN}🎧{Colors.NC} {eq_anim} {Colors.MEDIUM_GREEN}{msg}{Colors.NC}  ",
              end='', flush=True, file=sys.stderr)
        frame += 1
        time.sleep(0.1)

# ============================================================================
# MANEJO DE INTERRUPCIONES
# ============================================================================

def handle_interrupt(signum, frame):
    global INTERRUPTED
    INTERRUPTED = True
    print()
    print()
    print(f"{Colors.DARK_GREEN}╔════════════════════════════════════════════════════════════╗{Colors.NC}")
    print(f"{Colors.DARK_GREEN}║  {Colors.YELLOW_GREEN}⚠️  INTERRUPCIÓN DETECTADA (Ctrl+C){Colors.DARK_GREEN}                        ║{Colors.NC}")
    print(f"{Colors.DARK_GREEN}╚════════════════════════════════════════════════════════════╝{Colors.NC}")
    print()
    cleanup()
    print_warning("Operación cancelada por el usuario.")
    sys.exit(130)


def cleanup():
    for tmp_file in TMP_FILES[:]:
        try:
            if Path(tmp_file).exists():
                os.unlink(tmp_file)
                TMP_FILES.remove(tmp_file)
        except Exception:
            pass
    for tmp_dir in TMP_DIRS[:]:
        try:
            if Path(tmp_dir).exists() and Path(tmp_dir).is_dir():
                shutil.rmtree(tmp_dir)
                TMP_DIRS.remove(tmp_dir)
        except Exception:
            pass


signal.signal(signal.SIGINT, handle_interrupt)
signal.signal(signal.SIGTERM, handle_interrupt)
atexit.register(cleanup)

# ============================================================================
# FUNCIONES DE CONVERSIÓN
# ============================================================================

def convert_m4a_to_mp4(audio_file: Path, output_dir: Path, cover_image: Path,
                       crf: int = VIDEO_CRF, preset: str = VIDEO_PRESET,
                       resolution: str = VIDEO_RESOLUTION) -> bool:
    output_file = output_dir / f"{audio_file.stem}.mp4"
    duration = get_audio_duration(audio_file)
    if not duration:
        print_error(f"No se pudo determinar la duración de: {audio_file.name}")
        return False
    info = get_audio_info(audio_file)
    audio_codec = info.get('codec', 'aac')
    if audio_codec == 'aac':
        audio_args = ['-c:a', 'copy']
    else:
        audio_args = ['-c:a', 'aac', '-b:a', '192k', '-ar', '48000']
    duration_fmt = format_duration(duration)
    print(f"    {Colors.LIME}Duración:{Colors.NC} {Colors.LIGHT_GREEN}{duration_fmt}{Colors.NC} | "
          f"{Colors.LIME}Codec:{Colors.NC} {Colors.LIGHT_GREEN}{audio_codec}{Colors.NC}")
    
    # Iniciar animación de conversión
    stop_event = threading.Event()
    messages = ["Creando video...", "Codificando H.264...", "Aplicando imagen...", "Finalizando..."]
    anim_thread = threading.Thread(target=animate_conversion, args=(audio_file.name, stop_event, messages), daemon=True)
    anim_thread.start()
    
    cmd = ['ffmpeg', '-hide_banner', '-loglevel', 'warning', '-stats',
           '-loop', '1', '-framerate', '30', '-i', str(cover_image),
           '-i', str(audio_file), '-map', '0:v:0', '-map', '1:a:0',
           '-t', str(duration), '-shortest',
           '-c:v', 'libx264', '-preset', preset, '-crf', str(crf), '-pix_fmt', 'yuv420p',
           *audio_args,
           '-vf', f'scale={resolution}:force_original_aspect_ratio=decrease,pad={resolution}:(ow-iw)/2:(oh-ih)/2',
           '-movflags', '+faststart', '-metadata', f'title={audio_file.stem}',
           '-y', str(output_file)]
    try:
        result = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        
        # Detener animación
        stop_event.set()
        anim_thread.join(timeout=0.5)
        print("\r\033[K", end='', flush=True, file=sys.stderr)
        
        if result.returncode == 0 and output_file.exists():
            return True
        else:
            if result.stderr:
                print(result.stderr, file=sys.stderr)
            return False
    except Exception as e:
        stop_event.set()
        anim_thread.join(timeout=0.5)
        print_error(f"Error: {e}")
        return False


def convert_to_m4a(audio_file: Path, output_dir: Path, quality_mode: str = QUALITY_MODE,
                   vbr_quality: int = VBR_QUALITY, cbr_bitrate: str = CBR_BITRATE) -> bool:
    output_file = output_dir / f"{audio_file.stem}.m4a"
    if quality_mode == "vbr":
        quality_args = ['-c:a', 'aac', '-q:a', str(vbr_quality), '-ar', '48000']
    else:
        quality_args = ['-c:a', 'aac', '-b:a', cbr_bitrate, '-ar', '48000']
    stop_event = threading.Event()
    messages = ["Codificando AAC...", "Comprimiendo audio...", "Optimizando M4A...", "Casi listo..."]
    anim_thread = threading.Thread(target=animate_conversion, args=(audio_file.name, stop_event, messages), daemon=True)
    anim_thread.start()
    try:
        cmd = ['ffmpeg', '-hide_banner', '-loglevel', 'warning', '-stats',
               '-i', str(audio_file), *quality_args, '-movflags', '+faststart', '-y', str(output_file)]
        result = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        stop_event.set()
        anim_thread.join(timeout=0.5)
        print("\r\033[K", end='', flush=True, file=sys.stderr)
        if result.returncode == 0 and output_file.exists():
            return True
        else:
            if result.stderr:
                print(result.stderr, file=sys.stderr)
            return False
    except Exception as e:
        stop_event.set()
        anim_thread.join(timeout=0.5)
        print(f"\nError: {e}", file=sys.stderr)
        return False


def convert_to_flac(audio_file: Path, output_dir: Path, sample_rate: int = FLAC_SAMPLE_RATE,
                    bit_depth: int = FLAC_BIT_DEPTH, compression: int = FLAC_COMPRESSION) -> bool:
    output_file = output_dir / f"{audio_file.stem}.flac"
    info = get_audio_info(audio_file)
    input_codec = info.get('codec', '')
    input_sr = info.get('sample_rate')
    input_bd = info.get('bit_depth')
    effective_target_bd = get_effective_flac_bit_depth(bit_depth)
    if input_codec == 'flac' and input_sr and str(input_sr) == str(sample_rate):
        input_bd_norm = get_effective_flac_bit_depth(input_bd or effective_target_bd)
        if input_bd_norm == effective_target_bd:
            try:
                shutil.copy2(audio_file, output_file)
                if output_file.exists():
                    orig_size = get_file_size(audio_file)
                    out_size = get_file_size(output_file)
                    print_success(f"Copiado (sin re-codificación): {output_file.name}")
                    print(f"    {Colors.DARK_FOREST}{orig_size} → {out_size} | {input_sr}Hz/{input_bd_norm}bit FLAC{Colors.NC}")
                    return True
            except Exception:
                pass
    sample_fmt = "s16" if bit_depth == 16 else "s32"
    stop_event = threading.Event()
    messages = ["Procesando audio...", "Codificando FLAC...", "Aplicando compresión...", "Finalizando..."]
    anim_thread = threading.Thread(target=animate_conversion, args=(audio_file.name, stop_event, messages), daemon=True)
    anim_thread.start()
    try:
        cmd = ['ffmpeg', '-hide_banner', '-loglevel', 'warning', '-stats',
               '-i', str(audio_file), '-c:a', 'flac', '-ar', str(sample_rate),
               '-sample_fmt', sample_fmt, '-compression_level', str(compression),
               '-y', str(output_file)]
        result = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        stop_event.set()
        anim_thread.join(timeout=0.5)
        print("\r\033[K", end='', flush=True, file=sys.stderr)
        if result.returncode == 0 and output_file.exists():
            orig_size = get_file_size(audio_file)
            out_size = get_file_size(output_file)
            output_info = get_audio_info(output_file)
            actual_sr = output_info.get('sample_rate') or sample_rate
            actual_bd = output_info.get('bit_depth') or effective_target_bd
            print_success(f"Creado: {output_file.name}")
            print(f"    {Colors.DARK_FOREST}{orig_size} → {out_size} | {actual_sr}Hz/{actual_bd}bit FLAC{Colors.NC}")
            if bit_depth == 32 and actual_bd != 32:
                print_warning("32-bit solicitado, pero FFmpeg/FLAC generó FLAC efectivo a 24-bit.")
                print_info("Si necesitas 32-bit real, conviene exportar a WAV o AIFF.")
            return True
        else:
            if result.stderr:
                print(result.stderr, file=sys.stderr)
            return False
    except Exception as e:
        stop_event.set()
        anim_thread.join(timeout=0.5)
        print(f"\nError: {e}", file=sys.stderr)
        return False


def convert_to_432hz(input_file: Path, output_file: Path, output_sample_rate: int = 96000,
                     output_format: str = 'flac', compression_level: int = 8, codec: str = None) -> bool:
    """
    Convierte audio a frecuencia 432Hz
    
    Args:
        input_file: Archivo de entrada
        output_file: Archivo de salida (debe tener extensión correcta: .wav o .flac)
        output_sample_rate: Sample rate de salida (Hz)
        output_format: 'wav', 'flac', o 'wav_compressed'
        compression_level: Nivel de compresión (0-12 para FLAC)
        codec: Codec para WAV comprimido (ej: 'adpcm_ms', 'gsm_ms')
    """
    if not input_file.exists():
        print_error(f"El archivo no existe: {input_file}")
        return False
    info = get_audio_info(input_file)
    input_sample_rate = info.get('sample_rate')
    bit_depth = info.get('bit_depth', 24)
    if not input_sample_rate:
        print_error("No se pudo detectar el sample rate del archivo")
        return False
    input_sample_rate = int(input_sample_rate)
    
    # Determinar formato de muestra según bit depth
    if output_format == 'wav':
        # WAV sin comprimir: usar PCM
        if bit_depth == 16:
            sample_fmt = "s16"
            audio_codec = "pcm_s16le"
        else:  # 24-bit
            sample_fmt = "s32"
            audio_codec = "pcm_s24le"
    elif output_format == 'wav_compressed':
        # WAV comprimido: usar codec especificado
        audio_codec = codec or "adpcm_ms"
        sample_fmt = "s16"  # La mayoría de codecs comprimidos usan 16-bit
    else:  # flac
        sample_fmt = "s16" if bit_depth == 16 else "s32"
        audio_codec = "flac"
    
    print(f"    {Colors.MEDIUM_GREEN}🎵 Conversión a frecuencia universal 432Hz{Colors.NC}")
    print(f"    {Colors.DARK_FOREST}Input: {input_sample_rate}Hz/{bit_depth}-bit → Output: {output_sample_rate}Hz/{bit_depth}-bit{Colors.NC}")
    print(f"    {Colors.DARK_FOREST}Procesando: 440Hz → 432Hz (manteniendo duración){Colors.NC}")
    print(f"    {Colors.DARK_FOREST}Formato: {output_format.upper()}{Colors.NC}")
    
    stop_event = threading.Event()
    messages = ["Ajustando frecuencia...", "Aplicando pitch shift...", "Re-muestreando audio...", "Casi listo..."]
    anim_thread = threading.Thread(target=animate_conversion, args=(input_file.name, stop_event, messages), daemon=True)
    anim_thread.start()
    
    try:
        # Construir comando base
        cmd = ['ffmpeg', '-hide_banner', '-loglevel', 'warning', '-stats',
               '-i', str(input_file),
               '-af', f'asetrate={input_sample_rate}*432/440,aresample={output_sample_rate},atempo=440/432',
               '-c:a', audio_codec,
               '-ar', str(output_sample_rate),
               '-y', str(output_file)]
        
        # Agregar parámetros específicos según formato
        if output_format == 'wav':
            # WAV sin comprimir: agregar formato de muestra
            cmd.extend(['-sample_fmt', sample_fmt])
        elif output_format == 'wav_compressed':
            # WAV comprimido: algunos codecs pueden necesitar parámetros adicionales
            # La mayoría funcionan con solo el codec
            pass
        elif output_format == 'flac':
            # FLAC: agregar formato de muestra y nivel de compresión
            cmd.extend(['-sample_fmt', sample_fmt])
            cmd.extend(['-compression_level', str(compression_level)])
        
        result = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        stop_event.set()
        anim_thread.join(timeout=0.5)
        print("\r\033[K", end='', flush=True, file=sys.stderr)
        
        if result.returncode == 0 and output_file.exists():
            orig_size = get_file_size(input_file)
            new_size = get_file_size(output_file)
            print_success(f"Conversión a 432Hz completada: {output_file.name}")
            print(f"    {Colors.DARK_FOREST}Tamaño: {orig_size} → {new_size} | {output_sample_rate}Hz/{bit_depth}-bit{Colors.NC}")
            return True
        else:
            if result.stderr:
                print(result.stderr, file=sys.stderr)
            return False
    except Exception as e:
        stop_event.set()
        anim_thread.join(timeout=0.5)
        print(f"\nError: {e}", file=sys.stderr)
        return False


def convert_to_432hz_mp3(input_file: Path, output_file: Path, output_sample_rate: int = 48000,
                         bitrate_kbps: int = 320, vbr_quality: int = None) -> bool:
    """
    Convierte audio a frecuencia 432Hz y exporta a MP3
    
    Args:
        input_file: Archivo de entrada
        output_file: Archivo de salida (debe tener extensión .mp3)
        output_sample_rate: Sample rate deseado (Hz) - será limitado a 48kHz máximo para MP3
        bitrate_kbps: Bitrate en kbps (128, 192, 256, 320) - solo si vbr_quality es None
        vbr_quality: Calidad VBR (0-9, donde 0 es mejor) - si se especifica, usa VBR en lugar de CBR
    """
    if not input_file.exists():
        print_error(f"El archivo no existe: {input_file}")
        return False
    info = get_audio_info(input_file)
    input_sample_rate = info.get('sample_rate')
    bit_depth = info.get('bit_depth', 24)
    if not input_sample_rate:
        print_error("No se pudo detectar el sample rate del archivo")
        return False
    input_sample_rate = int(input_sample_rate)
    
    # libmp3lame solo soporta hasta 48kHz - limitar sample rate
    # Sample rates soportados: 8000, 11025, 12000, 16000, 22050, 24000, 32000, 44100, 48000
    mp3_max_sample_rate = 48000
    processing_sample_rate = output_sample_rate  # Para procesamiento interno (pitch shift)
    mp3_sample_rate = min(output_sample_rate, mp3_max_sample_rate)  # Para encoding MP3
    
    print(f"    {Colors.MEDIUM_GREEN}🎵 Conversión a frecuencia universal 432Hz → MP3{Colors.NC}")
    print(f"    {Colors.DARK_FOREST}Input: {input_sample_rate}Hz/{bit_depth}-bit → Output: {mp3_sample_rate}Hz/MP3{Colors.NC}")
    if output_sample_rate > mp3_max_sample_rate:
        print(f"    {Colors.YELLOW_GREEN}ℹ️  Procesamiento interno a {output_sample_rate}Hz, luego resample a {mp3_sample_rate}Hz para MP3{Colors.NC}")
    print(f"    {Colors.DARK_FOREST}Procesando: 440Hz → 432Hz (manteniendo duración){Colors.NC}")
    if vbr_quality is not None:
        print(f"    {Colors.DARK_FOREST}Modo: VBR Quality {vbr_quality} (0=máxima calidad){Colors.NC}")
    else:
        print(f"    {Colors.DARK_FOREST}Modo: CBR {bitrate_kbps}kbps{Colors.NC}")
    
    # Nota sobre limitación de MP3
    if output_sample_rate > mp3_max_sample_rate:
        print()
        print_info(f"ℹ️  Nota: MP3 (libmp3lame) soporta máximo 48kHz")
        print_info(f"   El audio se procesa a {output_sample_rate}Hz internamente, luego se resamplea a {mp3_sample_rate}Hz para el MP3 final")
        print()
    
    stop_event = threading.Event()
    messages = ["Ajustando frecuencia...", "Aplicando pitch shift...", "Re-muestreando audio...", "Codificando MP3...", "Casi listo..."]
    anim_thread = threading.Thread(target=animate_conversion, args=(input_file.name, stop_event, messages), daemon=True)
    anim_thread.start()
    
    try:
        # Construir comando base
        # Procesar a sample rate deseado internamente, luego resamplear a 48kHz para MP3
        if output_sample_rate > mp3_max_sample_rate:
            # Procesar a alta resolución primero, luego resamplear a 48kHz para MP3
            cmd = ['ffmpeg', '-hide_banner', '-loglevel', 'warning', '-stats',
                   '-i', str(input_file),
                   '-af', f'asetrate={input_sample_rate}*432/440,aresample={output_sample_rate},atempo=440/432,aresample={mp3_sample_rate}',
                   '-c:a', 'libmp3lame',
                   '-ar', str(mp3_sample_rate),
                   '-y', str(output_file)]
        else:
            # Sample rate está dentro del rango soportado
            cmd = ['ffmpeg', '-hide_banner', '-loglevel', 'warning', '-stats',
                   '-i', str(input_file),
                   '-af', f'asetrate={input_sample_rate}*432/440,aresample={mp3_sample_rate},atempo=440/432',
                   '-c:a', 'libmp3lame',
                   '-ar', str(mp3_sample_rate),
                   '-y', str(output_file)]
        
        # Agregar parámetros de bitrate o VBR
        if vbr_quality is not None:
            # Modo VBR
            cmd.extend(['-q:a', str(vbr_quality)])
        else:
            # Modo CBR
            cmd.extend(['-b:a', f'{bitrate_kbps}k'])
        
        # Agregar metadatos ID3 para compatibilidad con Ditto Music y reconocimiento de MIME type
        # ID3v2.3 es el estándar más compatible
        cmd.extend(['-id3v2_version', '3'])
        cmd.extend(['-write_id3v1', '1'])
        
        # Agregar metadatos básicos del archivo original
        input_name = input_file.stem
        cmd.extend(['-metadata', f'title={input_name}'])
        
        # Asegurar formato MP3 estándar
        cmd.extend(['-f', 'mp3'])
        
        result = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        stop_event.set()
        anim_thread.join(timeout=0.5)
        print("\r\033[K", end='', flush=True, file=sys.stderr)
        
        if result.returncode == 0 and output_file.exists():
            orig_size = get_file_size(input_file)
            new_size = get_file_size(output_file)
            print_success(f"Conversión a 432Hz MP3 completada: {output_file.name}")
            print(f"    {Colors.DARK_FOREST}Tamaño: {orig_size} → {new_size} | {mp3_sample_rate}Hz/MP3{Colors.NC}")
            return True
        else:
            if result.stderr:
                print(result.stderr, file=sys.stderr)
            return False
    except Exception as e:
        stop_event.set()
        anim_thread.join(timeout=0.5)
        print(f"\nError: {e}", file=sys.stderr)
        return False

# ============================================================================
# FUNCIONES DE PROCESAMIENTO
# ============================================================================

def process_m4a_to_mp4(source_dir: Path, output_dirname: str = "converted_videos"):
    output_dir = source_dir / output_dirname
    output_dir.mkdir(exist_ok=True)
    m4a_files = sorted(source_dir.glob("*.m4a")) + sorted(source_dir.glob("*.M4A"))
    if not m4a_files:
        print_error("No se encontraron archivos .m4a en esta carpeta.")
        return False
    print_header(f"Archivos M4A encontrados: {len(m4a_files)}")
    for f in m4a_files:
        print(f"    📄 {f.name}")
    print()
    cover_image = None
    for img_name in ['cover.png', 'cover.jpg', 'Cover.png', 'Cover.jpg', 'artwork.png', 'artwork.jpg']:
        img_path = source_dir / img_name
        if img_path.exists():
            cover_image = img_path
            break
    if not cover_image:
        print_error("No se encontró imagen de portada (cover.png, cover.jpg, etc.)")
        print("    Coloca una imagen llamada 'cover.png' en la carpeta.")
        return False
    print_info(f"Usando portada: {cover_image.name}")
    print()
    
    # Permitir al usuario seleccionar un archivo para las estimaciones o batch mode
    reference_file = select_audio_file_for_estimation(m4a_files)
    if reference_file is None:  # None significa que se canceló
        print_warning("Conversión cancelada.")
        return False
    
    # Verificar si es batch mode (Path especial "__BATCH__")
    is_batch_mode = (reference_file.name == "__BATCH__")
    
    if is_batch_mode:
        # Modo batch: seleccionar resolución sin mostrar cálculos (se mostrarán en la tabla)
        reference_file = m4a_files[0]
        resolution_profile = select_resolution_profile(reference_file, cover_image, show_estimations=False)
        if not resolution_profile:
            print_warning("Conversión cancelada.")
            return False
        
        # Mostrar estimaciones detalladas en tabla
        show_batch_estimations(m4a_files, resolution_profile)
    else:
        # Modo individual: seleccionar resolución con estimaciones
        resolution_profile = select_resolution_profile(reference_file, cover_image, show_estimations=True)
        if not resolution_profile:
            print_warning("Conversión cancelada.")
            return False
        
        # Mostrar estimación total aproximada
        total_duration = 0
        total_audio_size = 0
        for audio_file in m4a_files:
            duration = get_audio_duration(audio_file)
            if duration:
                total_duration += duration / 60.0
                total_audio_size += audio_file.stat().st_size / (1024 * 1024)
        
        if total_duration > 0:
            total_est_size = estimate_output_size(total_duration, resolution_profile, total_audio_size / len(m4a_files))
            total_est_time = estimate_conversion_time(total_duration, resolution_profile)
            
            if total_est_size < 1024:
                total_size_str = f"{total_est_size:.1f}MB"
            else:
                total_size_str = f"{total_est_size/1024:.1f}GB"
            
            print_header("Estimación Total")
            print(f"    {Colors.LIME}Archivos:{Colors.NC} {Colors.LIGHT_GREEN}{len(m4a_files)}{Colors.NC}")
            print(f"    {Colors.LIME}📦 Tamaño total estimado:{Colors.NC} {Colors.LIGHT_GREEN}{total_size_str}{Colors.NC}")
            print(f"    {Colors.LIME}⏱️  Tiempo total estimado:{Colors.NC} {Colors.YELLOW_GREEN}{format_time_estimate(total_est_time)}{Colors.NC}")
            print()
    
    if not confirm(f"¿Convertir {len(m4a_files)} archivos a MP4 con estas configuraciones?"):
        print_warning("Conversión cancelada.")
        return False
    
    print_header("Iniciando conversión M4A → MP4")
    print(f"    {Colors.MEDIUM_GREEN}💡 Presiona Ctrl+C en cualquier momento para cancelar{Colors.NC}")
    print()
    success_count = 0
    fail_count = 0
    for i, audio_file in enumerate(m4a_files, 1):
        if INTERRUPTED:
            print_warning("Conversión interrumpida por el usuario")
            break
        animated_progress_bar(i, len(m4a_files), f"Convirtiendo: {audio_file.name[:25]}")
        if convert_m4a_to_mp4(audio_file, output_dir, cover_image,
                              crf=resolution_profile["crf"],
                              preset=resolution_profile["preset"],
                              resolution=resolution_profile["resolution"]):
            success_count += 1
            orig_size = get_file_size(audio_file)
            out_size = get_file_size(output_dir / f"{audio_file.stem}.mp4")
            print(f"\n    {Colors.LIGHT_GREEN}✓{Colors.NC} {audio_file.name} → {out_size} ({orig_size})")
        else:
            fail_count += 1
            print(f"\n    {Colors.DARK_GREEN}✗{Colors.NC} {audio_file.name} → Error")
    print()
    print_header("Conversión MP4 Completada")
    print(f"    {Colors.LIGHT_GREEN}Exitosos:{Colors.NC} {Colors.LIME}{success_count}{Colors.NC}")
    if fail_count > 0:
        print(f"    {Colors.DARK_GREEN}Fallidos:{Colors.NC} {Colors.YELLOW_GREEN}{fail_count}{Colors.NC}")
    print(f"    {Colors.LIME}Salida:{Colors.NC}   {Colors.LIGHT_GREEN}{output_dir}/{Colors.NC}")
    return success_count > 0


def process_audio_to_m4a(source_dir: Path, output_dirname: str = "converted",
                         quality_mode: str = QUALITY_MODE, vbr_quality: int = VBR_QUALITY,
                         cbr_bitrate: str = CBR_BITRATE):
    output_dir = source_dir / output_dirname
    output_dir.mkdir(exist_ok=True)
    audio_files = select_audio_source_files(source_dir)
    if audio_files is None:
        print_warning("Conversión cancelada.")
        return False
    if not audio_files:
        print_error("No se encontraron archivos WAV/AIFF/FLAC para convertir.")
        return False
    print_header(f"Archivos {AUDIO_SOURCE_FORMATS_LABEL} encontrados: {len(audio_files)}")
    for f in audio_files:
        print(f"    📄 {f.name}")
    print()
    print_info(f"Modo: {quality_mode}")
    if quality_mode == "vbr":
        print(f"    VBR Quality: {vbr_quality} (0=máxima)")
    else:
        print(f"    CBR Bitrate: {cbr_bitrate}")
    if not confirm(f"¿Convertir {len(audio_files)} archivos a M4A?"):
        print_warning("Conversión cancelada.")
        return False
    print_header("Iniciando conversión AUDIO (WAV/AIFF/FLAC) → M4A")
    print(f"    {Colors.MEDIUM_GREEN}💡 Presiona Ctrl+C en cualquier momento para cancelar{Colors.NC}")
    success_count = 0
    fail_count = 0
    for i, audio_file in enumerate(audio_files, 1):
        if INTERRUPTED:
            print_warning("Conversión interrumpida por el usuario")
            break
        animated_progress_bar(i, len(audio_files), f"Convirtiendo: {audio_file.name[:25]}")
        if convert_to_m4a(audio_file, output_dir, quality_mode, vbr_quality, cbr_bitrate):
            success_count += 1
            orig_size = get_file_size(audio_file)
            out_size = get_file_size(output_dir / f"{audio_file.stem}.m4a")
            print(f"\n    {Colors.LIGHT_GREEN}✓{Colors.NC} {audio_file.name} → {out_size} ({orig_size})")
        else:
            fail_count += 1
            print(f"\n    {Colors.DARK_GREEN}✗{Colors.NC} {audio_file.name} → Error")
    print()
    print_header("Conversión M4A Completada")
    print(f"    {Colors.LIGHT_GREEN}Exitosos:{Colors.NC} {Colors.LIME}{success_count}{Colors.NC}")
    if fail_count > 0:
        print(f"    {Colors.DARK_GREEN}Fallidos:{Colors.NC} {Colors.YELLOW_GREEN}{fail_count}{Colors.NC}")
    print(f"    {Colors.LIME}Salida:{Colors.NC}   {Colors.LIGHT_GREEN}{output_dir}/{Colors.NC}")
    return success_count > 0


def process_album_to_unified_mp3(source_dir: Path, output_dirname: str = "unified",
                                 silence_duration: int = SILENCE_DURATION,
                                 mp3_bitrate: str = MP3_BITRATE, album_name: str = ALBUM_NAME):
    output_dir = source_dir / output_dirname
    output_dir.mkdir(exist_ok=True)
    audio_files = select_audio_source_files(source_dir)
    if audio_files is None:
        print_warning("Operación cancelada.")
        return False
    if not audio_files:
        print_error("No se encontraron archivos WAV/AIFF/FLAC en la fuente seleccionada.")
        return False
    if len(audio_files) < 2:
        print_warning("Solo se encontró 1 archivo. Este modo está diseñado para álbumes con múltiples pistas.")
    print_header(f"Archivos de audio encontrados: {len(audio_files)}")
    total_duration = 0.0
    for i, f in enumerate(audio_files, 1):
        dur = get_audio_duration(f) or 0.0
        dur_fmt = format_duration(dur)
        total_duration += dur
        print(f"    {Colors.LIME}{i}.{Colors.NC} {Colors.LIGHT_GREEN}{f.name}{Colors.NC} {Colors.MEDIUM_GREEN}({dur_fmt}){Colors.NC}")
    total_silence = silence_duration * (len(audio_files) - 1)
    final_duration = total_duration + total_silence
    total_fmt = format_duration(final_duration)
    print()
    print_info("Configuración:")
    print(f"    {Colors.LIME}Pistas:{Colors.NC}              {Colors.LIGHT_GREEN}{len(audio_files)}{Colors.NC}")
    print(f"    {Colors.LIME}Silencio entre pistas:{Colors.NC} {Colors.LIGHT_GREEN}{silence_duration} segundos{Colors.NC}")
    print(f"    {Colors.LIME}Duración total estimada:{Colors.NC} {Colors.LIGHT_GREEN}{total_fmt}{Colors.NC}")
    print(f"    {Colors.LIME}Bitrate MP3:{Colors.NC}         {Colors.LIGHT_GREEN}{mp3_bitrate}{Colors.NC}")
    output_name = album_name if album_name else f"{source_dir.name.replace(' ', '_')}_completo"
    output_file = output_dir / f"{output_name}.mp3"
    print(f"    {Colors.LIME}Archivo de salida:{Colors.NC}   {Colors.LIGHT_GREEN}{output_file.name}{Colors.NC}")
    print()
    if not confirm(f"¿Crear MP3 unificado con {len(audio_files)} pistas?"):
        print_warning("Operación cancelada.")
        return False
    print_header("Creando MP3 unificado para registro de derechos de autor")
    print(f"    {Colors.MEDIUM_GREEN}💡 Presiona Ctrl+C en cualquier momento para cancelar{Colors.NC}")
    print()
    tmp_dir = tempfile.mkdtemp(prefix='album_concat_')
    TMP_DIRS.append(tmp_dir)
    print_info(f"Generando silencio de {silence_duration} segundos...")
    silence_file = Path(tmp_dir) / "silence.wav"
    cmd = ['ffmpeg', '-hide_banner', '-loglevel', 'error',
           '-f', 'lavfi', '-i', f'anullsrc=r=48000:cl=stereo',
           '-t', str(silence_duration), '-y', str(silence_file)]
    subprocess.run(cmd, capture_output=True)
    if not silence_file.exists():
        print_error("No se pudo crear el archivo de silencio")
        cleanup()
        return False
    if INTERRUPTED:
        cleanup()
        return False
    concat_list = Path(tmp_dir) / "concat_list.txt"
    print()
    print(f"    {Colors.LIME}╔════════════════════════════════════════════════════════════╗{Colors.NC}")
    print(f"    {Colors.LIME}║{Colors.NC}  {Colors.YELLOW_GREEN}🎵 PREPARANDO PISTAS PARA EL ÁLBUM UNIFICADO 🎵{Colors.NC}          {Colors.LIME}║{Colors.NC}")
    print(f"    {Colors.LIME}╚════════════════════════════════════════════════════════════╝{Colors.NC}")
    print()
    for i, audio_file in enumerate(audio_files, 1):
        if INTERRUPTED:
            print_warning("Proceso interrumpido durante la preparación de pistas")
            cleanup()
            return False
        filename_short = audio_file.name[:25] + "..." if len(audio_file.name) > 25 else audio_file.name
        animated_progress_bar(i, len(audio_files), filename_short)
        tmp_wav = Path(tmp_dir) / f"track_{i:03d}.wav"
        cmd = ['ffmpeg', '-hide_banner', '-loglevel', 'error',
               '-i', str(audio_file), '-ar', '48000', '-ac', '2', '-y', str(tmp_wav)]
        result = subprocess.run(cmd, capture_output=True)
        if not tmp_wav.exists():
            print()
            print_error(f"Error al procesar: {audio_file.name}")
            cleanup()
            return False
        with open(concat_list, 'a') as f:
            f.write(f"file '{tmp_wav}'\n")
        if i < len(audio_files):
            with open(concat_list, 'a') as f:
                f.write(f"file '{silence_file}'\n")
    print()
    print()
    print_success(f"✅ {len(audio_files)} pistas preparadas correctamente")
    if INTERRUPTED:
        cleanup()
        return False
    print()
    print(f"    {Colors.LIME}╔════════════════════════════════════════════════════════════╗{Colors.NC}")
    print(f"    {Colors.LIME}║{Colors.NC}  {Colors.YELLOW_GREEN}🎼 CONCATENANDO {len(audio_files)} PISTAS EN UN SOLO ARCHIVO 🎼{Colors.NC}     {Colors.LIME}║{Colors.NC}")
    print(f"    {Colors.LIME}╚════════════════════════════════════════════════════════════╝{Colors.NC}")
    print()
    tmp_concat = Path(tmp_dir) / "concatenated.wav"
    stop_event = threading.Event()
    messages = ["Uniendo pistas..."]
    anim_thread = threading.Thread(target=lambda: animate_conversion("", stop_event, messages), daemon=True)
    anim_thread.start()
    cmd = ['ffmpeg', '-hide_banner', '-loglevel', 'error',
           '-f', 'concat', '-safe', '0', '-i', str(concat_list),
           '-c', 'copy', '-y', str(tmp_concat)]
    result = subprocess.run(cmd, capture_output=True)
    stop_event.set()
    anim_thread.join(timeout=0.5)
    print("\r\033[K", end='', flush=True, file=sys.stderr)
    if result.returncode != 0 or not tmp_concat.exists():
        print()
        print_error("Error al concatenar archivos")
        cleanup()
        return False
    print()
    print_success("✅ Pistas concatenadas exitosamente")
    if INTERRUPTED:
        cleanup()
        return False
    print()
    print(f"    {Colors.LIME}╔════════════════════════════════════════════════════════════╗{Colors.NC}")
    print(f"    {Colors.LIME}║{Colors.NC}  {Colors.YELLOW_GREEN}🎧 CODIFICANDO MP3 FINAL ({mp3_bitrate}) 🎧{Colors.NC}                    {Colors.LIME}║{Colors.NC}")
    print(f"    {Colors.LIME}╚════════════════════════════════════════════════════════════╝{Colors.NC}")
    print()
    stop_event = threading.Event()
    messages = ["Codificando audio...", "Aplicando compresión...", "Generando MP3...", "Casi listo..."]
    anim_thread = threading.Thread(target=lambda: animate_conversion("", stop_event, messages), daemon=True)
    anim_thread.start()
    cmd = ['ffmpeg', '-hide_banner', '-loglevel', 'error',
           '-i', str(tmp_concat),
           '-codec:a', 'libmp3lame', '-b:a', mp3_bitrate,
           '-id3v2_version', '3',
           '-metadata', f'title={output_name}',
           '-metadata', f'album={output_name}',
           '-metadata', f'comment=Álbum completo para registro de derechos de autor - {len(audio_files)} pistas',
           '-y', str(output_file)]
    result = subprocess.run(cmd, capture_output=True)
    stop_event.set()
    anim_thread.join(timeout=0.5)
    print("\r\033[K", end='', flush=True, file=sys.stderr)
    print()
    cleanup()
    if result.returncode == 0 and output_file.exists():
        final_size = get_file_size(output_file)
        final_dur = get_audio_duration(output_file)
        final_dur_fmt = format_duration(final_dur) if final_dur else "00:00"
        print()
        print()
        print(f"    {Colors.LIME}╔════════════════════════════════════════════════════════════╗{Colors.NC}")
        print(f"    {Colors.LIME}║{Colors.NC}                                                            {Colors.LIME}║{Colors.NC}")
        print(f"    {Colors.LIME}║{Colors.NC}   {Colors.YELLOW_GREEN}🏆  ¡¡VICTORY ROYALE!!  🏆{Colors.NC}                              {Colors.LIME}║{Colors.NC}")
        print(f"    {Colors.LIME}║{Colors.NC}                                                            {Colors.LIME}║{Colors.NC}")
        print(f"    {Colors.LIME}║{Colors.NC}   {Colors.LIGHT_GREEN}MP3 UNIFICADO CREADO EXITOSAMENTE{Colors.NC}                       {Colors.LIME}║{Colors.NC}")
        print(f"    {Colors.LIME}║{Colors.NC}   {Colors.MEDIUM_GREEN}Listo para registro de derechos de autor{Colors.NC}               {Colors.LIME}║{Colors.NC}")
        print(f"    {Colors.LIME}║{Colors.NC}                                                            {Colors.LIME}║{Colors.NC}")
        print(f"    {Colors.LIME}╚════════════════════════════════════════════════════════════╝{Colors.NC}")
        print()
        print(f"    {Colors.LIME}Archivo:{Colors.NC}      {Colors.LIGHT_GREEN}{output_file.name}{Colors.NC}")
        print(f"    {Colors.LIME}Pistas:{Colors.NC}       {Colors.LIGHT_GREEN}{len(audio_files)}{Colors.NC}")
        print(f"    {Colors.LIME}Duración:{Colors.NC}     {Colors.LIGHT_GREEN}{final_dur_fmt}{Colors.NC}")
        print(f"    {Colors.LIME}Tamaño:{Colors.NC}       {Colors.LIGHT_GREEN}{final_size}{Colors.NC}")
        print(f"    {Colors.LIME}Bitrate:{Colors.NC}      {Colors.LIGHT_GREEN}{mp3_bitrate}{Colors.NC}")
        print(f"    {Colors.LIME}Silencio:{Colors.NC}     {Colors.LIGHT_GREEN}{silence_duration}s entre pistas{Colors.NC}")
        return True
    else:
        print_error("Error al crear el MP3 final")
        return False


def process_audio_to_flac(source_dir: Path, output_dirname: str = "flac_hires",
                          sample_rate: int = FLAC_SAMPLE_RATE, bit_depth: int = FLAC_BIT_DEPTH,
                          compression: int = FLAC_COMPRESSION):
    output_dir = source_dir / output_dirname
    output_dir.mkdir(exist_ok=True)
    audio_files = select_audio_source_files(
        source_dir,
        extensions=HIRES_AUDIO_SOURCE_EXTENSIONS,
        formats_label=HIRES_AUDIO_SOURCE_FORMATS_LABEL,
        filter_note="Incluye fuentes con pérdida (MP3/M4A). Convertirlas a FLAC no recupera detalle perdido, pero sí unifica el formato maestro."
    )
    if audio_files is None:
        print_warning("Conversión cancelada.")
        return False
    if not audio_files:
        print_error("No se encontraron archivos compatibles para convertir a FLAC.")
        print_info("Formatos soportados para esta selección: WAV, AIFF, FLAC, MP3, M4A")
        return False
    print_header(f"Archivos de audio encontrados: {len(audio_files)}")
    lossy_count = 0
    for f in audio_files:
        dur = get_audio_duration(f)
        info = get_audio_info(f)
        sr = info.get('sample_rate', '?')
        codec = info.get('codec', '?')
        dur_fmt = format_duration(dur) if dur else "00:00"
        if f.suffix.lower() in LOSSY_AUDIO_SOURCE_EXTENSIONS:
            lossy_count += 1
        print(f"    {Colors.LIME}📄{Colors.NC} {Colors.LIGHT_GREEN}{f.name}{Colors.NC} {Colors.MEDIUM_GREEN}({dur_fmt}, {sr}Hz, {codec}){Colors.NC}")
    print()
    sr_display = "192kHz" if sample_rate == 192000 else ("96kHz" if sample_rate == 96000 else ("48kHz" if sample_rate == 48000 else ("44.1kHz" if sample_rate == 44100 else f"{sample_rate}Hz")))
    effective_bit_depth = get_effective_flac_bit_depth(bit_depth)
    print_info("Configuración FLAC:")
    print(f"    {Colors.LIME}Sample Rate:{Colors.NC}    {Colors.LIGHT_GREEN}{sr_display}{Colors.NC}")
    if bit_depth == effective_bit_depth:
        print(f"    {Colors.LIME}Bit Depth:{Colors.NC}      {Colors.LIGHT_GREEN}{bit_depth}-bit{Colors.NC}")
    else:
        print(f"    {Colors.LIME}Bit Depth:{Colors.NC}      {Colors.LIGHT_GREEN}{bit_depth}-bit solicitado{Colors.NC}")
        print(f"    {Colors.LIME}FLAC efectivo:{Colors.NC} {Colors.LIGHT_GREEN}{effective_bit_depth}-bit{Colors.NC}")
    print(f"    {Colors.LIME}Compresión:{Colors.NC}     {Colors.LIGHT_GREEN}Nivel {compression}{Colors.NC}")
    if lossy_count > 0:
        print_warning(f"Se detectaron {lossy_count} fuente(s) MP3/M4A.")
        print_info("La conversión a FLAC mejora compatibilidad y preserva la reexportación, pero no restaura información perdida del original con pérdida.")
    if bit_depth == 32 and effective_bit_depth != 32:
        print_warning("FFmpeg en este flujo genera FLAC efectivo a 24-bit aunque se procese en s32.")
    print()
    if not confirm(f"¿Convertir {len(audio_files)} archivos a FLAC {sr_display}/{effective_bit_depth}-bit efectivo?"):
        print_warning("Conversión cancelada.")
        return False
    print_header(f"Iniciando conversión a FLAC {sr_display}/{effective_bit_depth}-bit")
    print(f"    {Colors.MEDIUM_GREEN}💡 Presiona Ctrl+C en cualquier momento para cancelar{Colors.NC}")
    print()
    success_count = 0
    fail_count = 0
    for i, audio_file in enumerate(audio_files, 1):
        if INTERRUPTED:
            print_warning("Conversión interrumpida por el usuario")
            break
        print(f"\n{Colors.BOLD}[{i}/{len(audio_files)}]{Colors.NC} {audio_file.name}")
        if convert_to_flac(audio_file, output_dir, sample_rate, bit_depth, compression):
            success_count += 1
        else:
            fail_count += 1
    print()
    print_header("Conversión FLAC Completada")
    print()
    print(f"    {Colors.LIGHT_GREEN}╔════════════════════════════════════════════════════════╗{Colors.NC}")
    print(f"    {Colors.LIGHT_GREEN}║  {Colors.LIME}ARCHIVOS FLAC DE ALTA RESOLUCIÓN CREADOS{Colors.LIGHT_GREEN}              ║{Colors.NC}")
    print(f"    {Colors.LIGHT_GREEN}╚════════════════════════════════════════════════════════╝{Colors.NC}")
    print()
    print(f"    {Colors.LIGHT_GREEN}Exitosos:{Colors.NC} {Colors.LIME}{success_count}{Colors.NC}")
    if fail_count > 0:
        print(f"    {Colors.DARK_GREEN}Fallidos:{Colors.NC} {Colors.YELLOW_GREEN}{fail_count}{Colors.NC}")
    print(f"    {Colors.LIME}Formato:{Colors.NC}  {Colors.LIGHT_GREEN}FLAC {sr_display}/{effective_bit_depth}-bit{Colors.NC}")
    print(f"    {Colors.LIME}Salida:{Colors.NC}   {Colors.LIGHT_GREEN}{output_dir}/{Colors.NC}")
    return success_count > 0


def select_sample_rate_for_432hz() -> Optional[int]:
    """
    Permite al usuario seleccionar el sample rate de salida para la conversión a 432Hz.
    Retorna el sample rate seleccionado o None si se cancela.
    """
    print_header("Selecciona Resolución de Audio (Sample Rate)")
    print()
    print(f"    {Colors.LIME}🎚️  Resolución de salida para conversión a 432Hz{Colors.NC}")
    print(f"    {Colors.MEDIUM_GREEN}El sample rate determina la calidad y el tamaño del archivo final.{Colors.NC}")
    print()
    
    sample_rates = {
        "1": {"rate": 44100, "name": "44.1kHz (CD Quality)", "description": "Calidad de CD estándar. Archivos más pequeños, compatible universalmente."},
        "2": {"rate": 48000, "name": "48kHz (Professional)", "description": "Estándar profesional para producción. Balance calidad/tamaño."},
        "3": {"rate": 96000, "name": "96kHz (Hi-Res)", "description": "Alta resolución. Buena calidad, archivos más grandes."},
        "4": {"rate": 192000, "name": "192kHz (Ultra Hi-Res) - Recomendado ⭐", "description": "Ultra alta resolución. Máxima calidad posible, archivos muy grandes. Ideal para música devocional."},
    }
    
    # Mostrar opciones
    for key, sr_info in sample_rates.items():
        rec_mark = " ⭐" if "Recomendado" in sr_info["name"] else ""
        print(f"  {Colors.LIME}{key}){Colors.NC} {sr_info['name']}{rec_mark}")
        print(f"      {Colors.MEDIUM_GREEN}{sr_info['description']}{Colors.NC}")
        print()
    
    # Solicitar selección
    while True:
        try:
            choice = input(f"{Colors.YELLOW_GREEN}▶ Selecciona resolución (1-4) o Enter para 192kHz (recomendado): {Colors.NC}").strip()
            
            # Si es Enter (vacío), retornar 192kHz por defecto
            if not choice:
                print()
                print_success(f"Resolución seleccionada: 192kHz (Ultra Hi-Res) - Recomendado")
                print()
                return 192000
            
            if choice in sample_rates:
                selected = sample_rates[choice]
                print()
                print_success(f"Resolución seleccionada: {selected['name']}")
                print()
                return selected["rate"]
            else:
                print_error(f"Opción inválida. Selecciona un número del 1 al 4, o presiona Enter para 192kHz.")
        except (EOFError, KeyboardInterrupt):
            return None


def select_output_format_for_432hz() -> Optional[Dict]:
    """
    Permite al usuario seleccionar el formato de salida (WAV o FLAC) y nivel de compresión.
    Retorna un dict con la configuración o None si se cancela.
    """
    print_header("Selecciona Formato de Salida")
    print()
    print(f"    {Colors.LIME}📦 Formato de archivo de salida para conversión a 432Hz{Colors.NC}")
    print(f"    {Colors.MEDIUM_GREEN}El formato determina la calidad, tamaño y compatibilidad del archivo.{Colors.NC}")
    print()
    
    formats = {
        "1": {
            "name": "WAV (PCM sin comprimir)",
            "format": "wav",
            "description": "Sin pérdida, sin compresión. Máxima calidad, archivos muy grandes. Compatible universalmente."
        },
        "2": {
            "name": "WAV Comprimido",
            "format": "wav_compressed",
            "description": "WAV con compresión (ADPCM). Menor tamaño que PCM, buena compatibilidad."
        },
        "3": {
            "name": "FLAC (Recomendado ⭐)",
            "format": "flac",
            "description": "Sin pérdida con compresión. Excelente relación calidad/tamaño. Ideal para archivo maestro."
        },
    }
    
    # Mostrar opciones
    for key, fmt_info in formats.items():
        rec_mark = " ⭐" if "Recomendado" in fmt_info["name"] else ""
        print(f"  {Colors.LIME}{key}){Colors.NC} {fmt_info['name']}{rec_mark}")
        print(f"      {Colors.MEDIUM_GREEN}{fmt_info['description']}{Colors.NC}")
        print()
    
    # Solicitar selección de formato
    selected_format = None
    while selected_format is None:
        try:
            choice = input(f"{Colors.YELLOW_GREEN}▶ Selecciona formato (1-3) o Enter para FLAC (recomendado): {Colors.NC}").strip()
            
            # Si es Enter (vacío), retornar FLAC por defecto
            if not choice:
                selected_format = formats["3"]
                break
            
            if choice in formats:
                selected_format = formats[choice]
                break
            else:
                print_error(f"Opción inválida. Selecciona un número del 1 al 3, o presiona Enter para FLAC.")
        except (EOFError, KeyboardInterrupt):
            return None
    
    print()
    print_success(f"Formato seleccionado: {selected_format['name']}")
    print()
    
    # Si es WAV comprimido, seleccionar codec
    codec = None
    if selected_format["format"] == "wav_compressed":
        print_header("Selecciona Codec de Compresión WAV")
        print()
        codecs = {
            "1": {"codec": "adpcm_ms", "name": "ADPCM Microsoft", "description": "Compresión ~25% del tamaño PCM. Buena compatibilidad."},
            "2": {"codec": "adpcm_ima_wav", "name": "ADPCM IMA", "description": "Compresión ~25% del tamaño PCM. Estándar IMA."},
            "3": {"codec": "gsm_ms", "name": "GSM Microsoft", "description": "Compresión ~20% del tamaño PCM. Muy eficiente."},
        }
        
        for key, codec_info in codecs.items():
            print(f"  {Colors.LIME}{key}){Colors.NC} {codec_info['name']}")
            print(f"      {Colors.MEDIUM_GREEN}{codec_info['description']}{Colors.NC}")
            print()
        
        while codec is None:
            try:
                codec_choice = input(f"{Colors.YELLOW_GREEN}▶ Selecciona codec (1-3) o Enter para ADPCM Microsoft: {Colors.NC}").strip()
                
                if not codec_choice:
                    codec = "adpcm_ms"
                    break
                
                if codec_choice in codecs:
                    codec = codecs[codec_choice]["codec"]
                    break
                else:
                    print_error(f"Opción inválida. Selecciona un número del 1 al 3.")
            except (EOFError, KeyboardInterrupt):
                return None
        
        # Encontrar el nombre del codec seleccionado
        codec_name = codec
        for codec_info in codecs.values():
            if codec_info['codec'] == codec:
                codec_name = codec_info['name']
                break
        
        print()
        print_success(f"Codec seleccionado: {codec_name}")
        print()
    
    # Si es FLAC o WAV comprimido, seleccionar nivel de compresión
    compression_level = 8  # Default
    if selected_format["format"] in ["flac", "wav_compressed"]:
        print_header("Selecciona Nivel de Compresión")
        print()
        
        if selected_format["format"] == "flac":
            print(f"    {Colors.LIME}🎚️  Nivel de compresión FLAC (0-12){Colors.NC}")
            print()
            print(f"    {Colors.MEDIUM_GREEN}📊 ¿Cómo funcionan los niveles de compresión?{Colors.NC}")
            print(f"    {Colors.MEDIUM_GREEN}FLAC es un formato SIN PÉRDIDA: la calidad de audio es idéntica en todos los niveles.{Colors.NC}")
            print(f"    {Colors.MEDIUM_GREEN}Los niveles más altos comprimen MÁS (archivos más pequeños) pero tardan MÁS tiempo.{Colors.NC}")
            print()
            print(f"    {Colors.LIME}📦 Ratios de compresión estimados:{Colors.NC}")
            print()
            print(f"    {Colors.LIGHT_GREEN}0-2:{Colors.NC}   Compresión rápida")
            print(f"      {Colors.DARK_FOREST}→ Archivo: ~75% del tamaño WAV original{Colors.NC}")
            print(f"      {Colors.DARK_FOREST}→ Ejemplo: 100MB WAV → ~75MB FLAC{Colors.NC}")
            print(f"      {Colors.DARK_FOREST}→ Velocidad: Muy rápida{Colors.NC}")
            print()
            print(f"    {Colors.LIGHT_GREEN}3-5:{Colors.NC}   Balance velocidad/tamaño")
            print(f"      {Colors.DARK_FOREST}→ Archivo: ~65% del tamaño WAV original{Colors.NC}")
            print(f"      {Colors.DARK_FOREST}→ Ejemplo: 100MB WAV → ~65MB FLAC{Colors.NC}")
            print(f"      {Colors.DARK_FOREST}→ Velocidad: Rápida{Colors.NC}")
            print()
            print(f"    {Colors.LIGHT_GREEN}6-8:{Colors.NC}   Buen balance ⭐ (recomendado)")
            print(f"      {Colors.DARK_FOREST}→ Archivo: ~55% del tamaño WAV original{Colors.NC}")
            print(f"      {Colors.DARK_FOREST}→ Ejemplo: 100MB WAV → ~55MB FLAC{Colors.NC}")
            print(f"      {Colors.DARK_FOREST}→ Velocidad: Media (buen equilibrio){Colors.NC}")
            print()
            print(f"    {Colors.LIGHT_GREEN}9-12:{Colors.NC}  Máxima compresión")
            print(f"      {Colors.DARK_FOREST}→ Archivo: ~50% del tamaño WAV original{Colors.NC}")
            print(f"      {Colors.DARK_FOREST}→ Ejemplo: 100MB WAV → ~50MB FLAC{Colors.NC}")
            print(f"      {Colors.DARK_FOREST}→ Velocidad: Lenta (máximo ahorro de espacio){Colors.NC}")
            print()
            print(f"    {Colors.YELLOW_GREEN}💡 Comparación práctica:{Colors.NC}")
            print(f"    {Colors.MEDIUM_GREEN}Nivel 3 vs Nivel 8: El nivel 8 produce archivos ~15% más pequeños,{Colors.NC}")
            print(f"    {Colors.MEDIUM_GREEN}pero tarda más tiempo en procesar. La calidad de audio es idéntica.{Colors.NC}")
            print()
        else:  # wav_compressed
            print(f"    {Colors.LIME}🎚️  Nivel de compresión WAV{Colors.NC}")
            print(f"    {Colors.MEDIUM_GREEN}Algunos codecs WAV comprimidos tienen niveles de compresión.{Colors.NC}")
            print()
        
        while True:
            try:
                comp_input = input(f"{Colors.YELLOW_GREEN}▶ Nivel de compresión (0-12, Enter=8): {Colors.NC}").strip()
                
                if not comp_input:
                    compression_level = 8
                    break
                
                compression_level = int(comp_input)
                if 0 <= compression_level <= 12:
                    break
                else:
                    print_error("El nivel debe estar entre 0 y 12.")
            except ValueError:
                print_error("Por favor ingresa un número entre 0 y 12.")
            except (EOFError, KeyboardInterrupt):
                return None
        
        print()
        print_success(f"Nivel de compresión seleccionado: {compression_level}")
        print()
    
    return {
        'format': selected_format["format"],
        'compression': compression_level,
        'codec': codec
    }


def select_audio_files_for_432hz(audio_files: List[Path]) -> Optional[List[Path]]:
    """
    Permite al usuario seleccionar archivos individuales o procesar todos.
    Retorna:
    - Lista de Paths de archivos seleccionados
    - None si se cancela (Ctrl+C)
    """
    print_header("Selecciona Archivos para Conversión a 432Hz")
    print()
    print(f"    {Colors.LIME}🕉️  Conversión a frecuencia universal 432Hz{Colors.NC}")
    print(f"    {Colors.MEDIUM_GREEN}Convierte audio de 440Hz a 432Hz manteniendo la duración original.{Colors.NC}")
    print()
    print(f"    {Colors.LIME}📋 Selecciona archivos de la lista:{Colors.NC}")
    print()
    print(f"    {Colors.YELLOW_GREEN}💡 Puedes seleccionar múltiples archivos separados por comas (ej: 1,3,5){Colors.NC}")
    print(f"    {Colors.YELLOW_GREEN}💡 O presiona Enter para convertir todos los archivos{Colors.NC}")
    print()
    
    # Mostrar lista numerada de archivos
    for i, audio_file in enumerate(audio_files, 1):
        duration = get_audio_duration(audio_file)
        duration_str = format_duration(duration) if duration else "N/A"
        size_str = get_file_size(audio_file)
        print(f"  {Colors.LIME}{i}){Colors.NC} {Colors.LIGHT_GREEN}{audio_file.name}{Colors.NC}")
        print(f"      {Colors.MEDIUM_GREEN}Duración:{Colors.NC} {duration_str} | {Colors.MEDIUM_GREEN}Tamaño:{Colors.NC} {size_str}")
    
    print()
    
    # Solicitar selección
    while True:
        try:
            choice = input(f"{Colors.YELLOW_GREEN}▶ Selecciona archivo(s) (1-{len(audio_files)}, separados por comas) o Enter para todos: {Colors.NC}").strip()
            
            # Si es Enter (vacío), retornar todos los archivos
            if not choice:
                print()
                print_success(f"Procesando todos los archivos ({len(audio_files)})")
                print()
                return audio_files
            
            # Procesar selección múltiple
            try:
                selected_indices = []
                parts = choice.split(',')
                for part in parts:
                    part = part.strip()
                    if not part:
                        continue
                    index = int(part) - 1
                    if 0 <= index < len(audio_files):
                        if index not in selected_indices:
                            selected_indices.append(index)
                    else:
                        print_error(f"Número inválido: {part}. Debe estar entre 1 y {len(audio_files)}.")
                        break
                else:
                    # Si no hubo errores, retornar archivos seleccionados
                    if selected_indices:
                        selected_files = [audio_files[i] for i in sorted(selected_indices)]
                        print()
                        print_success(f"Archivos seleccionados: {len(selected_files)}")
                        for f in selected_files:
                            print(f"    {Colors.LIGHT_GREEN}• {f.name}{Colors.NC}")
                        print()
                        return selected_files
                    else:
                        print_error("No se seleccionaron archivos válidos.")
            except ValueError:
                print_error(f"Por favor ingresa números del 1 al {len(audio_files)}, separados por comas, o presiona Enter para todos.")
        except (EOFError, KeyboardInterrupt):
            return None


def select_sample_rate_for_432hz_mp3() -> Optional[int]:
    """
    Permite al usuario seleccionar el sample rate de salida para la conversión a 432Hz MP3.
    Retorna el sample rate seleccionado o None si se cancela.
    
    Nota: libmp3lame solo soporta hasta 48kHz. Si se selecciona un rate mayor,
    el audio se procesará internamente a esa resolución pero se resampleará a 48kHz para MP3.
    """
    print_header("Selecciona Resolución de Audio (Sample Rate) para MP3")
    print()
    print(f"    {Colors.LIME}🎚️  Resolución de salida para conversión a 432Hz MP3{Colors.NC}")
    print(f"    {Colors.MEDIUM_GREEN}El sample rate determina la calidad del procesamiento interno.{Colors.NC}")
    print()
    print(f"    {Colors.YELLOW_GREEN}⚠️  IMPORTANTE: libmp3lame (codec MP3) solo soporta hasta 48kHz{Colors.NC}")
    print(f"    {Colors.MEDIUM_GREEN}Si seleccionas > 48kHz, el audio se procesará a esa resolución internamente,{Colors.NC}")
    print(f"    {Colors.MEDIUM_GREEN}pero se resampleará automáticamente a 48kHz antes de codificar a MP3.{Colors.NC}")
    print()
    
    sample_rates = {
        "1": {"rate": 44100, "name": "44.1kHz (CD Quality)", "description": "Estándar CD. Máxima compatibilidad universal. Recomendado para compatibilidad.", "standard": True},
        "2": {"rate": 48000, "name": "48kHz (Professional) ⭐", "description": "Estándar profesional. Máximo soportado por libmp3lame. Excelente compatibilidad. RECOMENDADO.", "standard": True},
        "3": {"rate": 96000, "name": "96kHz (Hi-Res) - Procesamiento interno", "description": "Alta resolución para procesamiento interno. Se resampleará a 48kHz para MP3 final.", "standard": False},
        "4": {"rate": 192000, "name": "192kHz (Ultra Hi-Res) - Procesamiento interno", "description": "Ultra alta resolución para procesamiento interno. Se resampleará a 48kHz para MP3 final.", "standard": False},
    }
    
    # Mostrar opciones
    for key, sr_info in sample_rates.items():
        rec_mark = " ⭐" if "⭐" in sr_info["name"] else ""
        warning = " (se resampleará a 48kHz)" if not sr_info["standard"] else ""
        print(f"  {Colors.LIME}{key}){Colors.NC} {sr_info['name']}{rec_mark}{warning}")
        print(f"      {Colors.MEDIUM_GREEN}{sr_info['description']}{Colors.NC}")
        print()
    
    # Solicitar selección
    while True:
        try:
            choice = input(f"{Colors.YELLOW_GREEN}▶ Selecciona resolución (1-4) o Enter para 48kHz (recomendado): {Colors.NC}").strip()
            
            # Si es Enter (vacío), retornar 48kHz por defecto
            if not choice:
                print()
                print_success(f"Resolución seleccionada: 48kHz (Professional) - Recomendado")
                print()
                return 48000
            
            if choice in sample_rates:
                selected = sample_rates[choice]
                print()
                if not selected["standard"]:
                    print_info(f"ℹ️  Nota: El audio se procesará internamente a {selected['rate']}Hz")
                    print_info("   pero se resampleará automáticamente a 48kHz antes de codificar a MP3")
                    print_info("   (libmp3lame solo soporta hasta 48kHz)")
                    if not confirm("¿Continuar con procesamiento a alta resolución?"):
                        continue
                print_success(f"Resolución seleccionada: {selected['name']}")
                if not selected["standard"]:
                    print(f"    {Colors.MEDIUM_GREEN}→ MP3 final será a 48kHz (máximo soportado){Colors.NC}")
                print()
                return selected["rate"]
            else:
                print_error(f"Opción inválida. Selecciona un número del 1 al 4, o presiona Enter para 48kHz.")
        except (EOFError, KeyboardInterrupt):
            return None


def select_mp3_quality_settings() -> Optional[Dict]:
    """
    Permite al usuario seleccionar la configuración de calidad MP3 (bitrate o VBR).
    Retorna un dict con la configuración o None si se cancela.
    """
    print_header("Selecciona Calidad MP3")
    print()
    print(f"    {Colors.LIME}📦 Configuración de calidad para archivos MP3{Colors.NC}")
    print(f"    {Colors.MEDIUM_GREEN}MP3 es un formato con pérdida: mayor bitrate = mejor calidad pero archivos más grandes.{Colors.NC}")
    print()
    
    modes = {
        "1": {
            "name": "CBR (Constant Bitrate) - Recomendado ⭐",
            "mode": "cbr",
            "description": "Bitrate constante. Calidad predecible, archivos de tamaño consistente."
        },
        "2": {
            "name": "VBR (Variable Bitrate)",
            "mode": "vbr",
            "description": "Bitrate variable. Mejor calidad en pasajes complejos, archivos más pequeños."
        },
    }
    
    # Mostrar opciones de modo
    for key, mode_info in modes.items():
        rec_mark = " ⭐" if "Recomendado" in mode_info["name"] else ""
        print(f"  {Colors.LIME}{key}){Colors.NC} {mode_info['name']}{rec_mark}")
        print(f"      {Colors.MEDIUM_GREEN}{mode_info['description']}{Colors.NC}")
        print()
    
    # Solicitar selección de modo
    selected_mode = None
    while selected_mode is None:
        try:
            choice = input(f"{Colors.YELLOW_GREEN}▶ Selecciona modo (1-2) o Enter para CBR (recomendado): {Colors.NC}").strip()
            
            # Si es Enter (vacío), retornar CBR por defecto
            if not choice:
                selected_mode = modes["1"]
                break
            
            if choice in modes:
                selected_mode = modes[choice]
                break
            else:
                print_error(f"Opción inválida. Selecciona un número del 1 al 2, o presiona Enter para CBR.")
        except (EOFError, KeyboardInterrupt):
            return None
    
    print()
    print_success(f"Modo seleccionado: {selected_mode['name']}")
    print()
    
    # Si es CBR, seleccionar bitrate
    if selected_mode["mode"] == "cbr":
        print_header("Selecciona Bitrate CBR")
        print()
        bitrates = {
            "1": {"bitrate": 128, "name": "128 kbps", "description": "Calidad básica. Archivos pequeños. Adecuado para voz."},
            "2": {"bitrate": 192, "name": "192 kbps", "description": "Calidad media. Balance calidad/tamaño."},
            "3": {"bitrate": 256, "name": "256 kbps", "description": "Buena calidad. Recomendado para música."},
            "4": {"bitrate": 320, "name": "320 kbps ⭐", "description": "Máxima calidad CBR. Excelente para música de alta calidad."},
        }
        
        for key, br_info in bitrates.items():
            rec_mark = " ⭐" if "⭐" in br_info["name"] else ""
            print(f"  {Colors.LIME}{key}){Colors.NC} {br_info['name']}{rec_mark}")
            print(f"      {Colors.MEDIUM_GREEN}{br_info['description']}{Colors.NC}")
            print()
        
        bitrate = None
        while bitrate is None:
            try:
                br_choice = input(f"{Colors.YELLOW_GREEN}▶ Selecciona bitrate (1-4) o Enter para 320kbps (recomendado): {Colors.NC}").strip()
                
                if not br_choice:
                    bitrate = 320
                    break
                
                if br_choice in bitrates:
                    bitrate = bitrates[br_choice]["bitrate"]
                    break
                else:
                    print_error(f"Opción inválida. Selecciona un número del 1 al 4.")
            except (EOFError, KeyboardInterrupt):
                return None
        
        # Encontrar el nombre del bitrate seleccionado
        selected_bitrate_name = None
        for br_info in bitrates.values():
            if br_info['bitrate'] == bitrate:
                selected_bitrate_name = br_info['name']
                break
        
        print()
        print_success(f"Bitrate seleccionado: {selected_bitrate_name or f'{bitrate} kbps'}")
        print()
        
        return {
            'mode': 'cbr',
            'bitrate': bitrate,
            'vbr_quality': None
        }
    
    else:  # VBR
        print_header("Selecciona Calidad VBR")
        print()
        print(f"    {Colors.LIME}🎚️  Calidad VBR (0-9){Colors.NC}")
        print(f"    {Colors.MEDIUM_GREEN}Valores más bajos = mejor calidad pero archivos más grandes.{Colors.NC}")
        print()
        print(f"    {Colors.LIGHT_GREEN}0:{Colors.NC}   Máxima calidad VBR (~245 kbps promedio)")
        print(f"    {Colors.LIGHT_GREEN}1-2:{Colors.NC}  Calidad muy alta (~225 kbps promedio)")
        print(f"    {Colors.LIGHT_GREEN}3-4:{Colors.NC}  Calidad alta (~190 kbps promedio)")
        print(f"    {Colors.LIGHT_GREEN}5-6:{Colors.NC}  Calidad media (~175 kbps promedio)")
        print(f"    {Colors.LIGHT_GREEN}7-9:{Colors.NC}  Calidad básica (~165 kbps promedio)")
        print()
        
        vbr_quality = None
        while vbr_quality is None:
            try:
                vbr_input = input(f"{Colors.YELLOW_GREEN}▶ Calidad VBR (0-9, Enter=0 para máxima calidad): {Colors.NC}").strip()
                
                if not vbr_input:
                    vbr_quality = 0
                    break
                
                vbr_quality = int(vbr_input)
                if 0 <= vbr_quality <= 9:
                    break
                else:
                    print_error("El valor debe estar entre 0 y 9.")
            except ValueError:
                print_error("Por favor ingresa un número entre 0 y 9.")
            except (EOFError, KeyboardInterrupt):
                return None
        
        print()
        print_success(f"Calidad VBR seleccionada: {vbr_quality} (0=máxima calidad)")
        print()
        
        return {
            'mode': 'vbr',
            'bitrate': None,
            'vbr_quality': vbr_quality
        }


def show_432hz_mp3_estimations(audio_files: List[Path], sample_rate: int,
                               bitrate_kbps: int = None, vbr_quality: int = None) -> None:
    """
    Muestra estimaciones individuales y totales para conversión a 432Hz MP3
    
    Args:
        audio_files: Lista de archivos de audio a convertir
        sample_rate: Sample rate de salida (Hz)
        bitrate_kbps: Bitrate en kbps (solo para CBR)
        vbr_quality: Calidad VBR (solo para VBR)
    """
    print_header("Estimaciones de Conversión a 432Hz MP3")
    print()
    
    # Mostrar configuración seleccionada
    sr_display = "96kHz" if sample_rate == 96000 else ("48kHz" if sample_rate == 48000 else ("44.1kHz" if sample_rate == 44100 else ("192kHz" if sample_rate == 192000 else f"{sample_rate}Hz")))
    
    print(f"    {Colors.LIME}Formato:{Colors.NC}        {Colors.LIGHT_GREEN}MP3{Colors.NC}")
    print(f"    {Colors.LIME}Sample Rate:{Colors.NC}    {Colors.LIGHT_GREEN}{sr_display}{Colors.NC}")
    if sample_rate > 48000:
        print(f"    {Colors.YELLOW_GREEN}⚠️  ADVERTENCIA: Sample rate > 48kHz NO es parte del estándar MP3{Colors.NC}")
    if bitrate_kbps:
        print(f"    {Colors.LIME}Bitrate:{Colors.NC}        {Colors.LIGHT_GREEN}{bitrate_kbps} kbps (CBR){Colors.NC}")
    elif vbr_quality is not None:
        print(f"    {Colors.LIME}Calidad:{Colors.NC}        {Colors.LIGHT_GREEN}VBR Quality {vbr_quality} (0=máxima){Colors.NC}")
    print()
    print(f"    {Colors.MEDIUM_GREEN}💡 Nota: MP3 procesa desde entrada de alta calidad (24-bit),{Colors.NC}")
    print(f"    {Colors.MEDIUM_GREEN}   pero el formato final no preserva bit depth nativo.{Colors.NC}")
    print()
    
    total_duration_min = 0
    total_original_size_mb = 0
    total_estimated_size_mb = 0
    total_time_min = 0
    
    # Calcular estimaciones para cada archivo
    file_estimations = []
    for audio_file in audio_files:
        duration = get_audio_duration(audio_file)
        if duration:
            duration_min = duration / 60.0
            original_size_mb = audio_file.stat().st_size / (1024 * 1024)
            
            # Estimar tamaño de salida
            if bitrate_kbps:
                est_size_mb = estimate_mp3_output_size(duration, bitrate_kbps)
            else:
                # Para VBR, estimar basado en calidad (aproximado)
                avg_bitrates = {0: 245, 1: 225, 2: 225, 3: 190, 4: 190, 5: 175, 6: 175, 7: 165, 8: 165, 9: 165}
                avg_bitrate = avg_bitrates.get(vbr_quality, 200)
                est_size_mb = estimate_mp3_output_size(duration, avg_bitrate)
            
            # Estimar tiempo de conversión
            est_time_min = estimate_432hz_conversion_time(
                duration, output_format='mp3', bitrate_kbps=bitrate_kbps or 320
            )
            
            file_estimations.append({
                'file': audio_file,
                'duration': duration,
                'duration_min': duration_min,
                'original_size_mb': original_size_mb,
                'estimated_size_mb': est_size_mb,
                'estimated_time_min': est_time_min
            })
            
            total_duration_min += duration_min
            total_original_size_mb += original_size_mb
            total_estimated_size_mb += est_size_mb
            total_time_min += est_time_min
    
    # Mostrar tabla de estimaciones individuales
    print(f"    {Colors.LIME}{'Archivo':<30} {'Duración':<12} {'Tamaño Orig.':<15} {'Tamaño Est.':<18} {'Tiempo Est.':<15}{Colors.NC}")
    print(f"    {Colors.DARK_GREEN}{'-' * 90}{Colors.NC}")
    
    for est in file_estimations:
        duration_str = format_duration(est['duration'])
        original_size_str = get_file_size(est['file'])
        
        if est['estimated_size_mb'] < 1024:
            estimated_size_str = f"{est['estimated_size_mb']:.1f}MB"
        else:
            estimated_size_str = f"{est['estimated_size_mb']/1024:.1f}GB"
        
        time_str = format_time_estimate(est['estimated_time_min'])
        
        file_name = est['file'].name[:28] + ".." if len(est['file'].name) > 30 else est['file'].name
        print(f"    {Colors.LIGHT_GREEN}{file_name:<30}{Colors.NC} {duration_str:<12} {original_size_str:<15} {estimated_size_str:<18} {time_str:<15}")
    
    print()
    print(f"    {Colors.DARK_GREEN}{'-' * 90}{Colors.NC}")
    
    # Mostrar totales
    total_duration_str = format_time_estimate(total_duration_min)
    
    if total_original_size_mb < 1024:
        total_original_str = f"{total_original_size_mb:.1f}MB"
    else:
        total_original_str = f"{total_original_size_mb/1024:.1f}GB"
    
    if total_estimated_size_mb < 1024:
        total_estimated_str = f"{total_estimated_size_mb:.1f}MB"
    else:
        total_estimated_str = f"{total_estimated_size_mb/1024:.1f}GB"
    
    total_time_str = format_time_estimate(total_time_min)
    
    print(f"    {Colors.LIME}{'TOTALES':<30} {total_duration_str:<12} {total_original_str:<15} {total_estimated_str:<18} {total_time_str:<15}{Colors.NC}")
    print()


def process_to_432hz(source_dir: Path, output_dir: Path):
    """
    Procesa archivos de audio convirtiéndolos a frecuencia 432Hz
    
    Args:
        source_dir: Directorio fuente donde están los archivos de audio
        output_dir: Directorio de destino donde se guardarán los archivos convertidos
    """
    output_dir.mkdir(parents=True, exist_ok=True)
    audio_files = select_audio_source_files(source_dir)
    if audio_files is None:
        print_warning("Conversión cancelada.")
        return False
    if not audio_files:
        print_error("No se encontraron archivos WAV/AIFF/FLAC para convertir a 432Hz")
        return False
    
    print_header("Conversión a frecuencia 432Hz - Música Devocional")
    print()
    print(f"    {Colors.LIME}╔════════════════════════════════════════════════════════════╗{Colors.NC}")
    print(f"    {Colors.LIME}║{Colors.NC}  {Colors.YELLOW_GREEN}🕉️  CONVERSIÓN A 432Hz - FRECUENCIA SANADORA 🕉️{Colors.NC}         {Colors.LIME}║{Colors.NC}")
    print(f"    {Colors.LIME}╚════════════════════════════════════════════════════════════╝{Colors.NC}")
    print()
    print_info(f"Archivos encontrados: {len(audio_files)}")
    print()
    
    # Permitir al usuario seleccionar archivos
    selected_files = select_audio_files_for_432hz(audio_files)
    if selected_files is None:
        print_warning("Conversión cancelada.")
        return False
    
    if not selected_files:
        print_error("No se seleccionaron archivos para convertir.")
        return False
    
    print()
    
    # Permitir al usuario seleccionar formato de salida
    format_config = select_output_format_for_432hz()
    if format_config is None:
        print_warning("Conversión cancelada.")
        return False
    
    output_format = format_config['format']
    compression_level = format_config['compression']
    codec = format_config['codec']
    
    print()
    
    # Permitir al usuario seleccionar sample rate
    output_sample_rate = select_sample_rate_for_432hz()
    if output_sample_rate is None:
        print_warning("Conversión cancelada.")
        return False
    
    # Obtener bit depth del primer archivo (asumimos que todos tienen el mismo)
    # O usar 24-bit por defecto
    first_file_info = get_audio_info(selected_files[0])
    output_bit_depth = first_file_info.get('bit_depth', 24) or 24
    if output_bit_depth not in [16, 24]:
        output_bit_depth = 24  # Default a 24-bit si no es 16 o 24
    
    # Formatear sample rate para mostrar
    sr_display = "96kHz" if output_sample_rate == 96000 else ("48kHz" if output_sample_rate == 48000 else ("44.1kHz" if output_sample_rate == 44100 else f"{output_sample_rate}Hz"))
    
    print()
    
    # Mostrar tabla de estimaciones
    show_432hz_estimations(
        selected_files, output_format, output_sample_rate,
        output_bit_depth, compression_level, codec
    )
    
    print()
    if not confirm(f"¿Convertir {len(selected_files)} archivo(s) a 432Hz con formato {output_format.upper()} y resolución {sr_display}?"):
        print_warning("Conversión cancelada.")
        return False
    
    print()
    print_header("Iniciando conversión a 432Hz")
    print(f"    {Colors.LIME}Resolución de salida:{Colors.NC} {Colors.LIGHT_GREEN}{sr_display}{Colors.NC}")
    print(f"    {Colors.MEDIUM_GREEN}💡 Presiona Ctrl+C en cualquier momento para cancelar{Colors.NC}")
    print()
    
    success_count = 0
    fail_count = 0
    skip_count = 0
    existing_files = []
    created_output_dirs = set()

    if output_dir.resolve() == source_dir.resolve():
        (source_dir / "masters").mkdir(parents=True, exist_ok=True)
    
    # Determinar extensión según formato
    output_ext = ".wav" if output_format in ['wav', 'wav_compressed'] else ".flac"
    per_subdir_output_name = "flac" if output_format == "flac" else "wav"
    
    # Verificar archivos existentes antes de procesar
    for audio_file in selected_files:
        target_dir = resolve_output_dir_for_file(source_dir, output_dir, audio_file, per_subdir_output_name)
        output_file = target_dir / f"{audio_file.stem}_432Hz{output_ext}"
        if output_file.exists():
            existing_files.append((audio_file, output_file))
    
    # Si hay archivos existentes, preguntar al usuario
    if existing_files:
        print()
        print_warning(f"⚠️  Se encontraron {len(existing_files)} archivo(s) que ya existen en el directorio de salida:")
        for audio_file, output_file in existing_files:
            existing_size = get_file_size(output_file)
            print(f"    {Colors.YELLOW_GREEN}• {output_file.name}{Colors.NC} ({existing_size}) - de {audio_file.name}")
        print()
        print(f"    {Colors.LIME}Opciones:{Colors.NC}")
        print(f"    {Colors.MEDIUM_GREEN}1) Sobrescribir archivos existentes{Colors.NC}")
        print(f"    {Colors.MEDIUM_GREEN}2) Saltar archivos existentes (mantener los actuales){Colors.NC}")
        print(f"    {Colors.MEDIUM_GREEN}3) Agregar sufijo único a archivos nuevos (evitar sobrescritura){Colors.NC}")
        print(f"    {Colors.MEDIUM_GREEN}4) Cancelar{Colors.NC}")
        print()
        
        overwrite_mode = None
        while overwrite_mode is None:
            try:
                choice = input(f"{Colors.YELLOW_GREEN}▶ Selecciona opción (1-4): {Colors.NC}").strip()
                if choice == "1":
                    overwrite_mode = "overwrite"
                    print()
                    print_warning("⚠️  Los archivos existentes serán SOBRESCRITOS")
                    if not confirm("¿Continuar con sobrescritura?"):
                        print_warning("Conversión cancelada.")
                        return False
                elif choice == "2":
                    overwrite_mode = "skip"
                    print()
                    print_info(f"Se saltarán {len(existing_files)} archivo(s) existente(s)")
                elif choice == "3":
                    overwrite_mode = "unique"
                    print()
                    print_info("Se agregará un sufijo único a los archivos nuevos para evitar sobrescritura")
                elif choice == "4":
                    print_warning("Conversión cancelada.")
                    return False
                else:
                    print_error("Opción inválida. Selecciona 1, 2, 3 o 4.")
            except (EOFError, KeyboardInterrupt):
                print_warning("Conversión cancelada.")
                return False
    else:
        overwrite_mode = "overwrite"  # Por defecto, sobrescribir si no hay conflictos
    
    print()
    
    for i, audio_file in enumerate(selected_files, 1):
        if INTERRUPTED:
            print_warning("Conversión interrumpida por el usuario")
            break
        
        target_dir = resolve_output_dir_for_file(source_dir, output_dir, audio_file, per_subdir_output_name)
        target_dir.mkdir(parents=True, exist_ok=True)
        created_output_dirs.add(str(target_dir))
        output_file = target_dir / f"{audio_file.stem}_432Hz{output_ext}"
        
        # Verificar si el archivo ya existe y manejar según el modo seleccionado
        if output_file.exists() and overwrite_mode == "skip":
            skip_count += 1
            existing_size = get_file_size(output_file)
            print(f"\n    {Colors.YELLOW_GREEN}⊘{Colors.NC} {audio_file.name} → Saltado (ya existe: {existing_size})")
            continue
        elif output_file.exists() and overwrite_mode == "unique":
            # Agregar sufijo único basado en timestamp
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            output_file = target_dir / f"{audio_file.stem}_432Hz_{timestamp}{output_ext}"
            # Si aún existe (muy improbable), agregar un número incremental
            counter = 1
            while output_file.exists():
                output_file = target_dir / f"{audio_file.stem}_432Hz_{timestamp}_{counter}{output_ext}"
                counter += 1
        
        animated_progress_bar(i, len(selected_files), f"Convirtiendo: {audio_file.name[:25]}")
        
        if convert_to_432hz(audio_file, output_file, output_sample_rate,
                           output_format=output_format, compression_level=compression_level,
                           codec=codec):
            success_count += 1
            orig_size = get_file_size(audio_file)
            out_size = get_file_size(output_file)
            print(f"\n    {Colors.LIGHT_GREEN}✓{Colors.NC} {audio_file.name} → {out_size} ({orig_size})")
        else:
            fail_count += 1
            print(f"\n    {Colors.DARK_GREEN}✗{Colors.NC} {audio_file.name} → Error")
    
    print()
    print_header("Conversión a 432Hz Completada")
    print()
    print(f"    {Colors.LIGHT_GREEN}╔════════════════════════════════════════════════════════╗{Colors.NC}")
    print(f"    {Colors.LIGHT_GREEN}║{Colors.NC}  {Colors.LIME}🎵 MÚSICA AHORA VIBRA EN FRECUENCIA UNIVERSAL 🎵{Colors.NC}        {Colors.LIGHT_GREEN}║{Colors.NC}")
    print(f"    {Colors.LIGHT_GREEN}╚════════════════════════════════════════════════════════╝{Colors.NC}")
    print()
    print(f"    {Colors.LIGHT_GREEN}Exitosos:{Colors.NC} {Colors.LIME}{success_count}{Colors.NC}")
    if skip_count > 0:
        print(f"    {Colors.YELLOW_GREEN}Saltados:{Colors.NC} {Colors.LIME}{skip_count}{Colors.NC}")
    if fail_count > 0:
        print(f"    {Colors.DARK_GREEN}Fallidos:{Colors.NC} {Colors.YELLOW_GREEN}{fail_count}{Colors.NC}")
    print(f"    {Colors.LIME}Formato:{Colors.NC}     {Colors.LIGHT_GREEN}{output_format.upper()}{Colors.NC}")
    print(f"    {Colors.LIME}Frecuencia:{Colors.NC} {Colors.LIGHT_GREEN}432Hz (frecuencia sanadora){Colors.NC}")
    print(f"    {Colors.LIME}Resolución:{Colors.NC}   {Colors.LIGHT_GREEN}{sr_display}/{output_bit_depth}-bit{Colors.NC}")
    print(f"    {Colors.LIME}Salida:{Colors.NC}")
    if output_dir.resolve() == source_dir.resolve():
        print(f"    {Colors.MEDIUM_GREEN}• Raíz del origen: carpeta{Colors.NC} {Colors.LIGHT_GREEN}masters{Colors.NC}")
        print(f"    {Colors.MEDIUM_GREEN}• Subdirectorios: carpeta{Colors.NC} {Colors.LIGHT_GREEN}{per_subdir_output_name}{Colors.NC} {Colors.MEDIUM_GREEN}en cada subdirectorio seleccionado{Colors.NC}")
    else:
        print(f"    {Colors.LIGHT_GREEN}{output_dir}/{Colors.NC}")
    for out_dir in sorted(created_output_dirs):
        print(f"    {Colors.MEDIUM_GREEN}• {out_dir}{Colors.NC}")
    return success_count > 0


def process_to_432hz_mp3(source_dir: Path, output_dir: Path):
    """
    Procesa archivos de audio convirtiéndolos a frecuencia 432Hz y exporta a MP3
    
    Args:
        source_dir: Directorio fuente donde están los archivos de audio
        output_dir: Directorio de destino donde se guardarán los archivos convertidos
    """
    output_dir.mkdir(parents=True, exist_ok=True)
    audio_files = select_audio_source_files(source_dir)
    if audio_files is None:
        print_warning("Conversión cancelada.")
        return False
    if not audio_files:
        print_error("No se encontraron archivos WAV/AIFF/FLAC para convertir a 432Hz MP3")
        return False
    
    print_header("Conversión a frecuencia 432Hz MP3 - Música Devocional")
    print()
    print(f"    {Colors.LIME}╔════════════════════════════════════════════════════════════╗{Colors.NC}")
    print(f"    {Colors.LIME}║{Colors.NC}  {Colors.YELLOW_GREEN}🕉️  CONVERSIÓN A 432Hz MP3 - FRECUENCIA SANADORA 🕉️{Colors.NC}      {Colors.LIME}║{Colors.NC}")
    print(f"    {Colors.LIME}╚════════════════════════════════════════════════════════════╝{Colors.NC}")
    print()
    print_info(f"Archivos encontrados: {len(audio_files)}")
    print()
    
    # Permitir al usuario seleccionar archivos
    selected_files = select_audio_files_for_432hz(audio_files)
    if selected_files is None:
        print_warning("Conversión cancelada.")
        return False
    
    if not selected_files:
        print_error("No se seleccionaron archivos para convertir.")
        return False
    
    print()
    
    # Preguntar si desea usar preset Ditto Pro
    print_header("Preset de Configuración")
    print()
    print(f"    {Colors.LIME}🎯 Preset Ditto Pro{Colors.NC}")
    print(f"    {Colors.MEDIUM_GREEN}Configuración optimizada para Ditto Music y distribución profesional:{Colors.NC}")
    print(f"    {Colors.LIGHT_GREEN}• Sample Rate: 48kHz (Máximo estándar MP3){Colors.NC}")
    print(f"    {Colors.LIGHT_GREEN}• Modo: CBR (Constant Bitrate){Colors.NC}")
    print(f"    {Colors.LIGHT_GREEN}• Bitrate: 320 kbps (se ajustará automáticamente si supera 200MB){Colors.NC}")
    print()
    print(f"    {Colors.YELLOW_GREEN}💡 Compatible con Ditto Music:{Colors.NC}")
    print(f"    {Colors.YELLOW_GREEN}   • Formato MP3 con metadatos ID3 correctos (MIME type: audio/mpeg){Colors.NC}")
    print(f"    {Colors.YELLOW_GREEN}   • Límite de 200MB: el bitrate se ajusta automáticamente{Colors.NC}")
    print(f"    {Colors.YELLOW_GREEN}   • Tamaño optimizado (~90MB vs ~700MB WAV){Colors.NC}")
    print()
    print(f"    {Colors.MEDIUM_GREEN}ℹ️  Nota: MP3 (libmp3lame) soporta máximo 48kHz según estándar{Colors.NC}")
    print()
    
    use_ditto_preset = confirm("¿Usar preset Ditto Pro? (configuración automática)")
    print()
    
    if use_ditto_preset:
        # Configuración automática Ditto Pro
        output_sample_rate = 48000  # Máximo soportado por libmp3lame
        bitrate_kbps = 320
        vbr_quality = None
        print_success("✅ Preset Ditto Pro seleccionado")
        print(f"    {Colors.LIME}Sample Rate:{Colors.NC} {Colors.LIGHT_GREEN}48kHz (Máximo estándar MP3){Colors.NC}")
        print(f"    {Colors.LIME}Modo:{Colors.NC} {Colors.LIGHT_GREEN}CBR 320kbps{Colors.NC}")
        print()
        if not confirm("¿Continuar con esta configuración?"):
            print_warning("Conversión cancelada.")
            return False
    else:
        # Configuración manual
        # Permitir al usuario seleccionar sample rate
        output_sample_rate = select_sample_rate_for_432hz_mp3()
        if output_sample_rate is None:
            print_warning("Conversión cancelada.")
            return False
        
        print()
        
        # Permitir al usuario seleccionar configuración de calidad MP3
        quality_config = select_mp3_quality_settings()
        if quality_config is None:
            print_warning("Conversión cancelada.")
            return False
        
        bitrate_kbps = quality_config.get('bitrate')
        vbr_quality = quality_config.get('vbr_quality')
    
    # Formatear sample rate para mostrar
    sr_display = "96kHz" if output_sample_rate == 96000 else ("48kHz" if output_sample_rate == 48000 else ("44.1kHz" if output_sample_rate == 44100 else ("192kHz" if output_sample_rate == 192000 else f"{output_sample_rate}Hz")))
    
    # Verificar tamaño estimado y ajustar bitrate si es necesario para Ditto (límite 200MB)
    DITTO_MAX_SIZE_MB = 200.0
    adjusted_bitrate = bitrate_kbps
    files_need_adjustment = []
    
    if bitrate_kbps:  # Solo ajustar si es CBR (no VBR)
        for audio_file in selected_files:
            duration = get_audio_duration(audio_file)
            if duration:
                estimated_size = estimate_mp3_output_size(duration, bitrate_kbps)
                if estimated_size > DITTO_MAX_SIZE_MB:
                    max_bitrate = calculate_max_bitrate_for_size(duration, DITTO_MAX_SIZE_MB)
                    if max_bitrate < bitrate_kbps:
                        adjusted_bitrate = min(adjusted_bitrate, max_bitrate)
                        files_need_adjustment.append((audio_file, estimated_size, max_bitrate))
    
    # Si algún archivo necesita ajuste, informar al usuario
    if files_need_adjustment and adjusted_bitrate != bitrate_kbps:
        print()
        print_warning(f"⚠️  Algunos archivos excederían el límite de 200MB de Ditto Music")
        print(f"    {Colors.MEDIUM_GREEN}Se ajustará el bitrate a {adjusted_bitrate}kbps para cumplir con el límite{Colors.NC}")
        print()
        for audio_file, estimated_size, max_bitrate in files_need_adjustment:
            print(f"    {Colors.YELLOW_GREEN}• {audio_file.name}{Colors.NC}")
            print(f"      {Colors.MEDIUM_GREEN}Tamaño estimado: {estimated_size:.1f}MB → Se usará bitrate: {max_bitrate}kbps{Colors.NC}")
        print()
        if not confirm(f"¿Ajustar bitrate a {adjusted_bitrate}kbps para cumplir con el límite de Ditto (200MB)?"):
            print_warning("Conversión cancelada.")
            return False
        bitrate_kbps = adjusted_bitrate
    
    print()
    
    # Mostrar tabla de estimaciones
    show_432hz_mp3_estimations(
        selected_files, output_sample_rate,
        bitrate_kbps=bitrate_kbps, vbr_quality=vbr_quality
    )
    
    print()
    quality_str = f"{bitrate_kbps}kbps (CBR)" if bitrate_kbps else f"VBR Quality {vbr_quality}"
    if not confirm(f"¿Convertir {len(selected_files)} archivo(s) a 432Hz MP3 con sample rate {sr_display} y calidad {quality_str}?"):
        print_warning("Conversión cancelada.")
        return False
    
    print()
    print_header("Iniciando conversión a 432Hz MP3")
    print(f"    {Colors.LIME}Resolución de salida:{Colors.NC} {Colors.LIGHT_GREEN}{sr_display}{Colors.NC}")
    print(f"    {Colors.LIME}Calidad:{Colors.NC} {Colors.LIGHT_GREEN}{quality_str}{Colors.NC}")
    if output_sample_rate > 48000:
        print_warning("⚠️  ADVERTENCIA: Sample rate > 48kHz NO es parte del estándar MP3")
        print_warning("Algunos reproductores pueden no reproducir estos archivos correctamente")
    print(f"    {Colors.MEDIUM_GREEN}💡 Presiona Ctrl+C en cualquier momento para cancelar{Colors.NC}")
    print()
    
    success_count = 0
    fail_count = 0
    skip_count = 0
    existing_files = []
    created_output_dirs = set()

    if output_dir.resolve() == source_dir.resolve():
        (source_dir / "masters").mkdir(parents=True, exist_ok=True)
    
    # Verificar archivos existentes antes de procesar
    for audio_file in selected_files:
        target_dir = resolve_output_dir_for_file(source_dir, output_dir, audio_file, "mp3")
        output_file = target_dir / f"{audio_file.stem}_432Hz.mp3"
        if output_file.exists():
            existing_files.append((audio_file, output_file))
    
    # Si hay archivos existentes, preguntar al usuario
    if existing_files:
        print()
        print_warning(f"⚠️  Se encontraron {len(existing_files)} archivo(s) que ya existen en el directorio de salida:")
        for audio_file, output_file in existing_files:
            existing_size = get_file_size(output_file)
            print(f"    {Colors.YELLOW_GREEN}• {output_file.name}{Colors.NC} ({existing_size}) - de {audio_file.name}")
        print()
        print(f"    {Colors.LIME}Opciones:{Colors.NC}")
        print(f"    {Colors.MEDIUM_GREEN}1) Sobrescribir archivos existentes{Colors.NC}")
        print(f"    {Colors.MEDIUM_GREEN}2) Saltar archivos existentes (mantener los actuales){Colors.NC}")
        print(f"    {Colors.MEDIUM_GREEN}3) Agregar sufijo único a archivos nuevos (evitar sobrescritura){Colors.NC}")
        print(f"    {Colors.MEDIUM_GREEN}4) Cancelar{Colors.NC}")
        print()
        
        overwrite_mode = None
        while overwrite_mode is None:
            try:
                choice = input(f"{Colors.YELLOW_GREEN}▶ Selecciona opción (1-4): {Colors.NC}").strip()
                if choice == "1":
                    overwrite_mode = "overwrite"
                    print()
                    print_warning("⚠️  Los archivos existentes serán SOBRESCRITOS")
                    if not confirm("¿Continuar con sobrescritura?"):
                        print_warning("Conversión cancelada.")
                        return False
                elif choice == "2":
                    overwrite_mode = "skip"
                    print()
                    print_info(f"Se saltarán {len(existing_files)} archivo(s) existente(s)")
                elif choice == "3":
                    overwrite_mode = "unique"
                    print()
                    print_info("Se agregará un sufijo único a los archivos nuevos para evitar sobrescritura")
                elif choice == "4":
                    print_warning("Conversión cancelada.")
                    return False
                else:
                    print_error("Opción inválida. Selecciona 1, 2, 3 o 4.")
            except (EOFError, KeyboardInterrupt):
                print_warning("Conversión cancelada.")
                return False
    else:
        overwrite_mode = "overwrite"  # Por defecto, sobrescribir si no hay conflictos
    
    print()
    
    for i, audio_file in enumerate(selected_files, 1):
        if INTERRUPTED:
            print_warning("Conversión interrumpida por el usuario")
            break
        
        target_dir = resolve_output_dir_for_file(source_dir, output_dir, audio_file, "mp3")
        target_dir.mkdir(parents=True, exist_ok=True)
        created_output_dirs.add(str(target_dir))
        output_file = target_dir / f"{audio_file.stem}_432Hz.mp3"
        
        # Verificar si el archivo ya existe y manejar según el modo seleccionado
        if output_file.exists() and overwrite_mode == "skip":
            skip_count += 1
            existing_size = get_file_size(output_file)
            print(f"\n    {Colors.YELLOW_GREEN}⊘{Colors.NC} {audio_file.name} → Saltado (ya existe: {existing_size})")
            continue
        elif output_file.exists() and overwrite_mode == "unique":
            # Agregar sufijo único basado en timestamp
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            output_file = target_dir / f"{audio_file.stem}_432Hz_{timestamp}.mp3"
            # Si aún existe (muy improbable), agregar un número incremental
            counter = 1
            while output_file.exists():
                output_file = target_dir / f"{audio_file.stem}_432Hz_{timestamp}_{counter}.mp3"
                counter += 1
        
        animated_progress_bar(i, len(selected_files), f"Convirtiendo: {audio_file.name[:25]}")
        
        if convert_to_432hz_mp3(audio_file, output_file, output_sample_rate,
                               bitrate_kbps=bitrate_kbps, vbr_quality=vbr_quality):
            success_count += 1
            orig_size = get_file_size(audio_file)
            out_size = get_file_size(output_file)
            print(f"\n    {Colors.LIGHT_GREEN}✓{Colors.NC} {audio_file.name} → {out_size} ({orig_size})")
        else:
            fail_count += 1
            print(f"\n    {Colors.DARK_GREEN}✗{Colors.NC} {audio_file.name} → Error")
    
    print()
    print_header("Conversión a 432Hz MP3 Completada")
    print()
    print(f"    {Colors.LIGHT_GREEN}╔════════════════════════════════════════════════════════╗{Colors.NC}")
    print(f"    {Colors.LIGHT_GREEN}║{Colors.NC}  {Colors.LIME}🎵 MÚSICA AHORA VIBRA EN FRECUENCIA UNIVERSAL 🎵{Colors.NC}        {Colors.LIGHT_GREEN}║{Colors.NC}")
    print(f"    {Colors.LIGHT_GREEN}╚════════════════════════════════════════════════════════╝{Colors.NC}")
    print()
    print(f"    {Colors.LIGHT_GREEN}Exitosos:{Colors.NC} {Colors.LIME}{success_count}{Colors.NC}")
    if skip_count > 0:
        print(f"    {Colors.YELLOW_GREEN}Saltados:{Colors.NC} {Colors.LIME}{skip_count}{Colors.NC}")
    if fail_count > 0:
        print(f"    {Colors.DARK_GREEN}Fallidos:{Colors.NC} {Colors.YELLOW_GREEN}{fail_count}{Colors.NC}")
    print(f"    {Colors.LIME}Formato:{Colors.NC}     {Colors.LIGHT_GREEN}MP3{Colors.NC}")
    print(f"    {Colors.LIME}Frecuencia:{Colors.NC} {Colors.LIGHT_GREEN}432Hz (frecuencia sanadora){Colors.NC}")
    print(f"    {Colors.LIME}Resolución:{Colors.NC}   {Colors.LIGHT_GREEN}{sr_display}{Colors.NC}")
    print(f"    {Colors.LIME}Calidad:{Colors.NC}     {Colors.LIGHT_GREEN}{quality_str}{Colors.NC}")
    if output_sample_rate > 48000:
        print(f"    {Colors.YELLOW_GREEN}⚠️  ADVERTENCIA:{Colors.NC} Sample rate > 48kHz NO es estándar MP3")
    print(f"    {Colors.LIME}Salida:{Colors.NC}")
    if output_dir.resolve() == source_dir.resolve():
        print(f"    {Colors.MEDIUM_GREEN}• Raíz del origen: carpeta{Colors.NC} {Colors.LIGHT_GREEN}masters{Colors.NC}")
        print(f"    {Colors.MEDIUM_GREEN}• Subdirectorios: carpeta{Colors.NC} {Colors.LIGHT_GREEN}mp3{Colors.NC} {Colors.MEDIUM_GREEN}en cada subdirectorio seleccionado{Colors.NC}")
    else:
        print(f"    {Colors.LIGHT_GREEN}{output_dir}/{Colors.NC}")
    for out_dir in sorted(created_output_dirs):
        print(f"    {Colors.MEDIUM_GREEN}• {out_dir}{Colors.NC}")
    return success_count > 0

# ============================================================================
# MENÚ INTERACTIVO
# ============================================================================

def show_menu():
    print()
    print(f"{Colors.DARK_FOREST}╔══════════════════════════════════════════════════════════════╗{Colors.NC}")
    print(f"{Colors.DARK_FOREST}║{Colors.NC}  {Colors.BOLD}{Colors.LIME}🎵 MENÚ DE CONVERSIÓN DE AUDIO/VIDEO{Colors.NC}                {Colors.DARK_FOREST}║{Colors.NC}")
    print(f"{Colors.DARK_FOREST}╚══════════════════════════════════════════════════════════════╝{Colors.NC}")
    print()
    print(f"  {Colors.LIME}1){Colors.NC} M4A → MP4   {Colors.MEDIUM_GREEN}(video con imagen para YouTube){Colors.NC}")
    print(f"  {Colors.LIME}2){Colors.NC} WAV → M4A   {Colors.MEDIUM_GREEN}(compresión AAC alta calidad){Colors.NC}")
    print(f"  {Colors.LIME}3){Colors.NC} FLAC → M4A  {Colors.MEDIUM_GREEN}(compresión AAC alta calidad){Colors.NC}")
    print()
    print(f"  {Colors.BOLD}{Colors.YELLOW_GREEN}4){Colors.NC} {Colors.YELLOW_GREEN}ÁLBUM → MP3 UNIFICADO{Colors.NC}  {Colors.LIGHT_GREEN}(para registro de derechos de autor){Colors.NC}")
    print(f"     {Colors.MEDIUM_GREEN}Une todos los archivos de audio en UN SOLO MP3{Colors.NC}")
    print()
    print(f"  {Colors.BOLD}{Colors.LIGHT_GREEN}5){Colors.NC} {Colors.LIGHT_GREEN}AUDIO → FLAC HI-RES{Colors.NC}  {Colors.LIME}(192kHz hi-res, admite MP3/M4A){Colors.NC}")
    print(f"     {Colors.MEDIUM_GREEN}Convierte WAV/AIFF/FLAC/MP3/M4A a FLAC sin pérdida{Colors.NC}")
    print()
    print(f"  {Colors.BOLD}{Colors.LIME}6){Colors.NC} {Colors.LIME}AUDIO → 432Hz{Colors.NC}  {Colors.YELLOW_GREEN}(frecuencia sanadora){Colors.NC}")
    print(f"     {Colors.MEDIUM_GREEN}Convierte audio a frecuencia universal 432Hz{Colors.NC}")
    print()
    print(f"  {Colors.BOLD}{Colors.YELLOW_GREEN}7){Colors.NC} {Colors.YELLOW_GREEN}AUDIO → MP3 432Hz{Colors.NC}  {Colors.LIME}(frecuencia sanadora en MP3){Colors.NC}")
    print(f"     {Colors.MEDIUM_GREEN}Convierte audio a frecuencia 432Hz y exporta a MP3{Colors.NC}")
    print()
    print(f"  {Colors.MEDIUM_GREEN}Entrada general en modos de audio: WAV, AIFF, FLAC (modo 5 también admite MP3 y M4A){Colors.NC}")
    print()
    print(f"  {Colors.DARK_FOREST}h){Colors.NC} Ayuda")
    print(f"  {Colors.DARK_FOREST}q){Colors.NC} Salir")
    print()
    try:
        choice = input(f"{Colors.LIME}▶ Selecciona una opción: {Colors.NC}").strip()
        return choice
    except (EOFError, KeyboardInterrupt):
        return 'q'


def show_help():
    help_text = """
╔══════════════════════════════════════════════════════════════════════════════╗
║                    SCRIPT DE CONVERSIÓN DE AUDIO/VIDEO                       ║
╚══════════════════════════════════════════════════════════════════════════════╝

USO:
    python3 06_audio_converter.py [opciones]

MODOS DE CONVERSIÓN:
    1) M4A → MP4
       Crea video con imagen estática para YouTube/streaming.
       Requiere imagen de portada (cover.png, cover.jpg, etc.).

    2) WAV → M4A
       Convierte audio fuente sin pérdida a AAC alta calidad.

    3) FLAC → M4A
       Convierte audio fuente sin pérdida a AAC alta calidad.

    4) ÁLBUM → MP3 UNIFICADO
       Une múltiples pistas en un solo MP3 (con silencios entre tracks).
       Pensado para registro de derechos de autor.

    5) AUDIO → FLAC HI-RES
       Entrada: WAV/AIFF/FLAC/MP3/M4A
       Salida: FLAC (preset recomendado: 192kHz)
       Incluye guía para seleccionar bit depth (16/24/32).

    6) AUDIO → 432Hz
       Convierte audio a 432Hz (música devocional/frecuencia sanadora).
       Salida configurable: WAV, WAV comprimido o FLAC.

    7) AUDIO → MP3 432Hz
       Convierte audio a 432Hz y exporta a MP3 con opciones de calidad.
       Incluye preset Ditto Pro (48kHz, CBR 320kbps con ajuste por tamaño).

DETALLE TÉCNICO MODO 5 (192kHz + BIT DEPTH):
    Sample rate y bit depth no son lo mismo:
    - Sample rate (Hz): cuántas muestras por segundo.
    - Bit depth: precisión de cada muestra.

    Diferencias de bit depth:
    - 16-bit: ~96 dB de rango dinámico, máxima compatibilidad.
    - 24-bit: ~144 dB de rango dinámico, estándar de producción/mastering.
    - 32-bit: mayor headroom para procesamiento interno.

    Ejemplo a 192kHz (estéreo, 10 segundos, sin compresión):
    - 16-bit @ 192kHz: ~7.3 MB
    - 24-bit @ 192kHz: ~11.0 MB
    - 32-bit @ 192kHz: ~14.6 MB

    Importante en este script:
    - Si pides 32-bit en FLAC, FFmpeg/FLAC termina generando FLAC efectivo
      a 24-bit en este flujo.
    - Convertir MP3/M4A a FLAC mejora archivo maestro/flujo de trabajo, pero
      no recupera información ya perdida por compresión con pérdida.

NOTAS GENERALES:
    - En modos de audio se listan WAV/AIFF/FLAC por defecto.
    - El modo 5 también incluye MP3 y M4A como fuente.
    - Presiona Ctrl+C para cancelar en cualquier momento.

EJEMPLOS:
    # Modo interactivo
    python3 06_audio_converter.py

    # Modo desde línea de comandos (próximamente)
"""
    print(help_text)

# ============================================================================
# PUNTO DE ENTRADA
# ============================================================================

def main():
    if not check_dependencies():
        sys.exit(1)
    while True:
        choice = show_menu()
        print()
        if choice == '1':
            folder = select_folder()
            if folder:
                output_dirname = input(f"{Colors.YELLOW_GREEN}Nombre del directorio de salida (Enter=converted_videos): {Colors.NC}").strip() or "converted_videos"
                process_m4a_to_mp4(folder, output_dirname)
        elif choice == '2':
            folder = select_folder()
            if folder:
                output_dirname = input(f"{Colors.YELLOW_GREEN}Nombre del directorio de salida (Enter=converted): {Colors.NC}").strip() or "converted"
                process_audio_to_m4a(folder, output_dirname)
        elif choice == '3':
            folder = select_folder()
            if folder:
                output_dirname = input(f"{Colors.YELLOW_GREEN}Nombre del directorio de salida (Enter=converted): {Colors.NC}").strip() or "converted"
                process_audio_to_m4a(folder, output_dirname)
        elif choice == '4':
            folder = select_folder()
            if folder:
                print()
                print(f"{Colors.LIME}═══ Configuración del Álbum Unificado ═══{Colors.NC}")
                print()
                silence_input = input(f"{Colors.YELLOW_GREEN}Segundos de silencio entre pistas (Enter=2): {Colors.NC}").strip()
                silence_duration = int(silence_input) if silence_input else 2
                album_input = input(f"{Colors.YELLOW_GREEN}Nombre del archivo MP3 (Enter=nombre de carpeta): {Colors.NC}").strip()
                album_name = album_input if album_input else ""
                bitrate_input = input(f"{Colors.YELLOW_GREEN}Bitrate MP3 (Enter=320k): {Colors.NC}").strip()
                mp3_bitrate = bitrate_input if bitrate_input else "320k"
                output_dirname = input(f"{Colors.YELLOW_GREEN}Nombre del directorio de salida (Enter=unified): {Colors.NC}").strip() or "unified"
                process_album_to_unified_mp3(folder, output_dirname, silence_duration, mp3_bitrate, album_name)
        elif choice == '5':
            folder = select_folder()
            if folder:
                print()
                print(f"{Colors.LIME}═══ Configuración FLAC Alta Resolución ═══{Colors.NC}")
                print()
                print(f"  {Colors.MEDIUM_GREEN}Sample rates disponibles:{Colors.NC}")
                print(f"    {Colors.LIGHT_GREEN}192000{Colors.NC} - 192kHz (Ultra Hi-Res, preset recomendado)")
                print(f"    {Colors.LIGHT_GREEN}96000{Colors.NC} - 96kHz (alta calidad, archivos grandes)")
                print(f"    {Colors.LIGHT_GREEN}48000{Colors.NC} - 48kHz (estudio profesional)")
                print(f"    {Colors.LIGHT_GREEN}44100{Colors.NC} - 44.1kHz (calidad CD)")
                print()
                sr_input = input(f"{Colors.YELLOW_GREEN}Sample rate (Enter=192000): {Colors.NC}").strip()
                sample_rate = int(sr_input) if sr_input else 192000
                print()
                print_bit_depth_guide(sample_rate)
                print(f"  {Colors.MEDIUM_GREEN}Bit depth disponibles para solicitud:{Colors.NC}")
                print(f"    {Colors.LIGHT_GREEN}32{Colors.NC} - Procesamiento s32 (FLAC final efectivo 24-bit con FFmpeg)")
                print(f"    {Colors.LIGHT_GREEN}24{Colors.NC} - FLAC estándar de alta resolución")
                print(f"    {Colors.LIGHT_GREEN}16{Colors.NC} - Compatibilidad máxima")
                print()
                bd_input = input(f"{Colors.YELLOW_GREEN}Bit depth - 32, 24 o 16 (Enter=32): {Colors.NC}").strip()
                bit_depth = int(bd_input) if bd_input else 32
                print()
                comp_input = input(f"{Colors.YELLOW_GREEN}Nivel compresión 0-12 (Enter=8): {Colors.NC}").strip()
                compression = int(comp_input) if comp_input else 8
                print()
                output_dirname = input(f"{Colors.YELLOW_GREEN}Nombre del directorio de salida (Enter=flac_hires): {Colors.NC}").strip() or "flac_hires"
                process_audio_to_flac(folder, output_dirname, sample_rate, bit_depth, compression)
        elif choice == '6':
            folder = select_folder()
            if folder:
                output_dir = select_output_folder(folder)
                if output_dir:
                    process_to_432hz(folder, output_dir)
        elif choice == '7':
            folder = select_folder()
            if folder:
                output_dir = select_output_folder(folder)
                if output_dir:
                    process_to_432hz_mp3(folder, output_dir)
        elif choice.lower() == 'h':
            show_help()
        elif choice.lower() == 'q':
            print_info("¡Hasta luego!")
            sys.exit(0)
        else:
            print_error(f"Opción inválida: {choice}")
        print()
        try:
            input(f"{Colors.MEDIUM_GREEN}Presiona Enter para continuar...{Colors.NC}")
        except (EOFError, KeyboardInterrupt):
            print()
            sys.exit(0)


if __name__ == "__main__":
    main()
