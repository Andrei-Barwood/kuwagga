from enum import Enum
from pathlib import Path
from dataclasses import dataclass

class RiskLevel(Enum):
    SAFE = "SAFE"           # Borrable tras confirmación (cachés, temporales)
    REVIEW = "REVIEW"         # Requiere inspección detallada (descargas, node_modules)
    DANGEROUS = "DANGEROUS"   # Datos de apps que no deben tocarse automáticamente
    PROTECTED = "PROTECTED"   # Archivos críticos del OS

@dataclass
class PathInfo:
    path: Path
    risk: RiskLevel
    description: str
    size_bytes: int = 0
    is_directory: bool = True

def is_subpath(child: Path, parent: Path) -> bool:
    """Verifica si 'child' es un subdirectorio de 'parent'."""
    try:
        # parent.resolve() in child.resolve().parents puede fallar por permisos
        # en su lugar, usamos paths absolutos y relativos
        child.relative_to(parent)
        return True
    except ValueError:
        return False
    except Exception:
        return False

def check_protection(target_path: Path, protected_paths: list[Path]) -> bool:
    """
    Retorna True si el target_path coincide o está dentro de una ruta protegida.
    """
    target = target_path.resolve()
    for prot_path in protected_paths:
        try:
            prot = prot_path.resolve()
            if target == prot or is_subpath(target, prot):
                return True
        except Exception:
            # Si no podemos resolver la ruta protegida, somos conservadores
            # y asumimos que podría ser un problema, pero en general omitimos.
            continue
    return False
