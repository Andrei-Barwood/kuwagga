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
FLAC_SAMPLE_RATE = 96000
FLAC_BIT_DEPTH = 24
FLAC_COMPRESSION = 8

# Variables globales
INTERRUPTED = False
TMP_FILES = []
TMP_DIRS = []

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
                                '-show_entries', 'stream=sample_rate,bits_per_sample,codec_name,bit_rate',
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
    if input_codec == 'flac' and input_sr and str(input_sr) == str(sample_rate):
        input_bd_norm = 24 if input_bd in [24, 32] else (input_bd or 24)
        target_bd_norm = 24 if bit_depth in [24, 32] else bit_depth
        if input_bd_norm == target_bd_norm:
            try:
                shutil.copy2(audio_file, output_file)
                if output_file.exists():
                    orig_size = get_file_size(audio_file)
                    out_size = get_file_size(output_file)
                    print_success(f"Copiado (sin re-codificación): {output_file.name}")
                    print(f"    {Colors.DARK_FOREST}{orig_size} → {out_size} | {input_sr}Hz/{input_bd}bit{Colors.NC}")
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
            print_success(f"Creado: {output_file.name}")
            print(f"    {Colors.DARK_FOREST}{orig_size} → {out_size} | {sample_rate}Hz/{bit_depth}bit{Colors.NC}")
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


def convert_to_432hz(input_file: Path, output_file: Path) -> bool:
    if not input_file.exists():
        print_error(f"El archivo no existe: {input_file}")
        return False
    info = get_audio_info(input_file)
    sample_rate = info.get('sample_rate')
    bit_depth = info.get('bit_depth', 24)
    if not sample_rate:
        print_error("No se pudo detectar el sample rate del archivo")
        return False
    sample_rate = int(sample_rate)
    sample_fmt = "s16" if bit_depth == 16 else "s32"
    print(f"    {Colors.MEDIUM_GREEN}🎵 Conversión a frecuencia universal 432Hz{Colors.NC}")
    print(f"    {Colors.DARK_FOREST}Sample Rate: {sample_rate}Hz | Bit Depth: {bit_depth}-bit{Colors.NC}")
    print(f"    {Colors.DARK_FOREST}Procesando: 440Hz → 432Hz (manteniendo duración){Colors.NC}")
    stop_event = threading.Event()
    messages = ["Ajustando frecuencia...", "Aplicando pitch shift...", "Re-muestreando audio...", "Casi listo..."]
    anim_thread = threading.Thread(target=animate_conversion, args=(input_file.name, stop_event, messages), daemon=True)
    anim_thread.start()
    try:
        cmd = ['ffmpeg', '-hide_banner', '-loglevel', 'warning', '-stats',
               '-i', str(input_file),
               '-af', f'asetrate={sample_rate}*432/440,aresample={sample_rate},atempo=440/432',
               '-c:a', 'flac', '-sample_fmt', sample_fmt,
               '-compression_level', str(FLAC_COMPRESSION), '-ar', str(sample_rate),
               '-y', str(output_file)]
        result = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        stop_event.set()
        anim_thread.join(timeout=0.5)
        print("\r\033[K", end='', flush=True, file=sys.stderr)
        if result.returncode == 0 and output_file.exists():
            orig_size = get_file_size(input_file)
            new_size = get_file_size(output_file)
            print_success(f"Conversión a 432Hz completada: {output_file.name}")
            print(f"    {Colors.DARK_FOREST}Tamaño: {orig_size} → {new_size}{Colors.NC}")
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


