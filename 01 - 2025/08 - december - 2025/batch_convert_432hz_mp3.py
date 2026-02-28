#!/usr/bin/env python3
"""
Script de automatización para conversión masiva a MP3 432Hz usando preset Ditto Pro
Procesa todos los subdirectorios de audio excluyendo '2022'
"""

import os
import sys
import subprocess
import time
import threading
from pathlib import Path
from datetime import datetime
from typing import List, Optional
import signal

# ============================================================================
# CONFIGURACIÓN
# ============================================================================

SOURCE_BASE = "/Volumes/TOSHIBA EXT/2026/00 - bakcup spektra/Kirtan Teg Singh/discography"
DEST_BASE = "/Volumes/Backup II - mid 2025/2026/01 - Kirtant Teg Singh"
EXCLUDE_DIR = "2022"
PYTHON_SCRIPT = "06_audio_converter.py"

# Obtener la ruta absoluta del script Python (está en el mismo directorio que este script)
SCRIPT_DIR = Path(__file__).parent.absolute()
PYTHON_SCRIPT_PATH = SCRIPT_DIR / PYTHON_SCRIPT

# Colores para output
class Colors:
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    RED = '\033[0;31m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'  # No Color

# ============================================================================
# FUNCIONES
# ============================================================================

def print_header(msg: str):
    print()
    print(f"{Colors.BLUE}{'=' * 64}{Colors.NC}")
    print(f"{Colors.BLUE}  {msg}{Colors.NC}")
    print(f"{Colors.BLUE}{'=' * 64}{Colors.NC}")
    print()

def print_info(msg: str):
    print(f"{Colors.GREEN}ℹ{Colors.NC}  {msg}")

def print_success(msg: str):
    print(f"{Colors.GREEN}✓{Colors.NC}  {msg}")

def print_error(msg: str):
    print(f"{Colors.RED}✗{Colors.NC}  {msg}", file=sys.stderr)

def print_warning(msg: str):
    print(f"{Colors.YELLOW}⚠{Colors.NC}  {msg}")

def check_python_script() -> bool:
    """Verificar que el script Python existe"""
    if not PYTHON_SCRIPT_PATH.exists():
        print_error(f"No se encontró el script Python: {PYTHON_SCRIPT_PATH}")
        return False
    print_success(f"Script Python encontrado: {PYTHON_SCRIPT_PATH}")
    return True

def check_paths() -> bool:
    """Verificar que las rutas base existen"""
    source_path = Path(SOURCE_BASE)
    if not source_path.exists():
        print_error(f"El directorio fuente no existe: {SOURCE_BASE}")
        return False
    
    dest_path = Path(DEST_BASE)
    if not dest_path.exists():
        print_warning("El directorio destino no existe. Creándolo...")
        try:
            dest_path.mkdir(parents=True, exist_ok=True)
            print_success(f"Directorio destino creado: {DEST_BASE}")
        except Exception as e:
            print_error(f"No se pudo crear el directorio destino: {DEST_BASE}")
            print_error(f"Error: {e}")
            return False
    
    return True

def check_pexpect() -> bool:
    """Verificar que pexpect está instalado"""
    try:
        import pexpect
        return True
    except ImportError:
        print_error("pexpect no está instalado. Instálalo con: pip install pexpect")
        return False

def count_audio_files(directory: Path) -> int:
    """Contar archivos de audio en un directorio"""
    extensions = ['.flac', '.FLAC', '.wav', '.WAV', '.m4a', '.M4A', '.mp3', '.MP3']
    count = 0
    for ext in extensions:
        count += len(list(directory.glob(f"*{ext}")))
    return count

class ProgressSpinner:
    """Animación de progreso mientras se procesa"""
    def __init__(self, message="Procesando"):
        self.message = message
        self.spinner_chars = ['🎵', '🎶', '🎸', '🎹', '🎺', '🎷', '🥁', '🎻']
        self.spinner_index = 0
        self.running = False
        self.thread = None
        self.current_status = ""
    
    def _animate(self):
        """Función de animación en segundo plano"""
        while self.running:
            spinner = self.spinner_chars[self.spinner_index % len(self.spinner_chars)]
            status = f"{spinner} {self.message} {self.current_status}"
            print(f"\r{Colors.YELLOW}{status}{Colors.NC}", end='', flush=True)
            self.spinner_index += 1
            time.sleep(0.3)
    
    def start(self, status=""):
        """Iniciar la animación"""
        self.running = True
        self.current_status = status
        self.thread = threading.Thread(target=self._animate, daemon=True)
        self.thread.start()
    
    def update(self, status=""):
        """Actualizar el mensaje de estado"""
        self.current_status = status
    
    def stop(self):
        """Detener la animación"""
        self.running = False
        if self.thread:
            self.thread.join(timeout=0.5)
        print("\r" + " " * 80 + "\r", end='', flush=True)  # Limpiar línea

