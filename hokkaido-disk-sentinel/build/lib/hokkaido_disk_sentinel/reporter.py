import json
import datetime
import getpass
import platform
from pathlib import Path
from .safety import PathInfo
from .utils import format_size

class Reporter:
    def __init__(self, disk_usage: dict, recoverable: list[PathInfo], protected: list[PathInfo]):
        self.disk_usage = disk_usage
        self.recoverable = recoverable
        self.protected = protected
        self.total_recoverable = sum(item.size_bytes for item in recoverable)

    def _get_base_data(self) -> dict:
        return {
            "timestamp": datetime.datetime.now().isoformat(),
            "os": platform.system(),
            "user": getpass.getuser(),
            "disk": {
                "total": self.disk_usage.get("total", 0),
                "used": self.disk_usage.get("used", 0),
                "free": self.disk_usage.get("free", 0),
                "percent": self.disk_usage.get("percent", 0.0)
            },
            "recoverable_total": self.total_recoverable,
            "recoverable_items": [
                {
                    "path": str(item.path),
                    "risk": item.risk.name,
                    "description": item.description,
                    "size_bytes": item.size_bytes
                } for item in self.recoverable
            ],
            "protected_items": [
                {
                    "path": str(item.path),
                    "description": item.description
                } for item in self.protected
            ]
        }

    def generate_json(self, filepath: str):
        """Genera un reporte en formato JSON."""
        data = self._get_base_data()
        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=4)

    def generate_markdown(self, filepath: str):
        """Genera un reporte detallado en Markdown."""
        data = self._get_base_data()
        md = [
            "# Hokkaido Disk Sentinel Report\n",
            f"- **Fecha y hora:** {data['timestamp']}",
            f"- **Sistema Operativo:** {data['os']}",
            f"- **Usuario:** {data['user']}",
            "\n## Uso de Disco\n",
            f"- **Total:** {format_size(data['disk']['total'])}",
            f"- **Usado:** {format_size(data['disk']['used'])} ({data['disk']['percent']}%)",
            f"- **Libre:** {format_size(data['disk']['free'])}",
            f"\n## Espacio Recuperable Estimado: {format_size(data['recoverable_total'])}\n",
            "### Candidatos a Limpieza\n",
            "| Ruta | Tamaño | Riesgo | Descripción |",
            "| --- | --- | --- | --- |"
        ]
        
        for item in data['recoverable_items']:
            md.append(f"| `{item['path']}` | {format_size(item['size_bytes'])} | {item['risk']} | {item['description']} |")

        md.extend([
            "\n## Rutas Protegidas (NO BORRABLES)\n",
            "| Ruta | Descripción |",
            "| --- | --- |"
        ])
        
        for item in data['protected_items']:
            md.append(f"| `{item['path']}` | {item['description']} |")
            
        md.append("\n> **Nota:** Este es un reporte generado automáticamente. No elimine rutas DANGEROUS o PROTECTED.")

        with open(filepath, "w", encoding="utf-8") as f:
            f.write("\n".join(md))