def process_audio_to_m4a(source_dir: Path, format_type: str, output_dirname: str = "converted",
                         quality_mode: str = QUALITY_MODE, vbr_quality: int = VBR_QUALITY,
                         cbr_bitrate: str = CBR_BITRATE):
    output_dir = source_dir / output_dirname
    output_dir.mkdir(exist_ok=True)
    extensions = ['.wav', '.WAV'] if format_type == 'wav' else ['.flac', '.FLAC']
    audio_files = []
    for ext in extensions:
        audio_files.extend(sorted(source_dir.glob(f"*{ext}")))
    if not audio_files:
        print_error(f"No se encontraron archivos {format_type.upper()} en esta carpeta.")
        return False
    print_header(f"Archivos {format_type.upper()} encontrados: {len(audio_files)}")
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
    print_header(f"Iniciando conversión {format_type.upper()} → M4A")
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
    audio_files = []
    for ext in ['.flac', '.FLAC', '.wav', '.WAV', '.m4a', '.M4A', '.mp3', '.MP3']:
        audio_files.extend(sorted(source_dir.glob(f"*{ext}")))
    if not audio_files:
        print_error("No se encontraron archivos de audio (FLAC/WAV/M4A/MP3) en esta carpeta.")
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
    audio_files = []
    for ext in ['.wav', '.WAV', '.m4a', '.M4A', '.mp3', '.MP3', '.aiff', '.AIF', '.aif', '.AIF',
                '.ogg', '.OGG', '.wma', '.WMA', '.opus', '.OPUS', '.flac', '.FLAC']:
        audio_files.extend(sorted(source_dir.glob(f"*{ext}")))
    if not audio_files:
        print_error("No se encontraron archivos de audio en esta carpeta.")
        print_info("Formatos soportados: WAV, M4A, MP3, AIFF, OGG, WMA, OPUS, FLAC")
        return False
    print_header(f"Archivos de audio encontrados: {len(audio_files)}")
    for f in audio_files:
        dur = get_audio_duration(f)
        info = get_audio_info(f)
        sr = info.get('sample_rate', '?')
        dur_fmt = format_duration(dur) if dur else "00:00"
        print(f"    {Colors.LIME}📄{Colors.NC} {Colors.LIGHT_GREEN}{f.name}{Colors.NC} {Colors.MEDIUM_GREEN}({dur_fmt}, {sr}Hz){Colors.NC}")
    print()
    sr_display = "96kHz" if sample_rate == 96000 else ("48kHz" if sample_rate == 48000 else ("44.1kHz" if sample_rate == 44100 else f"{sample_rate}Hz"))
    print_info("Configuración FLAC:")
    print(f"    {Colors.LIME}Sample Rate:{Colors.NC}    {Colors.LIGHT_GREEN}{sr_display}{Colors.NC}")
    print(f"    {Colors.LIME}Bit Depth:{Colors.NC}      {Colors.LIGHT_GREEN}{bit_depth}-bit{Colors.NC}")
    print(f"    {Colors.LIME}Compresión:{Colors.NC}     {Colors.LIGHT_GREEN}Nivel {compression}{Colors.NC}")
    print()
    if not confirm(f"¿Convertir {len(audio_files)} archivos a FLAC {sr_display}/{bit_depth}-bit?"):
        print_warning("Conversión cancelada.")
        return False
    print_header(f"Iniciando conversión a FLAC {sr_display}/{bit_depth}-bit")
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
    print(f"    {Colors.LIME}Formato:{Colors.NC}  {Colors.LIGHT_GREEN}FLAC {sr_display}/{bit_depth}-bit{Colors.NC}")
    print(f"    {Colors.LIME}Salida:{Colors.NC}   {Colors.LIGHT_GREEN}{output_dir}/{Colors.NC}")
    return success_count > 0