def process_directory(source_dir: Path, dest_dir: Path, dir_name: str) -> bool:
    """
    Procesar un directorio individual usando pexpect para automatizar la interacción
    """
    # Reemplazar espacios y caracteres problemáticos en el nombre del log
    safe_dir_name = dir_name.replace('/', '_').replace(' ', '_').replace('-', '_')
    log_file = Path(f"/tmp/batch_convert_{safe_dir_name}_{os.getpid()}.log")
    start_time = time.time()
    
    print_header(f"Procesando: {dir_name}")
    print_info(f"Origen: {source_dir}")
    print_info(f"Destino: {dest_dir}")
    print_info(f"Log: {log_file}")
    print()
    
    # Crear directorio de destino si no existe
    try:
        dest_dir.mkdir(parents=True, exist_ok=True)
    except Exception as e:
        print_error(f"No se pudo crear el directorio destino: {dest_dir}")
        print_error(f"Error: {e}")
        return False
    
    # Contar archivos de audio
    audio_count = count_audio_files(source_dir)
    if audio_count == 0:
        print_warning(f"No se encontraron archivos de audio en: {dir_name}")
        return False
    print_info(f"Archivos de audio encontrados: {audio_count}")
    print()
    
    # Importar pexpect
    try:
        import pexpect
    except ImportError:
        print_error("pexpect no está disponible")
        return False
    
    # Abrir log file
    log_fd = open(log_file, 'w', encoding='utf-8')
    log_fd.write(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] Iniciando procesamiento de: {dir_name}\n")
    log_fd.write(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] Origen: {source_dir}\n")
    log_fd.write(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] Destino: {dest_dir}\n\n")
    log_fd.flush()
    
    # Iniciar el proceso Python
    print_info("Iniciando conversión... (ver progreso en: {})".format(log_file))
    
    # Iniciar spinner de progreso
    spinner = ProgressSpinner("Iniciando conversión")
    spinner.start()
    
    try:
        # Spawn del proceso Python
        spinner.update("Iniciando script Python...")
        log_fd.write(f"PROGRESO: Ejecutando: python3 {PYTHON_SCRIPT_PATH}\n")
        log_fd.write(f"PROGRESO: Script existe: {PYTHON_SCRIPT_PATH.exists()}\n")
        log_fd.flush()
        
        # Verificar que el script existe
        if not PYTHON_SCRIPT_PATH.exists():
            spinner.stop()
            log_fd.write(f"ERROR: El script Python no existe: {PYTHON_SCRIPT_PATH}\n")
            log_fd.flush()
            print_error(f"El script Python no existe: {PYTHON_SCRIPT_PATH}")
            return False
        
        # Crear spawn con mejor configuración
        # Usar env TERM=dumb para deshabilitar códigos ANSI problemáticos
        # Aumentar maxread para capturar más salida
        env = os.environ.copy()
        env['TERM'] = 'dumb'  # Deshabilitar códigos ANSI problemáticos
        
        child = pexpect.spawn(
            f'python3 "{PYTHON_SCRIPT_PATH}"',
            encoding='utf-8',
            timeout=600,
            logfile=log_fd,
            echo=False,
            env=env,
            maxread=2000  # Aumentar buffer para capturar más salida
        )
        
        log_fd.write(f"PROGRESO: Proceso iniciado, PID: {child.pid}\n")
        log_fd.flush()
        
        # Esperar un momento para que el proceso inicie
        time.sleep(2)
        
        # Verificar que el proceso sigue vivo
        if not child.isalive():
            spinner.stop()
            log_fd.write(f"ERROR: El proceso terminó inmediatamente. Exit status: {child.exitstatus}\n")
            log_fd.flush()
            print_error("El proceso Python terminó inmediatamente. Revisa el log.")
            return False
        
        # Esperar menú principal y seleccionar opción 7
        spinner.update("Esperando menú principal...")
        log_fd.write("PROGRESO: Esperando menú principal...\n")
        log_fd.flush()
        
        # Leer lo que hay disponible primero
        try:
            child.expect("Selecciona una opción:", timeout=30)
            log_fd.write("PROGRESO: Menú principal detectado\n")
            log_fd.flush()
        except pexpect.TIMEOUT:
            # Ver qué hay en el buffer
            buffer_content = child.before if hasattr(child, 'before') else "N/A"
            log_fd.write(f"ERROR: Timeout esperando menú.\n")
            log_fd.write(f"Buffer recibido (últimos 500 chars): {buffer_content[-500:]}\n")
            log_fd.write(f"Proceso vivo: {child.isalive()}\n")
            if not child.isalive():
                log_fd.write(f"Exit status: {child.exitstatus}\n")
            log_fd.flush()
            spinner.stop()
            print_error("Timeout esperando menú principal. Revisa el log para ver qué recibió.")
            return False
        except pexpect.EOF:
            log_fd.write(f"ERROR: El proceso terminó (EOF). Exit status: {child.exitstatus}\n")
            log_fd.flush()
            spinner.stop()
            print_error("El proceso terminó antes de mostrar el menú. Revisa el log.")
            return False
        
        log_fd.write("PROGRESO: Seleccionando opción 7 (MP3 432Hz)\n")
        log_fd.flush()
        spinner.update("Seleccionando opción 7...")
        child.sendline("7")
        log_fd.write("PROGRESO: Opción 7 enviada\n")
        log_fd.flush()
        time.sleep(1)  # Pausa después de enviar
        
        # Seleccionar carpeta fuente
        spinner.update("Seleccionando carpeta fuente...")
        log_fd.write("PROGRESO: Esperando prompt de carpeta fuente...\n")
        log_fd.flush()
        
        try:
            child.expect("Pega la ruta de la carpeta", timeout=30)
        except pexpect.TIMEOUT:
            log_fd.write(f"ERROR: Timeout esperando prompt de carpeta. Buffer: {child.before[-200:]}\n")
            log_fd.flush()
            spinner.stop()
            print_error("Timeout esperando prompt de carpeta fuente. Revisa el log.")
            return False
        
        log_fd.write(f"PROGRESO: Enviando ruta de carpeta fuente: {source_dir}\n")
        log_fd.flush()
        child.sendline(str(source_dir))
        time.sleep(0.5)
        
        # Esperar confirmación de carpeta fuente
        spinner.update("Verificando carpeta fuente...")
        log_fd.write("PROGRESO: Esperando confirmación de carpeta fuente...\n")
        log_fd.flush()
        
        try:
            child.expect(["Carpeta seleccionada:", "Operación cancelada"], timeout=30)
        except pexpect.TIMEOUT:
            log_fd.write(f"ERROR: Timeout esperando confirmación. Buffer: {child.before[-200:]}\n")
            log_fd.flush()
            spinner.stop()
            print_error("Timeout esperando confirmación de carpeta. Revisa el log.")
            return False
        
        if "Operación cancelada" in child.after:
            spinner.stop()
            log_fd.write("ERROR: Operación cancelada al seleccionar carpeta fuente\n")
            log_fd.flush()
            return False
        
        # Seleccionar carpeta destino
        spinner.update("Seleccionando carpeta destino...")
        log_fd.write("PROGRESO: Esperando prompt de carpeta destino...\n")
        log_fd.flush()
        
        try:
            child.expect("Pega la ruta de la carpeta de destino", timeout=30)
        except pexpect.TIMEOUT:
            log_fd.write(f"ERROR: Timeout esperando prompt de destino. Buffer: {child.before[-200:]}\n")
            log_fd.flush()
            spinner.stop()
            print_error("Timeout esperando prompt de carpeta destino. Revisa el log.")
            return False
        
        log_fd.write(f"PROGRESO: Enviando ruta de carpeta destino: {dest_dir}\n")
        log_fd.flush()
        child.sendline(str(dest_dir))
        time.sleep(0.5)
        
        # Esperar confirmación de carpeta destino
        spinner.update("Verificando carpeta destino...")
        log_fd.write("PROGRESO: Esperando confirmación de carpeta destino...\n")
        log_fd.flush()
        
        try:
            child.expect(["Carpeta de destino seleccionada:", "Usando directorio actual:"], timeout=30)
        except pexpect.TIMEOUT:
            log_fd.write(f"ERROR: Timeout esperando confirmación de destino. Buffer: {child.before[-200:]}\n")
            log_fd.flush()
            spinner.stop()
            print_error("Timeout esperando confirmación de carpeta destino. Revisa el log.")
            return False
        
        # Seleccionar archivos (Enter para todos)
        spinner.update("Seleccionando archivos...")
        log_fd.write("PROGRESO: Esperando selección de archivos...\n")
        log_fd.flush()
        
        # El prompt real es: "▶ Selecciona archivo(s) (1-X, separados por comas) o Enter para todos:"
        # Tiene códigos ANSI, así que buscamos "Enter para todos" que aparece al final del prompt
        try:
            # Buscar "Enter para todos" que es parte del prompt y no tiene códigos ANSI problemáticos
            # O buscar el símbolo ▶ seguido de texto
            index = child.expect([
                "Enter para todos:",
                "Enter para todos",
                "o Enter para todos:",
                "o Enter para todos",
                "Selecciona archivo",
                "▶ Selecciona"
            ], timeout=30)
            log_fd.write(f"PROGRESO: Prompt detectado (índice {index})\n")
            log_fd.flush()
            
            # Si detectamos el prompt, esperar un momento para que termine de mostrarse
            time.sleep(0.5)
            
        except pexpect.TIMEOUT:
            # Intentar leer lo que hay disponible
            if hasattr(child, 'before'):
                buffer_content = child.before[-1000:] if len(child.before) > 1000 else child.before
                log_fd.write(f"ERROR: Timeout esperando selección de archivos.\n")
                log_fd.write(f"Buffer recibido (últimos 1000 chars):\n{buffer_content}\n")
            log_fd.flush()
            spinner.stop()
            print_error("Timeout esperando selección de archivos. Revisa el log.")
            return False
        
        log_fd.write("PROGRESO: Prompt de selección detectado, enviando Enter...\n")
        log_fd.flush()
        child.sendline("")  # Enter para todos
        time.sleep(2)  # Pausa más larga para que procese
        
        # Esperar confirmación de archivos
        spinner.update("Verificando archivos seleccionados...")
        log_fd.write("PROGRESO: Esperando confirmación de archivos...\n")
        log_fd.flush()
        
        try:
            index = child.expect([
                "Procesando todos los archivos",
                "Archivos seleccionados:",
                "Procesando todos",
                "todos los archivos",
                "Procesando"
            ], timeout=30)
            log_fd.write(f"PROGRESO: Confirmación recibida (índice {index})\n")
            log_fd.flush()
        except pexpect.TIMEOUT:
            if hasattr(child, 'before'):
                buffer_content = child.before[-1000:] if len(child.before) > 1000 else child.before
                log_fd.write(f"ERROR: Timeout esperando confirmación de archivos.\n")
                log_fd.write(f"Buffer recibido (últimos 1000 chars):\n{buffer_content}\n")
            log_fd.flush()
            spinner.stop()
            print_error("Timeout esperando confirmación de archivos. Revisa el log.")
            return False
        
        # Usar preset Ditto Pro
        spinner.update("Configurando preset Ditto Pro...")
        log_fd.write("PROGRESO: Esperando pregunta de preset Ditto Pro...\n")
        log_fd.flush()
        
        try:
            child.expect("¿Usar preset Ditto Pro?", timeout=30)
        except pexpect.TIMEOUT:
            log_fd.write(f"ERROR: Timeout esperando preset. Buffer: {child.before[-200:]}\n")
            log_fd.flush()
            spinner.stop()
            print_error("Timeout esperando preset Ditto Pro. Revisa el log.")
            return False
        
        log_fd.write("PROGRESO: Seleccionando preset Ditto Pro\n")
        log_fd.flush()
        child.sendline("s")
        time.sleep(0.5)
        
        # Esperar confirmación de preset
        spinner.update("Aplicando preset...")
        log_fd.write("PROGRESO: Esperando confirmación de preset...\n")
        log_fd.flush()
        
        try:
            child.expect("Preset Ditto Pro seleccionado", timeout=30)
        except pexpect.TIMEOUT:
            log_fd.write(f"ERROR: Timeout esperando confirmación de preset. Buffer: {child.before[-200:]}\n")
            log_fd.flush()
            spinner.stop()
            print_error("Timeout esperando confirmación de preset. Revisa el log.")
            return False
        
        # Confirmar configuración del preset
        spinner.update("Confirmando configuración...")
        log_fd.write("PROGRESO: Esperando confirmación de configuración...\n")
        log_fd.flush()
        
        try:
            child.expect("¿Continuar con esta configuración?", timeout=30)
        except pexpect.TIMEOUT:
            log_fd.write(f"ERROR: Timeout esperando confirmación de configuración. Buffer: {child.before[-200:]}\n")
            log_fd.flush()
            spinner.stop()
            print_error("Timeout esperando confirmación de configuración. Revisa el log.")
            return False
        
        child.sendline("s")
        time.sleep(0.5)
        
        # Manejar archivos existentes si aparecen
        spinner.update("Verificando archivos existentes...")
        log_fd.write("PROGRESO: Esperando confirmación final o archivos existentes...\n")
        log_fd.flush()
        
        try:
            index = child.expect(
                ["Se encontraron", "¿Convertir"],
                timeout=30
            )
            if index == 0:  # Archivos existentes detectados
                log_fd.write("PROGRESO: Archivos existentes detectados\n")
                log_fd.flush()
                spinner.update("Manejando archivos existentes (sobrescribir)...")
                
                # ESTRATEGIA ALTERNATIVA: No intentar detectar el prompt específico
                # El prompt tiene códigos ANSI que pueden interferir con pexpect
                # Simplemente esperar un tiempo razonable y enviar "1" directamente
                
                # Log del buffer actual para debugging
                if hasattr(child, 'before'):
                    buffer_content = child.before[-1000:] if len(child.before) > 1000 else child.before
                    log_fd.write(f"PROGRESO: Buffer antes de enviar opción 1 (últimos 1000 chars):\n{buffer_content}\n")
                    log_fd.flush()
                
                # Esperar tiempo suficiente para que el prompt aparezca (3 segundos)
                log_fd.write("PROGRESO: Esperando que aparezca el prompt de selección...\n")
                log_fd.flush()
                time.sleep(3)
                
                # Enviar "1" directamente para sobrescribir
                # No intentamos detectar el prompt porque tiene códigos ANSI problemáticos
                log_fd.write("PROGRESO: Enviando opción 1 (sobrescribir archivos existentes) sin esperar prompt\n")
                log_fd.flush()
                child.sendline("1")
                time.sleep(2)  # Pausa para que procese la selección
                
                # Esperar confirmación de sobrescritura o continuación
                # Según el código del script Python, después de seleccionar "1":
                # 1. Imprime: "⚠️  Los archivos existentes serán SOBRESCRITOS"
                # 2. Pregunta: "¿Continuar con sobrescritura?"
                log_fd.write("PROGRESO: Esperando confirmación de sobrescritura...\n")
                log_fd.flush()
                
                # Log del buffer antes del expect
                if hasattr(child, 'before'):
                    buffer_before = child.before[-1000:] if len(child.before) > 1000 else child.before
                    log_fd.write(f"PROGRESO: Buffer antes de esperar confirmación (últimos 1000 chars):\n{buffer_before}\n")
                    log_fd.flush()
                
                try:
                    # Buscar patrones más flexibles que ignoren códigos ANSI
                    # Usar solo el texto sin emojis ni códigos de color
                    index = child.expect([
                        "Continuar con sobrescritura",  # Sin el ¿ inicial (puede tener códigos ANSI)
                        "archivos existentes serán SOBRESCRITOS",  # Texto clave sin emoji
                        "¿Continuar con sobrescritura?",  # Con signo de interrogación
                        "Los archivos existentes serán SOBRESCRITOS",  # Sin emoji
                        "Convirtiendo:",  # Ya está en conversión
                        "Iniciando conversión"  # Ya está en conversión
                    ], timeout=30)
                    
                    log_fd.write(f"PROGRESO: Respuesta recibida después de seleccionar opción 1 (índice {index})\n")
                    log_fd.flush()
                    
                    if index == 0 or index == 2:  # Pide confirmación de sobrescritura
                        log_fd.write("PROGRESO: Confirmando sobrescritura...\n")
                        log_fd.flush()
                        child.sendline("s")
                        time.sleep(1.5)
                        # Esperar que continúe a la conversión
                        try:
                            child.expect(["Convirtiendo:", "Iniciando conversión", "¿Convertir"], timeout=30)
                            log_fd.write("PROGRESO: Confirmación procesada, continuando con conversión\n")
                            log_fd.flush()
                        except pexpect.TIMEOUT:
                            log_fd.write("PROGRESO: Timeout esperando continuación después de confirmación\n")
                            log_fd.flush()
                    elif index == 1 or index == 3:  # Muestra advertencia, esperar confirmación
                        log_fd.write("PROGRESO: Advertencia detectada, esperando prompt de confirmación...\n")
                        log_fd.flush()
                        time.sleep(1)
                        try:
                            child.expect("Continuar", timeout=10)
                            log_fd.write("PROGRESO: Confirmando sobrescritura...\n")
                            log_fd.flush()
                            child.sendline("s")
                            time.sleep(1.5)
                        except pexpect.TIMEOUT:
                            log_fd.write("PROGRESO: No se encontró prompt de confirmación, continuando...\n")
                            log_fd.flush()
                    # Si index es 4 o 5, ya está en la conversión, continuar
                    elif index == 4 or index == 5:
                        log_fd.write("PROGRESO: Ya está en proceso de conversión\n")
                        log_fd.flush()
                    
                except pexpect.TIMEOUT:
                    # Puede que no pida confirmación o que ya esté en conversión
                    log_fd.write("PROGRESO: Timeout esperando confirmación de sobrescritura\n")
                    if hasattr(child, 'before'):
                        buffer_content = child.before[-1000:] if len(child.before) > 1000 else child.before
                        log_fd.write(f"PROGRESO: Buffer actual (últimos 1000 chars):\n{buffer_content}\n")
                    log_fd.flush()
                    # Continuar de todas formas, puede que ya esté en conversión
                
                # Si llegamos aquí, los archivos existentes fueron manejados
                # Continuar esperando la conversión
                log_fd.write("PROGRESO: Archivos existentes manejados, continuando...\n")
                log_fd.flush()
                
        except pexpect.TIMEOUT:
            # No hay archivos existentes, continuar
            log_fd.write("PROGRESO: No hay archivos existentes, continuando...\n")
            log_fd.flush()
        
        # Confirmar conversión (solo si no se confirmó antes por archivos existentes)
        # Verificar si ya estamos en conversión antes de enviar confirmación
        spinner.update("Verificando estado de conversión...")
        log_fd.write("PROGRESO: Verificando si necesita confirmación de conversión...\n")
        log_fd.flush()
        
        # Log del buffer actual
        if hasattr(child, 'before'):
            buffer_before = child.before[-1000:] if len(child.before) > 1000 else child.before
            log_fd.write(f"PROGRESO: Buffer antes de verificar confirmación (últimos 1000 chars):\n{buffer_before}\n")
            log_fd.flush()
        
        # Esperar un momento para que aparezca el prompt
        time.sleep(1)
        
        try:
            # Intentar detectar si ya estamos en conversión o necesitamos confirmar
            # Buscar patrones más flexibles que ignoren códigos ANSI
            index = child.expect([
                "Convertir.*archivo.*a 432Hz MP3",  # Patrón más específico sin ¿
                "¿Convertir",  # Con signo de interrogación
                "Convirtiendo:",
                "Iniciando conversión",
                "Conversión a 432Hz MP3 Completada"
            ], timeout=10)  # Aumentar timeout a 10 segundos
            
            if index == 0 or index == 1:  # Necesita confirmación
                spinner.update("Confirmando conversión...")
                log_fd.write("PROGRESO: Confirmando conversión\n")
                log_fd.flush()
                child.sendline("s")
                time.sleep(2)  # Dar más tiempo para que procese
            else:
                log_fd.write(f"PROGRESO: Ya en proceso de conversión o completada (índice {index})\n")
                log_fd.flush()
        except pexpect.TIMEOUT:
            # Si hay timeout, verificar el buffer para ver qué hay
            if hasattr(child, 'before'):
                buffer_after = child.before[-500:] if len(child.before) > 500 else child.before
                log_fd.write(f"PROGRESO: Timeout verificando confirmación. Buffer (últimos 500 chars):\n{buffer_after}\n")
                log_fd.flush()
                # Si el buffer contiene "Convertir", intentar enviar "s" de todas formas
                if "Convertir" in buffer_after or "convertir" in buffer_after.lower():
                    log_fd.write("PROGRESO: Detectado 'Convertir' en buffer, enviando confirmación...\n")
                    log_fd.flush()
                    child.sendline("s")
                    time.sleep(2)
                else:
                    log_fd.write("PROGRESO: Continuando con conversión (no se necesita confirmación adicional)\n")
                    log_fd.flush()
            else:
                log_fd.write("PROGRESO: Continuando con conversión (no se necesita confirmación adicional)\n")
                log_fd.flush()
        
        # Esperar a que termine la conversión
        # Esto puede tardar mucho, así que esperamos con timeout largo
        spinner.update("Iniciando conversión de audio...")
        log_fd.write("PROGRESO: Esperando finalización de conversión...\n")
        log_fd.flush()
        
        # Esperar mensajes de progreso o finalización
        file_count = 0
        while True:
            try:
                index = child.expect(
                    [
                        "Conversión a 432Hz MP3 Completada",
                        "Exitosos:",
                        "Convirtiendo:",
                        "✓",
                        "✗",
                        "Presiona Enter para continuar"
                    ],
                    timeout=300  # 5 minutos de timeout para cada expect
                )
                
                if index == 0 or index == 1:  # Conversión completada
                    spinner.update("Conversión completada!")
                    log_fd.write("PROGRESO: Conversión completada\n")
                    log_fd.flush()
                    time.sleep(0.5)  # Mostrar mensaje final brevemente
                    break
                elif index == 2:  # Convirtiendo archivo
                    file_count += 1
                    spinner.update(f"Convirtiendo archivo {file_count}...")
                    log_fd.write("PROGRESO: Procesando archivo...\n")
                    log_fd.flush()
                elif index == 3:  # Archivo completado
                    spinner.update(f"Archivo {file_count} completado ✓")
                    log_fd.write("PROGRESO: Archivo completado\n")
                    log_fd.flush()
                elif index == 4:  # Error en archivo
                    spinner.update(f"Error en archivo {file_count} ✗")
                    log_fd.write("ERROR: Error al procesar archivo\n")
                    log_fd.flush()
                elif index == 5:  # Presiona Enter
                    spinner.update("Finalizando...")
                    child.sendline("")
                    break
                    
            except pexpect.TIMEOUT:
                # Verificar si ffmpeg sigue corriendo
                try:
                    result = subprocess.run(
                        ['pgrep', '-f', 'ffmpeg.*432Hz'],
                        capture_output=True,
                        text=True
                    )
                    if result.returncode == 0:
                        spinner.update("FFmpeg procesando audio...")
                        log_fd.write("PROGRESO: FFmpeg aún procesando, esperando...\n")
                        log_fd.flush()
                        continue
                    else:
                        spinner.update("Esperando finalización...")
                        log_fd.write("WARNING: Timeout pero ffmpeg no está corriendo\n")
                        log_fd.flush()
                        break
                except Exception:
                    break
        
        # Volver al menú y salir
        try:
            child.expect("Selecciona una opción:", timeout=10)
            child.sendline("q")
        except pexpect.TIMEOUT:
            pass
        
        # Esperar despedida
        try:
            child.expect(["¡Hasta luego!", pexpect.EOF], timeout=10)
        except pexpect.TIMEOUT:
            pass
        
        child.close()
        log_fd.close()
        spinner.stop()  # Detener spinner
        
        # Verificar resultado
        end_time = time.time()
        duration = int(end_time - start_time)
        duration_min = duration // 60
        duration_sec = duration % 60
        
        # Verificar si hubo errores en el log
        with open(log_file, 'r', encoding='utf-8') as f:
            log_content = f.read()
            if "ERROR:" in log_content:
                print_error(f"Error detectado en el procesamiento de: {dir_name}")
                print_info(f"Revisa el log: {log_file}")
                return False
        
        # Contar archivos MP3 creados
        mp3_count = len(list(dest_dir.glob("*_432Hz.mp3")))
        print_success(f"Directorio procesado exitosamente: {dir_name}")
        print_info(f"Tiempo transcurrido: {duration_min}m {duration_sec}s")
        print_info(f"Archivos MP3 creados: {mp3_count}")
        print_info(f"Log completo: {log_file}")
        return True
        
    except pexpect.EOF:
        spinner.stop()
        exit_status = child.exitstatus if hasattr(child, 'exitstatus') else "N/A"
        log_fd.write(f"ERROR: El proceso terminó inesperadamente (EOF)\n")
        log_fd.write(f"Exit status: {exit_status}\n")
        if hasattr(child, 'before'):
            log_fd.write(f"Último buffer: {child.before[-500:]}\n")
        log_fd.close()
        print_error(f"El proceso terminó inesperadamente para: {dir_name}")
        print_info(f"Revisa el log: {log_file}")
        return False
    except pexpect.TIMEOUT as e:
        spinner.stop()
        log_fd.write(f"ERROR: Timeout esperando respuesta del proceso\n")
        if hasattr(child, 'before'):
            log_fd.write(f"Buffer recibido: {child.before[-500:]}\n")
        log_fd.write(f"Proceso vivo: {child.isalive() if hasattr(child, 'isalive') else 'N/A'}\n")
        log_fd.close()
        print_error(f"Timeout esperando respuesta para: {dir_name}")
        print_info(f"Revisa el log: {log_file}")
        return False
    except Exception as e:
        spinner.stop()
        import traceback
        log_fd.write(f"ERROR: Excepción: {str(e)}\n")
        log_fd.write(f"Traceback: {traceback.format_exc()}\n")
        log_fd.close()
        print_error(f"Error al procesar {dir_name}: {e}")
        print_info(f"Revisa el log: {log_file}")
        return False

