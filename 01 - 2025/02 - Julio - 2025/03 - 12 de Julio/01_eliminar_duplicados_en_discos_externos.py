#!/usr/bin/env python3
"""
Script para encontrar archivos duplicados en directorios y discos externos
Requiere: Python 3.6+
"""

import sys
import os
import hashlib
import subprocess
import textwrap
import shutil
from collections import defaultdict

# Verificar versión de Python
if sys.version_info < (3, 6):
    print("Error: Se requiere Python 3.6 o superior.", file=sys.stderr)
    sys.exit(1)

# --- Configuración ---

MEDIA_EXTENSIONS = {
    # Proyectos de Audio (DAWs)
    ".logicx", ".als", ".cpr", ".ptx", ".flp", ".rpp", ".reason",
    # Archivos de Audio
    ".mp3", ".m4a", ".wav", ".aiff",
    # Proyectos de Video
    ".fcp", ".fcpbundle", ".prproj", ".drp",
    # Archivos de Video
    ".mp4", ".mov", ".m4v",
    # Proyectos de Diseño
    ".psd", ".ai", ".sketch", ".fig",
}

# --- Funciones Auxiliares ---

def get_file_hash(path: str) -> str:
    sha256 = hashlib.sha256()
    try:
        with open(path, "rb") as f:
            for byte_block in iter(lambda: f.read(4096), b""):
                sha256.update(byte_block)
        return sha256.hexdigest()
    except (IOError, PermissionError):
        return ""

def format_bytes(size: int) -> str:
    if size == 0:
        return "0B"
    power = 1024
    n = 0
    power_labels = {0: '', 1: 'KB', 2: 'MB', 3: 'GB', 4: 'TB'}
    while size > power and n < len(power_labels):
        size /= power
        n += 1
    return f"{size:.2f} {power_labels[n]}"

def truncate_path(path: str, max_len: int) -> str:
    """Acorta una ruta si es más larga que max_len, añadiendo '...' en el medio."""
    if len(path) <= max_len:
        return path
    
    half_len = (max_len - 5) // 2
    return f"{path[:half_len]}...{path[-half_len:]}"

def select_search_location() -> str:
    """Muestra un menú para que el usuario elija una ubicación, incluyendo discos externos."""
    print("Selecciona dónde quieres buscar archivos duplicados:")
    
    paths = {
        "1": ("Escritorio", os.path.expanduser("~/Desktop")),
        "2": ("Descargas", os.path.expanduser("~/Downloads")),
        "3": ("Documentos", os.path.expanduser("~/Documents")),
        "4": ("Música", os.path.expanduser("~/Music")),
        "5": ("Películas", os.path.expanduser("~/Movies")),
        "6": ("Imágenes", os.path.expanduser("~/Pictures")),
        "7": ("Todo mi directorio de usuario (~/)", os.path.expanduser("~")),
    }
    
    print("\n--- Ubicaciones Internas ---")
    for key, (name, _) in paths.items():
        print(f"  {key}) {name}")

    external_drives = []
    volumes_path = "/Volumes"
    if os.path.exists(volumes_path):
        for drive_name in os.listdir(volumes_path):
            drive_path = os.path.join(volumes_path, drive_name)
            if drive_name not in ["Macintosh HD", "com.apple.TimeMachine.localsnapshots"] and os.path.isdir(drive_path):
                external_drives.append((drive_name, drive_path))

    if external_drives:
        print("\n--- Discos Externos / USB ---")
        for i, (name, path) in enumerate(external_drives, start=len(paths) + 1):
            key = str(i)
            paths[key] = (name, path)
            print(f"  {key}) {name}")

    while True:
        try:
            choice = input("\nIngresa el número de tu elección: ")
            if choice in paths:
                print("-" * 20)
                return paths[choice][1]
            print("Opción no válida. Por favor, intenta de nuevo.")
        except (EOFError, KeyboardInterrupt):
            print("\nOperación cancelada por el usuario.", file=sys.stderr)
            sys.exit(1)
        
# --- Lógica Principal ---