def process_to_432hz(source_dir: Path, output_dirname: str = "432hz"):
    output_dir = source_dir / output_dirname
    output_dir.mkdir(exist_ok=True)
    audio_files = []
    for ext in ['.flac', '.FLAC', '.wav', '.WAV', '.m4a', '.M4A', '.mp3', '.MP3']:
        audio_files.extend(sorted(source_dir.glob(f"*{ext}")))
    if not audio_files:
        print_error("No se encontraron archivos de audio para convertir a 432Hz")
        return False
    print_header("Conversión a frecuencia 432Hz - Música Devocional")
    print()
    print(f"    {Colors.LIME}╔════════════════════════════════════════════════════════════╗{Colors.NC}")
    print(f"    {Colors.LIME}║{Colors.NC}  {Colors.YELLOW_GREEN}🕉️  CONVERSIÓN A 432Hz - FRECUENCIA SANADORA 🕉️{Colors.NC}         {Colors.LIME}║{Colors.NC}")
    print(f"    {Colors.LIME}╚════════════════════════════════════════════════════════════╝{Colors.NC}")
    print()
    print_info(f"Archivos encontrados: {len(audio_files)}")
    for f in audio_files:
        dur = get_audio_duration(f)
        dur_fmt = format_duration(dur) if dur else "00:00"
        print(f"    {Colors.LIME}📄{Colors.NC} {Colors.LIGHT_GREEN}{f.name}{Colors.NC} {Colors.MEDIUM_GREEN}({dur_fmt}){Colors.NC}")
    print()
    if not confirm(f"¿Convertir {len(audio_files)} archivos a 432Hz?"):
        print_warning("Conversión cancelada.")
        return False
    success_count = 0
    fail_count = 0
    for i, audio_file in enumerate(audio_files, 1):
        if INTERRUPTED:
            print_warning("Conversión interrumpida por el usuario")
            break
        print(f"\n{Colors.BOLD}[{i}/{len(audio_files)}]{Colors.NC} {audio_file.name}")
        output_file = output_dir / f"{audio_file.stem}_432Hz.flac"
        if convert_to_432hz(audio_file, output_file):
            success_count += 1
        else:
            fail_count += 1
    print()
    print_header("Conversión a 432Hz Completada")
    print()
    print(f"    {Colors.LIGHT_GREEN}╔════════════════════════════════════════════════════════╗{Colors.NC}")
    print(f"    {Colors.LIGHT_GREEN}║{Colors.NC}  {Colors.LIME}🎵 MÚSICA AHORA VIBRA EN FRECUENCIA UNIVERSAL 🎵{Colors.NC}        {Colors.LIGHT_GREEN}║{Colors.NC}")
    print(f"    {Colors.LIGHT_GREEN}╚════════════════════════════════════════════════════════╝{Colors.NC}")
    print()
    print(f"    {Colors.LIGHT_GREEN}Exitosos:{Colors.NC} {Colors.LIME}{success_count}{Colors.NC}")
    if fail_count > 0:
        print(f"    {Colors.DARK_GREEN}Fallidos:{Colors.NC} {Colors.YELLOW_GREEN}{fail_count}{Colors.NC}")
    print(f"    {Colors.LIME}Frecuencia:{Colors.NC} {Colors.LIGHT_GREEN}432Hz (frecuencia sanadora){Colors.NC}")
    print(f"    {Colors.LIME}Salida:{Colors.NC}     {Colors.LIGHT_GREEN}{output_dir}/{Colors.NC}")
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
    print(f"  {Colors.BOLD}{Colors.LIGHT_GREEN}5){Colors.NC} {Colors.LIGHT_GREEN}AUDIO → FLAC HI-RES{Colors.NC}  {Colors.LIME}(96kHz/24-bit alta resolución){Colors.NC}")
    print(f"     {Colors.MEDIUM_GREEN}Convierte cualquier audio a FLAC sin pérdida{Colors.NC}")
    print()
    print(f"  {Colors.BOLD}{Colors.LIME}6){Colors.NC} {Colors.LIME}AUDIO → 432Hz{Colors.NC}  {Colors.YELLOW_GREEN}(frecuencia sanadora){Colors.NC}")
    print(f"     {Colors.MEDIUM_GREEN}Convierte audio a frecuencia universal 432Hz{Colors.NC}")
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
    1) M4A → MP4        Crea video con imagen estática (requiere cover.png)
    2) WAV → M4A        Comprime WAV a AAC de alta calidad
    3) FLAC → M4A       Convierte FLAC a AAC
    4) ÁLBUM → MP3      Une todos los FLAC/WAV/M4A en UN SOLO MP3
                        (Para registro de derechos de autor)
    5) AUDIO → FLAC     Convierte cualquier audio a FLAC 96kHz/24-bit
                        (Alta resolución para producción/archivo)
    6) AUDIO → 432Hz    Convierte audio a frecuencia universal 432Hz
                        (Frecuencia sanadora para música devocional)

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
                process_audio_to_m4a(folder, 'wav', output_dirname)
        elif choice == '3':
            folder = select_folder()
            if folder:
                output_dirname = input(f"{Colors.YELLOW_GREEN}Nombre del directorio de salida (Enter=converted): {Colors.NC}").strip() or "converted"
                process_audio_to_m4a(folder, 'flac', output_dirname)
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
                print(f"    {Colors.LIGHT_GREEN}96000{Colors.NC} - 96kHz (máxima calidad, archivos grandes)")
                print(f"    {Colors.LIGHT_GREEN}48000{Colors.NC} - 48kHz (estudio profesional)")
                print(f"    {Colors.LIGHT_GREEN}44100{Colors.NC} - 44.1kHz (calidad CD)")
                print()
                sr_input = input(f"{Colors.YELLOW_GREEN}Sample rate (Enter=96000): {Colors.NC}").strip()
                sample_rate = int(sr_input) if sr_input else 96000
                print()
                bd_input = input(f"{Colors.YELLOW_GREEN}Bit depth - 24 o 16 (Enter=24): {Colors.NC}").strip()
                bit_depth = int(bd_input) if bd_input else 24
                print()
                comp_input = input(f"{Colors.YELLOW_GREEN}Nivel compresión 0-12 (Enter=8): {Colors.NC}").strip()
                compression = int(comp_input) if comp_input else 8
                print()
                output_dirname = input(f"{Colors.YELLOW_GREEN}Nombre del directorio de salida (Enter=flac_hires): {Colors.NC}").strip() or "flac_hires"
                process_audio_to_flac(folder, output_dirname, sample_rate, bit_depth, compression)
        elif choice == '6':
            folder = select_folder()
            if folder:
                output_dirname = input(f"{Colors.YELLOW_GREEN}Nombre del directorio de salida (Enter=432hz): {Colors.NC}").strip() or "432hz"
                process_to_432hz(folder, output_dirname)
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