def main():
    """Función principal"""
    print_header("Conversión Masiva a MP3 432Hz - Preset Ditto Pro")
    
    # Verificaciones
    if not check_pexpect():
        sys.exit(1)
    
    if not check_python_script():
        sys.exit(1)
    
    if not check_paths():
        sys.exit(1)
    
    print_info(f"Directorio fuente: {SOURCE_BASE}")
    print_info(f"Directorio destino: {DEST_BASE}")
    print_info(f"Excluyendo: {EXCLUDE_DIR}")
    print()
    
    # Encontrar todos los subdirectorios
    source_path = Path(SOURCE_BASE)
    dirs = []
    for item in source_path.iterdir():
        if item.is_dir() and item.name != EXCLUDE_DIR:
            dirs.append(item)
    
    if not dirs:
        print_warning("No se encontraron subdirectorios para procesar")
        sys.exit(0)
    
    print_info(f"Se encontraron {len(dirs)} directorio(s) para procesar:")
    for dir_path in dirs:
        print(f"  • {dir_path.name}")
    print()
    
    # Confirmar antes de proceder
    try:
        confirm = input(f"{Colors.YELLOW}¿Continuar con la conversión? (s/n): {Colors.NC}").strip().lower()
        if confirm not in ['s', 'y', 'sí', 'yes', 'si']:
            print_warning("Operación cancelada")
            sys.exit(0)
    except (EOFError, KeyboardInterrupt):
        print()
        print_warning("Operación cancelada")
        sys.exit(0)
    
    print()
    
    # Procesar cada directorio
    success_count = 0
    fail_count = 0
    total = len(dirs)
    overall_start_time = time.time()
    
    for i, source_dir in enumerate(dirs, 1):
        dir_name = source_dir.name
        dest_dir = Path(DEST_BASE) / dir_name
        
        print()
        print_info(f"[{i}/{total}] Procesando: {dir_name}")
        print_info(f"Hora de inicio: {datetime.now().strftime('%H:%M:%S')}")
        print()
        
        if process_directory(source_dir, dest_dir, dir_name):
            success_count += 1
            print_success(f"✓ Completado: {dir_name} ({i}/{total})")
        else:
            fail_count += 1
            print_error(f"✗ Fallido: {dir_name} ({i}/{total})")
        
        # Mostrar progreso acumulado
        elapsed = int(time.time() - overall_start_time)
        elapsed_min = elapsed // 60
        if i > 0:
            avg_time_per_dir = elapsed // i
            remaining_dirs = total - i
            estimated_remaining = avg_time_per_dir * remaining_dirs
            est_min = estimated_remaining // 60
        else:
            est_min = 0
        
        print()
        print_info(f"Progreso: {i}/{total} directorios")
        print_info(f"Tiempo transcurrido: {elapsed_min} minutos")
        if remaining_dirs > 0:
            print_info(f"Tiempo estimado restante: ~{est_min} minutos")
        print()
        
        # Pequeña pausa entre directorios
        time.sleep(2)
    
    # Resumen final
    overall_end_time = time.time()
    total_duration = int(overall_end_time - overall_start_time)
    total_hours = total_duration // 3600
    total_min = (total_duration % 3600) // 60
    total_sec = total_duration % 60
    
    print()
    print_header("Procesamiento Completado")
    print_success(f"Exitosos: {success_count}")
    if fail_count > 0:
        print_error(f"Fallidos: {fail_count}")
    print_info(f"Total procesados: {total}")
    if total_hours > 0:
        print_info(f"Tiempo total: {total_hours}h {total_min}m {total_sec}s")
    else:
        print_info(f"Tiempo total: {total_min}m {total_sec}s")
    
    # Mostrar ubicación de logs
    print()
    print_info("Logs individuales guardados en: /tmp/batch_convert_*.log")
    print_info("Para ver el log más reciente:")
    print_info("  cat \"$(ls -t /tmp/batch_convert_*.log | head -1)\"")
    print_info("Para ver las últimas líneas:")
    print_info("  tail -50 \"$(ls -t /tmp/batch_convert_*.log | head -1)\"")
    print()

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print()
        print_warning("Operación cancelada por el usuario")
        sys.exit(130)

