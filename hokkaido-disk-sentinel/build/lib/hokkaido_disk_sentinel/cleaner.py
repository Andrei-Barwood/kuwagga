import shutil
import logging
from pathlib import Path
from .safety import PathInfo, RiskLevel, check_protection
from .platforms import get_platform_paths

logger = logging.getLogger(__name__)

class SafeCleaner:
    def __init__(self, dry_run: bool = True):
        self.dry_run = dry_run
        self.protected_paths = get_platform_paths().get("protected", [])

    def clean_item(self, item: PathInfo) -> bool:
        """Elimina de forma segura un elemento si las políticas lo permiten."""
        target = item.path.resolve()

        # Regla 1: Nunca borrar nada clasificado como DANGEROUS o PROTECTED
        if item.risk in (RiskLevel.DANGEROUS, RiskLevel.PROTECTED):
            logger.warning(f"[BLOCKED] Se intentó borrar ruta con riesgo {item.risk.name}: {target}")
            return False

        # Regla 2: Chequear en tiempo real si está en rutas protegidas
        if check_protection(target, self.protected_paths):
            logger.error(f"[SECURITY] Intento de borrado interceptado en ruta protegida: {target}")
            return False

        if not target.exists():
            logger.info(f"[SKIP] La ruta no existe: {target}")
            return True

        if self.dry_run:
            logger.info(f"[DRY-RUN] Se eliminaría: {target}")
            return True

        try:
            if target.is_dir() and not target.is_symlink():
                shutil.rmtree(target)
            else:
                target.unlink()
            logger.info(f"[DELETED] Eliminado con éxito: {target}")
            return True
        except PermissionError:
            logger.error(f"[ERROR] Permiso denegado: {target}")
            return False
        except Exception as e:
            logger.error(f"[ERROR] Fallo al borrar {target}: {str(e)}")
            return False

    def clean_multiple(self, items: list[PathInfo]) -> dict:
        """Limpia múltiples items y retorna un reporte."""
        results = {"success": 0, "failed": 0, "freed_bytes": 0}
        for item in items:
            size_before = item.size_bytes
            success = self.clean_item(item)
            if success:
                results["success"] += 1
                if not self.dry_run:
                    results["freed_bytes"] += size_before
            else:
                results["failed"] += 1
        return results
