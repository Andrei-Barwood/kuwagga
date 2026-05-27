import os
from pathlib import Path

def format_size(size_in_bytes: int) -> str:
    """Convierte bytes a un formato legible por humanos (KB, MB, GB, TB)."""
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if size_in_bytes < 1024.0:
            return f"{size_in_bytes:.2f} {unit}"
        size_in_bytes /= 1024.0
    return f"{size_in_bytes:.2f} PB"

def get_directory_size(path: Path) -> int:
    """Calcula el tamaño total de un directorio de forma segura."""
    total_size = 0
    if not path.exists():
        return 0
        
    if path.is_file() and not path.is_symlink():
        try:
            return path.stat().st_size
        except (PermissionError, FileNotFoundError, OSError):
            return 0

    try:
        for dirpath, dirnames, filenames in os.walk(path):
            for f in filenames:
                fp = Path(dirpath) / f
                if not fp.is_symlink():
                    try:
                        total_size += fp.stat().st_size
                    except (PermissionError, FileNotFoundError, OSError):
                        continue
    except (PermissionError, OSError):
        pass
    
    return total_size
