import psutil
from pathlib import Path
import os
from .safety import PathInfo, RiskLevel, check_protection
from .platforms import get_platform_paths
from .utils import get_directory_size

class DiskScanner:
    def __init__(self):
        self.platform_paths = get_platform_paths()
        self.protected_paths = self.platform_paths.get("protected", [])

    def get_disk_usage(self, path: str = "/") -> dict:
        """Obtiene el uso de disco de la partición principal o la ruta dada."""
        try:
            usage = psutil.disk_usage(path)
            return {
                "total": usage.total,
                "used": usage.used,
                "free": usage.free,
                "percent": usage.percent
            }
        except Exception:
            # Fallback for some systems where / might not work as expected
            return {"total": 0, "used": 0, "free": 0, "percent": 0.0}

    def find_recoverable_space(self) -> list[PathInfo]:
        """Encuentra directorios y archivos candidatos a limpieza."""
        candidates = []
        
        # Cachés de usuario (SAFE)
        caches = self.platform_paths.get("caches")
        if caches and caches.exists():
            candidates.append(PathInfo(
                path=caches,
                risk=RiskLevel.SAFE,
                description="Cachés de usuario generales",
                size_bytes=get_directory_size(caches),
                is_directory=True
            ))

        # Trash (SAFE)
        trash = self.platform_paths.get("trash")
        if trash and trash.exists():
            candidates.append(PathInfo(
                path=trash,
                risk=RiskLevel.SAFE,
                description="Papelera de reciclaje",
                size_bytes=get_directory_size(trash),
                is_directory=True
            ))

        # Logs (SAFE)
        logs = self.platform_paths.get("logs")
        if logs and logs.exists():
            candidates.append(PathInfo(
                path=logs,
                risk=RiskLevel.SAFE,
                description="Logs del sistema y aplicaciones de usuario",
                size_bytes=get_directory_size(logs),
                is_directory=True
            ))

        # Temp (SAFE / REVIEW)
        temp = self.platform_paths.get("temp")
        if temp and temp.exists() and not check_protection(temp, self.protected_paths):
            candidates.append(PathInfo(
                path=temp,
                risk=RiskLevel.SAFE,
                description="Archivos temporales del sistema/usuario",
                size_bytes=get_directory_size(temp),
                is_directory=True
            ))

        # Downloads (REVIEW)
        downloads = self.platform_paths.get("downloads")
        if downloads and downloads.exists():
            candidates.append(PathInfo(
                path=downloads,
                risk=RiskLevel.REVIEW,
                description="Carpeta de descargas (requiere revisión manual)",
                size_bytes=get_directory_size(downloads),
                is_directory=True
            ))
            
        # Mac Specific (REVIEW / SAFE)
        xcode = self.platform_paths.get("xcode_derived")
        if xcode and xcode.exists():
            candidates.append(PathInfo(
                path=xcode,
                risk=RiskLevel.REVIEW,
                description="Caché de compilación de Xcode (DerivedData)",
                size_bytes=get_directory_size(xcode),
                is_directory=True
            ))

        # Filtrar candidatos que por error estén protegidos (Safety Layer)
        safe_candidates = []
        for c in candidates:
            if not check_protection(c.path, self.protected_paths):
                safe_candidates.append(c)

        return safe_candidates

    def estimate_non_deletable_space(self) -> list[PathInfo]:
        """Reporta rutas clave que no deben ser eliminadas."""
        protected = []
        for p in self.protected_paths:
            if p.exists():
                protected.append(PathInfo(
                    path=p,
                    risk=RiskLevel.PROTECTED,
                    description="Ruta protegida del sistema operativo",
                    size_bytes=0, # No calculamos tamaño de /System por rendimiento
                    is_directory=True
                ))
        return protected
