#!/usr/bin/env python3
"""
Script para encontrar archivos duplicados en directorios específicos
Requiere: Python 3.6+
"""

import sys
import os
import hashlib
import subprocess
from collections import defaultdict

# Verificar versión de Python
if sys.version_info < (3, 6):
    print("Error: Se requiere Python 3.6 o superior.", file=sys.stderr)
    sys.exit(1)

# --- Configuración ---

MEDIA_EXTENSIONS = {
    # Audio - DAWs
    ".logicx", ".als", ".cpr", ".ptx", ".flp", ".rpp", ".reason", ".m4a", ".mp3", ".wav"
    # Video
    ".fcp", ".fcpbundle", ".prproj", ".drp", ".mov", ".m4v", "mp4",
    # Diseño
    ".psd", ".ai", ".sketch", ".fig",
}

# --- Funciones Auxiliares ---

def get_file_hash(path: str) -> str:
    """Calcula el hash SHA256 de un archivo para identificarlo."""
    sha256 = hashlib.sha256()
    try:
        with open(path, "rb") as f:
            for byte_block in iter(lambda: f.read(4096), b""):
                sha256.update(byte_block)
        return sha256.hexdigest()
    except (IOError, PermissionError):
        return ""

def format_bytes(size: int) -> str:
    """Convierte bytes a un formato legible (KB, MB, GB)."""
    if size == 0:
        return "0B"
    power = 1024
    n = 0
    power_labels = {0: '', 1: 'KB', 2: 'MB', 3: 'GB', 4: 'TB'}
    while size > power and n < len(power_labels):
        size /= power
        n += 1
    return f"{size:.2f} {power_labels[n]}"

def select_search_directory() -> str:
    """Muestra un menú para que el usuario elija dónde buscar."""
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

    for key, (name, _) in paths.items():
        print(f"  {key}) {name}")

    while True:
        try:
            choice = input("Ingresa el número de tu elección: ")
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
    duplicate_locations = set() # Usamos un set para evitar directorios repetidos

    print("Escaneando directorios (esto puede tardar)...")
    try:
        for dirpath, _, filenames in os.walk(search_path):
            print(f"  Scaneando: {dirpath.ljust(80)}", end='\r')
            for filename in filenames:
                if filename.lower().endswith(tuple(MEDIA_EXTENSIONS)):
                    file_path = os.path.join(dirpath, filename)
                    try:
                        file_size = os.path.getsize(file_path)
                        hashes_by_size[file_size].append(file_path)
                    except OSError:
                        continue
    finally:
        print(" " * 100, end='\r')

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
                print(f"  {'📌' if i == 0 else '↳'} {path}")
                # Añade la carpeta contenedora al set
                duplicate_locations.add(os.path.dirname(path))

    if not found_duplicates:
        print("\n✅ ¡Genial! No se encontraron archivos duplicados en esa ubicación.")
        return # Termina el script si no hay nada que hacer

    print("\n" + "="*40)
    print(f"✅ Búsqueda finalizada.")
    print(f" Espacio total que se puede liberar: {format_bytes(total_wasted_space)}")
    print("="*40)
    
    # --- NUEVA SECCIÓN: Abrir en Finder ---
    prompt_to_open_finder(list(sorted(duplicate_locations)))


def prompt_to_open_finder(locations: list):
    """Muestra un menú para abrir una carpeta de duplicados en Finder."""
    print("\n📍 Se encontraron duplicados en las siguientes ubicaciones.")
    print("Selecciona un número para abrir la carpeta en Finder:")

    for i, location in enumerate(locations):
        print(f"  {i + 1}) {location}")
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
                # Comando específico de macOS para abrir una carpeta
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
    search_dir = select_search_directory()
    find_duplicates(search_dir)