def find_duplicates(search_path: str):
    """Encuentra duplicados y ofrece abrir su ubicación."""
    print(f"🔍 Iniciando búsqueda en: {search_path}")
    
    hashes_by_size = defaultdict(list)
    files_by_hash = defaultdict(list)
    total_wasted_space = 0
    duplicate_locations = set()
    terminal_width = shutil.get_terminal_size().columns

    print("Escaneando directorios (esto puede tardar)...")
    try:
        for dirpath, _, filenames in os.walk(search_path, topdown=True):
            # Acorta la ruta en la barra de progreso para que no se desordene
            display_path = truncate_path(dirpath, terminal_width - 15)
            print(f"  Scaneando: {display_path.ljust(terminal_width-13)}", end='\r')

            for filename in filenames:
                if os.path.splitext(filename)[1].lower() in MEDIA_EXTENSIONS:
                    file_path = os.path.join(dirpath, filename)
                    try:
                        file_size = os.path.getsize(file_path)
                        if file_size > 0:
                            hashes_by_size[file_size].append(file_path)
                    except OSError:
                        continue
    finally:
        print(" " * terminal_width, end='\r')

    print("Analizando archivos para encontrar duplicados...\n")
    for size, files in hashes_by_size.items():
        if len(files) < 2:
            continue
        for file_path in files:
            file_hash = get_file_hash(file_path)
            if file_hash:
                files_by_hash[file_hash].append((file_path, size))

    found_duplicates = False
    for file_hash, files_info in files_by_hash.items():
        if len(files_info) > 1:
            if not found_duplicates:
                print("--- 📂 Archivos Duplicados Encontrados ---")
                found_duplicates = True
            
            _, file_size = files_info[0]
            total_wasted_space += file_size * (len(files_info) - 1)

            print(f"\nHash: {file_hash[:10]}... | Tamaño por archivo: {format_bytes(file_size)}")
            for i, (path, _) in enumerate(files_info):
                icon = '📌' if i == 0 else '↳'
                # Configura el justificado para las rutas de archivo
                wrapper = textwrap.TextWrapper(
                    initial_indent=f"  {icon} ",
                    width=terminal_width,
                    subsequent_indent='    ' # 4 espacios para alinear
                )
                print(wrapper.fill(path))
                duplicate_locations.add(os.path.dirname(path))

    if not found_duplicates:
        print("\n✅ ¡Genial! No se encontraron archivos duplicados en esa ubicación.")
        return

    print("\n" + "="*40)
    print(f"✅ Búsqueda finalizada.")
    print(f" Espacio total que se puede liberar: {format_bytes(total_wasted_space)}")
    print("="*40)
    
    prompt_to_open_finder(list(sorted(duplicate_locations)))


def prompt_to_open_finder(locations: list):
    """Muestra un menú justificado para abrir una carpeta en Finder."""
    print("\n📍 Se encontraron duplicados en las siguientes ubicaciones.")
    print("Selecciona un número para abrir la carpeta en Finder:")
    
    terminal_width = shutil.get_terminal_size().columns
    
    for i, location in enumerate(locations):
        # Configura el justificado para el menú de ubicaciones
        wrapper = textwrap.TextWrapper(
            initial_indent=f"  {i + 1}) ",
            width=terminal_width,
            subsequent_indent='     ' # 5 espacios para alinear con el inicio de la ruta
        )
        print(wrapper.fill(location))

    print("  0) Salir")

    while True:
        try:
            choice = int(input("\nIngresa tu opción: "))
            if 0 <= choice <= len(locations):
                if choice == 0:
                    print("Saliendo del programa.")
                    break
                
                selected_path = locations[choice - 1]
                print(f"Abriendo {selected_path} en Finder...")
                try:
                    subprocess.run(["open", selected_path], check=True)
                except subprocess.CalledProcessError as e:
                    print(f"Error al abrir Finder: {e}", file=sys.stderr)
                except FileNotFoundError:
                    print("Error: El comando 'open' no está disponible (no estás en macOS?)", file=sys.stderr)
                break
            else:
                print("Número fuera de rango. Intenta de nuevo.")
        except ValueError:
            print("Entrada no válida. Por favor, ingresa un número.")
        except Exception as e:
            print(f"No se pudo abrir la carpeta: {e}")
            break


if __name__ == "__main__":
    find_duplicates(select_search_location())