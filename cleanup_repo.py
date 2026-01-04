#!/usr/bin/env python3
"""
Script para limpiar archivos innecesarios del repositorio
"""

import os
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).parent.resolve()

# Archivos y directorios a limpiar
CLEANUP_PATTERNS = [
    # Archivos temporales
    "*.tmp",
    "*.log",
    
    # Python cache
    "__pycache__/",
    "*.pyc",
    "*.pyo",
    "*.pyd",
    
    # Reportes antiguos de verificación
    "script_verification_report_*.txt",
    
    # Archivos de sistema
    ".DS_Store",
    "Thumbs.db",
    
    # Archivos de editor
    "*.swp",
    "*.swo",
    "*~",
    ".idea/",
    ".vscode/",
]

# Archivos específicos a eliminar
SPECIFIC_FILES = [
    "REVIEW_SUMMARY.md",  # Si es temporal
]

def find_files_to_clean() -> list:
    """Encuentra archivos que deben ser limpiados"""
    files_to_delete = []
    dirs_to_delete = []
    
    # Buscar archivos temporales
    for pattern in ["*.tmp", "*.log"]:
        for file in REPO_ROOT.rglob(pattern):
            if file.is_file():
                files_to_delete.append(file)
    
    # Buscar reportes antiguos
    for file in REPO_ROOT.rglob("script_verification_report_*.txt"):
        if file.is_file():
            files_to_delete.append(file)
    
    # Buscar __pycache__
    for pycache_dir in REPO_ROOT.rglob("__pycache__"):
        if pycache_dir.is_dir():
            dirs_to_delete.append(pycache_dir)
    
    # Buscar archivos .pyc, .pyo, .pyd
    for pattern in ["*.pyc", "*.pyo", "*.pyd"]:
        for file in REPO_ROOT.rglob(pattern):
            if file.is_file():
                files_to_delete.append(file)
    
    # Buscar .DS_Store
    for file in REPO_ROOT.rglob(".DS_Store"):
        if file.is_file():
            files_to_delete.append(file)
    
    # Archivos específicos
    for filename in SPECIFIC_FILES:
        file_path = REPO_ROOT / filename
        if file_path.exists():
            files_to_delete.append(file_path)
    
    return files_to_delete, dirs_to_delete

def main():
    """Función principal"""
    print("🔍 Buscando archivos innecesarios...")
    print()
    
    files_to_delete, dirs_to_delete = find_files_to_clean()
    
    if not files_to_delete and not dirs_to_delete:
        print("✓ No se encontraron archivos innecesarios")
        return
    
    print(f"📁 Archivos a eliminar: {len(files_to_delete)}")
    print(f"📂 Directorios a eliminar: {len(dirs_to_delete)}")
    print()
    
    if files_to_delete:
        print("Archivos:")
        for f in files_to_delete[:20]:  # Mostrar primeros 20
            rel_path = f.relative_to(REPO_ROOT)
            print(f"  - {rel_path}")
        if len(files_to_delete) > 20:
            print(f"  ... y {len(files_to_delete) - 20} más")
        print()
    
    if dirs_to_delete:
        print("Directorios:")
        for d in dirs_to_delete:
            rel_path = d.relative_to(REPO_ROOT)
            print(f"  - {rel_path}/")
        print()
    
    # Confirmar
    response = input("¿Eliminar estos archivos? (y/n): ").strip().lower()
    if response != 'y':
        print("Operación cancelada")
        return
    
    # Eliminar archivos
    deleted_files = 0
    deleted_dirs = 0
    
    for file_path in files_to_delete:
        try:
            file_path.unlink()
            deleted_files += 1
        except Exception as e:
            print(f"⚠️  Error al eliminar {file_path}: {e}")
    
    # Eliminar directorios
    for dir_path in dirs_to_delete:
        try:
            import shutil
            shutil.rmtree(dir_path)
            deleted_dirs += 1
        except Exception as e:
            print(f"⚠️  Error al eliminar {dir_path}: {e}")
    
    print()
    print(f"✓ Eliminados {deleted_files} archivos y {deleted_dirs} directorios")
    
    # Actualizar .gitignore si es necesario
    gitignore_path = REPO_ROOT / ".gitignore"
    gitignore_entries = [
        "*.tmp",
        "*.log",
        "__pycache__/",
        "*.pyc",
        "*.pyo",
        "*.pyd",
        ".DS_Store",
        "script_verification_report_*.txt",
        "REVIEW_SUMMARY.md",
    ]
    
    if gitignore_path.exists():
        with open(gitignore_path, 'r') as f:
            existing = f.read()
    else:
        existing = ""
    
    new_entries = []
    for entry in gitignore_entries:
        if entry not in existing:
            new_entries.append(entry)
    
    if new_entries:
        print()
        print("📝 Actualizando .gitignore...")
        with open(gitignore_path, 'a') as f:
            if existing and not existing.endswith('\n'):
                f.write('\n')
            f.write("# Archivos temporales y cache\n")
            for entry in new_entries:
                f.write(f"{entry}\n")
        print("✓ .gitignore actualizado")

if __name__ == "__main__":
    main()

