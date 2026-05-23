import sys
from pathlib import Path
import platformdirs

def get_platform_paths() -> dict:
    """Retorna las rutas importantes basadas en el sistema operativo actual."""
    app_name = "HokkaidoDiskSentinel"
    app_author = "HokkaidoTeam"
    
    paths = {
        "caches": Path(platformdirs.user_cache_dir()),
        "logs": Path(platformdirs.user_log_dir()),
        "downloads": Path(platformdirs.user_downloads_dir()),
        "temp": Path("/tmp") if sys.platform != "win32" else Path(platformdirs.user_cache_dir()) / "Temp", # Aproximación
        "protected": []
    }

    if sys.platform == "darwin":  # macOS
        paths["trash"] = Path.home() / ".Trash"
        paths["xcode_derived"] = Path.home() / "Library/Developer/Xcode/DerivedData"
        paths["homebrew_cache"] = Path.home() / "Library/Caches/Homebrew"
        paths["protected"] = [
            Path("/System"),
            Path("/Library"),
            Path("/Applications"),
            Path("/private"),
            Path("/usr"),
            Path("/bin"),
            Path("/sbin"),
            Path("/var"),
            Path("/etc")
        ]
    elif sys.platform == "win32":  # Windows
        # platformdirs en windows da AppData
        paths["trash"] = Path("C:\\$Recycle.Bin")
        paths["temp"] = Path(platformdirs.user_data_dir()) / ".." / "Local" / "Temp"
        paths["protected"] = [
            Path("C:\\Windows"),
            Path("C:\\Program Files"),
            Path("C:\\Program Files (x86)"),
            Path("C:\\ProgramData"),
            Path("C:\\System Volume Information"),
            Path("C:\\pagefile.sys"),
            Path("C:\\hiberfil.sys"),
            Path("C:\\swapfile.sys"),
        ]
    else:  # Linux
        paths["trash"] = Path.home() / ".local/share/Trash"
        paths["npm_cache"] = Path.home() / ".npm"
        paths["protected"] = [
            Path("/"),
            Path("/boot"),
            Path("/etc"),
            Path("/usr"),
            Path("/bin"),
            Path("/sbin"),
            Path("/lib"),
            Path("/lib64"),
            Path("/var"),
            Path("/home"),
            Path("/root"),
            Path("/proc"),
            Path("/sys"),
            Path("/dev"),
            Path("/run")
        ]

    return paths
