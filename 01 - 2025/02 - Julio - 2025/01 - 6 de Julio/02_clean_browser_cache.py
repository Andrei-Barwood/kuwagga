import os
import shutil
import sys
from pathlib import Path

def get_dir_size(path: Path) -> int:
    """Calcula el tamaño total de un directorio o archivo."""
    total_size = 0
    if path.is_file():
        return path.stat().st_size
    if path.is_dir():
        for dirpath, _, filenames in os.walk(path):
            for f in filenames:
                fp = Path(dirpath) / f
                if not fp.is_symlink() and fp.exists():
                    total_size += fp.stat().st_size
    return total_size

def human_readable_size(size: int) -> str:
    """Convierte bytes a formato legible (KB, MB, GB, etc.)."""
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if size < 1024.0:
            return f"{size:.2f} {unit}"
        size /= 1024.0
    return f"{size:.2f} PB"

def get_browsers_cache_dirs() -> dict[str, list[Path]]:
    """Devuelve un diccionario con las rutas de caché de varios navegadores según el sistema operativo."""
    home = Path.home()
    system = sys.platform
    
    browsers = {
        "Firefox": [],
        "Chrome": [],
        "Safari": [],
        "Edge": [],
        "Brave": [],
        "Opera": []
    }
    
    if system == "darwin": # macOS
        browsers["Firefox"] = [
            home / "Library/Caches/Firefox",
            home / "Library/Caches/org.mozilla.firefox",
            home / "Library/Caches/Mozilla"
        ]
        browsers["Chrome"] = [home / "Library/Caches/Google/Chrome"]
        browsers["Safari"] = [home / "Library/Caches/com.apple.Safari"]
        browsers["Edge"] = [home / "Library/Caches/com.microsoft.edgemac"]
        browsers["Brave"] = [home / "Library/Caches/BraveSoftware/Brave-Browser"]
        browsers["Opera"] = [home / "Library/Caches/com.operasoftware.Opera"]
        
    elif system == "win32": # Windows
        local_app_data = Path(os.getenv('LOCALAPPDATA', home / 'AppData/Local'))
        
        # Firefox (Puede tener varios perfiles)
        ff_profiles = local_app_data / "Mozilla/Firefox/Profiles"
        if ff_profiles.exists():
            for profile in ff_profiles.iterdir():
                if profile.is_dir():
                    browsers["Firefox"].extend([profile / "cache2", profile / "startupCache"])
                    
        browsers["Chrome"] = [
            local_app_data / "Google/Chrome/User Data/Default/Cache",
            local_app_data / "Google/Chrome/User Data/Default/Code Cache"
        ]
        browsers["Edge"] = [
            local_app_data / "Microsoft/Edge/User Data/Default/Cache",
            local_app_data / "Microsoft/Edge/User Data/Default/Code Cache"
        ]
        browsers["Brave"] = [
            local_app_data / "BraveSoftware/Brave-Browser/User Data/Default/Cache"
        ]
        browsers["Opera"] = [
            local_app_data / "Opera Software/Opera Stable/Cache"
        ]
        
    elif system.startswith("linux"): # Linux
        cache_home = Path(os.getenv('XDG_CACHE_HOME', home / '.cache'))
        browsers["Firefox"] = [cache_home / "mozilla/firefox"]
        browsers["Chrome"] = [cache_home / "google-chrome"]
        browsers["Brave"] = [cache_home / "BraveSoftware/Brave-Browser"]
        browsers["Edge"] = [cache_home / "microsoft-edge"]
        browsers["Opera"] = [cache_home / "opera"]
        
    return browsers

def show_cache_size():
    browsers_dirs = get_browsers_cache_dirs()
    total_global_size = 0
    print("\n--- Tamaño de Caché por Navegador ---")
    
    for browser, cache_dirs in browsers_dirs.items():
        if not cache_dirs:
            continue # Saltar navegadores no aplicables al SO
            
        browser_total_size = 0
        found_any = False
        for cache_dir in cache_dirs:
            if cache_dir.exists() and cache_dir.is_dir():
                size = get_dir_size(cache_dir)
                browser_total_size += size
                found_any = True
                
        if found_any:
            print(f"[{browser}] Tamaño: {human_readable_size(browser_total_size)}")
            total_global_size += browser_total_size
        else:
            print(f"[{browser}] No encontrado o vacío")
            
    print("-" * 50)
    print(f"Tamaño total de todas las cachés: {human_readable_size(total_global_size)}\n")

def clean_all_browsers_cache():
    browsers_dirs = get_browsers_cache_dirs()
    total_freed = 0
    
    print("\nIniciando limpieza de TODOS los navegadores...")
    print("Los navegadores acumulan muchos datos en caché (imágenes de webs, scripts, etc.).")
    print("Limpiando directorios de caché de forma segura...\n")
    
    for browser, cache_dirs in browsers_dirs.items():
        browser_freed = 0
        for cache_dir in cache_dirs:
            if cache_dir.exists() and cache_dir.is_dir():
                size = get_dir_size(cache_dir)
                if size == 0:
                    continue
                    
                print(f"Limpiando caché de {browser}: {cache_dir}")
                
                try:
                    # Borramos el contenido del directorio
                    for item in cache_dir.iterdir():
                        if item.is_file() or item.is_symlink():
                            item.unlink()
                        elif item.is_dir():
                            shutil.rmtree(item)
                    
                    browser_freed += size
                    total_freed += size
                except Exception as e:
                    print(f" -> Error al limpiar {cache_dir}: {e}")
                    
        if browser_freed > 0:
            print(f" -> ¡{browser} limpiado exitosamente! Liberado: {human_readable_size(browser_freed)}\n")
            
    print("-" * 50)
    print(f"Total de espacio liberado: {human_readable_size(total_freed)}")
    print("Tus perfiles, historial, contraseñas y marcadores NO fueron tocados.\n")

def main_menu():
    while True:
        print("=== Utilidad Multi-Navegador de Limpieza de Caché ===")
        print("Soporte para: Windows, macOS y Linux")
        print("Navegadores: Chrome, Firefox, Safari, Edge, Brave, Opera\n")
        print("1. Ver espacio ocupado por la caché")
        print("   -> Muestra cuánto espacio están usando los archivos temporales de todos tus navegadores (seguro, no borra nada).")
        print("2. Limpiar caché de TODOS los navegadores")
        print("   -> Borra los archivos temporales. Es seguro y no borra tu historial ni contraseñas.")
        print("3. Salir")
        print("   -> Cierra el programa.")
        print("=====================================================")
        
        opcion = input("Selecciona una opción (1-3): ").strip()
        
        if opcion == '1':
            show_cache_size()
        elif opcion == '2':
            clean_all_browsers_cache()
        elif opcion == '3':
            print("Saliendo del programa...")
            break
        else:
            print("\nError: Opción no válida. Por favor, selecciona 1, 2 o 3.\n")

if __name__ == "__main__":
    main_menu()
