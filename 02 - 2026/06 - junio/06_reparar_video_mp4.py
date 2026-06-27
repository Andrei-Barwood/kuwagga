#!/usr/bin/env python3
"""
Reparador de video MP4/MOV truncado o corrupto (H.264/H.265).
Usa untrunc y ffmpeg. Compatible con Windows, macOS y Linux.
"""

from __future__ import annotations

import json
import os
import platform
import shutil
import struct
import subprocess
import sys
import time
import urllib.error
import urllib.request
import zipfile
from pathlib import Path

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------

APP_NAME = "Reparador de Video MP4"
APP_VERSION = "1.0.0"

VIDEO_EXTENSIONS = {".mp4", ".m4v", ".mov", ".3gp", ".mkv"}

UNTRUNC_WINDOWS_ASSETS = {
    "64": {
        "name": "untrunc_x64.zip",
        "url": "https://github.com/anthwlock/untrunc/releases/download/latest/untrunc_x64.zip",
        "sha256": "6b77fb70cb64c6e3122176399ce68e78ab4c5d12259eb61a6ec15fa0b90473a5",
    },
    "32": {
        "name": "untrunc_x32.zip",
        "url": "https://github.com/anthwlock/untrunc/releases/download/latest/untrunc_x32.zip",
        "sha256": "82f69e5f732d4e45fde8af0e29727c0ed70bba97b36463d0edbbac4a7e28ca15",
    },
}

UNTRUNC_RETRY_PATTERNS = (
    "premature end",
    "premature eof",
    "structural error",
    "unknown sequence",
    "failed reading",
    "no mp4 structure",
    "unable to find",
)

CONFIG_DIR = Path.home() / ".video_repair"
CONFIG_FILE = CONFIG_DIR / "config.json"
TOOLS_DIR = CONFIG_DIR / "tools"

# -----------------------------------------------------------------------------
# Utilidades de terminal (ASCII seguro)
# -----------------------------------------------------------------------------


def clear_screen() -> None:
    if platform.system() == "Windows":
        os.system("cls")
    else:
        os.system("clear")


def pause(message: str = "Presiona ENTER para continuar...") -> None:
    try:
        input(message)
    except (KeyboardInterrupt, EOFError):
        print("\nOperacion cancelada.")
        sys.exit(0)


def print_header() -> None:
    sistema = platform.system()
    print("=" * 72)
    print(f"  {APP_NAME} v{APP_VERSION}")
    print(f"  Sistema: {sistema} | Python: {sys.version.split()[0]}")
    print("=" * 72)
    print()


def print_ok(msg: str) -> None:
    print(f"[OK] {msg}")


def print_warn(msg: str) -> None:
    print(f"[!] {msg}")


def print_err(msg: str) -> None:
    print(f"[ERROR] {msg}")


def print_info(msg: str) -> None:
    print(f"[*] {msg}")


# -----------------------------------------------------------------------------
# Configuracion persistente
# -----------------------------------------------------------------------------


def load_config() -> dict:
    if not CONFIG_FILE.exists():
        return {}
    try:
        with CONFIG_FILE.open("r", encoding="utf-8") as fh:
            return json.load(fh)
    except (json.JSONDecodeError, OSError):
        return {}


def save_config(data: dict) -> None:
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    with CONFIG_FILE.open("w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2)


def get_untrunc_custom_path() -> str | None:
    cfg = load_config()
    path = cfg.get("untrunc_path")
    if path and Path(path).is_file():
        return path
    return None


def set_untrunc_custom_path(path: str) -> None:
    cfg = load_config()
    cfg["untrunc_path"] = str(Path(path).resolve())
    save_config(cfg)


# -----------------------------------------------------------------------------
# Deteccion de herramientas
# -----------------------------------------------------------------------------


def command_exists(name: str) -> bool:
    return shutil.which(name) is not None


def find_ffmpeg() -> str | None:
    candidates = ["ffmpeg"]
    if platform.system() == "Darwin":
        candidates.extend([
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
        ])
    for candidate in candidates:
        if candidate == "ffmpeg":
            found = shutil.which("ffmpeg")
            if found:
                return found
        elif Path(candidate).is_file():
            return candidate
    return None


def find_brew() -> str | None:
    return shutil.which("brew")


def find_choco() -> str | None:
    return shutil.which("choco")


def find_winget() -> str | None:
    return shutil.which("winget")


def windows_bitness() -> str:
    if struct.calcsize("P") * 8 == 64:
        return "64"
    return "32"


def find_untrunc() -> str | None:
    custom = get_untrunc_custom_path()
    if custom:
        return custom

    if platform.system() == "Windows":
        local_exe = TOOLS_DIR / "untrunc.exe"
        if local_exe.is_file():
            return str(local_exe)
        return shutil.which("untrunc")

    for name in ("untrunc",):
        found = shutil.which(name)
        if found:
            return found

    for candidate in (
        "/opt/homebrew/bin/untrunc",
        "/usr/local/bin/untrunc",
        "/usr/bin/untrunc",
    ):
        if Path(candidate).is_file():
            return candidate
    return None


def run_command(
    cmd: list[str],
    *,
    check: bool = False,
    capture: bool = False,
    cwd: str | None = None,
    shell: bool = False,
) -> subprocess.CompletedProcess:
    kwargs: dict = {
        "cwd": cwd,
        "shell": shell,
    }
    if capture:
        kwargs["stdout"] = subprocess.PIPE
        kwargs["stderr"] = subprocess.STDOUT
        kwargs["text"] = True
        kwargs["encoding"] = "utf-8"
        kwargs["errors"] = "replace"
    return subprocess.run(cmd, check=check, **kwargs)


def run_command_live(cmd: list[str], *, cwd: str | None = None) -> tuple[int, str]:
    """Ejecuta un comando mostrando salida en vivo. Retorna (codigo, salida_completa)."""
    print_info(f"Ejecutando: {' '.join(cmd)}")
    print("-" * 72)

    output_lines: list[str] = []
    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
        cwd=cwd,
    )

    assert proc.stdout is not None
    for line in proc.stdout:
        line = line.rstrip("\n\r")
        output_lines.append(line)
        print(line)

    proc.wait()
    print("-" * 72)
    return proc.returncode or 0, "\n".join(output_lines)


# -----------------------------------------------------------------------------
# Instalacion de dependencias
# -----------------------------------------------------------------------------


def sha256_file(path: Path) -> str:
    import hashlib

    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def download_file(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(url, headers={"User-Agent": APP_NAME})
    with urllib.request.urlopen(req, timeout=120) as response, dest.open("wb") as out:
        shutil.copyfileobj(response, out)


def install_untrunc_windows(*, auto_download: bool = True) -> str | None:
    existing = find_untrunc()
    if existing:
        return existing

    if not auto_download:
        return None

    asset = UNTRUNC_WINDOWS_ASSETS[windows_bitness()]
    print_info(f"Descargando untrunc para Windows ({asset['name']})...")

    TOOLS_DIR.mkdir(parents=True, exist_ok=True)
    zip_path = TOOLS_DIR / asset["name"]

    try:
        download_file(asset["url"], zip_path)
    except (urllib.error.URLError, OSError) as exc:
        print_err(f"No se pudo descargar untrunc: {exc}")
        return None

    digest = sha256_file(zip_path)
    if digest != asset["sha256"]:
        print_err("La suma SHA256 del archivo descargado no coincide. Descarga cancelada.")
        zip_path.unlink(missing_ok=True)
        return None

    try:
        with zipfile.ZipFile(zip_path, "r") as zf:
            zf.extractall(TOOLS_DIR)
    except (zipfile.BadZipFile, OSError) as exc:
        print_err(f"No se pudo extraer untrunc: {exc}")
        return None
    finally:
        zip_path.unlink(missing_ok=True)

    exe_path = TOOLS_DIR / "untrunc.exe"
    if not exe_path.is_file():
        for candidate in TOOLS_DIR.rglob("untrunc.exe"):
            if candidate.is_file():
                if candidate != exe_path:
                    shutil.move(str(candidate), str(exe_path))
                break

    if exe_path.is_file():
        set_untrunc_custom_path(str(exe_path))
        print_ok(f"untrunc instalado en: {exe_path}")
        return str(exe_path)

    print_err("No se encontro untrunc.exe despues de la extraccion.")
    return None


def install_ffmpeg_macos_linux() -> bool:
    brew = find_brew()
    if not brew:
        print_err("Homebrew no esta instalado.")
        print_info("Instala Homebrew desde: https://brew.sh")
        print_info("Luego ejecuta: brew install ffmpeg")
        return False

    if find_ffmpeg():
        print_ok("ffmpeg ya esta disponible.")
        return True

    print_info("Instalando ffmpeg con Homebrew...")
    result = run_command([brew, "install", "ffmpeg"], capture=True)
    if result.returncode == 0 and find_ffmpeg():
        print_ok("ffmpeg instalado correctamente.")
        return True

    print_err("No se pudo instalar ffmpeg con Homebrew.")
    if result.stdout:
        print(result.stdout[-2000:])
    return False


def install_untrunc_macos_linux() -> str | None:
    existing = find_untrunc()
    if existing:
        print_ok(f"untrunc ya esta disponible: {existing}")
        return existing

    brew = find_brew()
    if not brew:
        print_err("Homebrew no esta instalado. No se puede instalar untrunc automaticamente.")
        return compile_untrunc_from_source()

    print_info("Agregando tap ottomatic-io/video...")
    tap_result = run_command([brew, "tap", "ottomatic-io/video"], capture=True)
    if tap_result.returncode != 0:
        print_warn("No se pudo agregar el tap ottomatic-io/video. Intentando compilacion local...")
        return compile_untrunc_from_source()

    print_info("Instalando untrunc con Homebrew...")
    install_result = run_command([brew, "install", "ottomatic-io/video/untrunc"], capture=True)
    if install_result.returncode == 0:
        found = find_untrunc()
        if found:
            print_ok(f"untrunc instalado: {found}")
            return found

    print_warn("La instalacion con Homebrew fallo. Intentando compilacion local...")
    if install_result.stdout:
        print(install_result.stdout[-2000:])
    return compile_untrunc_from_source()


def compile_untrunc_from_source() -> str | None:
    brew = find_brew()
    if not brew:
        print_err("Se requiere Homebrew para compilar untrunc desde el codigo fuente.")
        return None

    if not find_ffmpeg():
        print_info("Instalando ffmpeg (requerido para compilar untrunc)...")
        run_command([brew, "install", "ffmpeg", "yasm"], capture=False)

    build_root = CONFIG_DIR / "untrunc-src"
    if build_root.exists():
        shutil.rmtree(build_root, ignore_errors=True)
    build_root.mkdir(parents=True, exist_ok=True)

    print_info("Clonando repositorio anthwlock/untrunc...")
    clone = run_command(
        ["git", "clone", "--depth", "1", "https://github.com/anthwlock/untrunc.git", str(build_root)],
        capture=True,
    )
    if clone.returncode != 0:
        print_err("No se pudo clonar el repositorio untrunc.")
        if clone.stdout:
            print(clone.stdout)
        return None

    env = os.environ.copy()
    if platform.system() == "Darwin":
        brew_prefix = run_command([brew, "--prefix"], capture=True)
        if brew_prefix.returncode == 0:
            prefix = brew_prefix.stdout.strip()
            env["CPPFLAGS"] = f"-I{prefix}/include"
            env["LDFLAGS"] = f"-L{prefix}/lib"

    print_info("Compilando untrunc (puede tardar varios minutos)...")
    make = subprocess.run(
        ["make", "all"],
        cwd=str(build_root),
        env=env,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if make.returncode != 0:
        print_err("La compilacion de untrunc fallo.")
        combined = (make.stdout or "") + (make.stderr or "")
        if combined:
            print(combined[-3000:])
        return None

    built = build_root / "untrunc"
    if not built.is_file():
        print_err("El binario untrunc no se genero.")
        return None

    dest = TOOLS_DIR / "untrunc"
    TOOLS_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copy2(built, dest)
    dest.chmod(dest.stat().st_mode | 0o111)
    set_untrunc_custom_path(str(dest))
    print_ok(f"untrunc compilado e instalado en: {dest}")
    return str(dest)


def install_ffmpeg_windows() -> bool:
    if find_ffmpeg():
        print_ok("ffmpeg ya esta disponible.")
        return True

    choco = find_choco()
    if choco:
        print_info("Instalando ffmpeg con Chocolatey...")
        result = run_command([choco, "install", "ffmpeg", "-y"], capture=True)
        if result.returncode == 0 and find_ffmpeg():
            print_ok("ffmpeg instalado con Chocolatey.")
            return True
        print_warn("Chocolatey no pudo instalar ffmpeg.")

    winget = find_winget()
    if winget:
        print_info("Instalando ffmpeg con winget...")
        result = run_command(
            [winget, "install", "--id", "Gyan.FFmpeg", "-e", "--accept-package-agreements", "--accept-source-agreements"],
            capture=True,
        )
        if result.returncode == 0 and find_ffmpeg():
            print_ok("ffmpeg instalado con winget.")
            return True
        # Algunas versiones usan otro id
        result = run_command(
            [winget, "install", "ffmpeg", "-e", "--accept-package-agreements", "--accept-source-agreements"],
            capture=True,
        )
        if result.returncode == 0 and find_ffmpeg():
            print_ok("ffmpeg instalado con winget.")
            return True
        print_warn("winget no pudo instalar ffmpeg.")

    print_err("No se encontro choco ni winget, o la instalacion fallo.")
    print_info("Instala ffmpeg manualmente desde: https://ffmpeg.org/download.html")
    return False


def ensure_dependencies(*, interactive: bool = True) -> tuple[str | None, str | None]:
    sistema = platform.system()

    ffmpeg = find_ffmpeg()
    untrunc = find_untrunc()

    missing_ffmpeg = ffmpeg is None
    missing_untrunc = untrunc is None

    if not missing_ffmpeg and not missing_untrunc:
        return ffmpeg, untrunc

    print_warn("Faltan dependencias:")
    if missing_ffmpeg:
        print("  - ffmpeg")
    if missing_untrunc:
        print("  - untrunc")

    if interactive:
        resp = input("Deseas intentar instalarlas automaticamente? (s/n): ").strip().lower()
        if resp not in ("s", "si", "y", "yes"):
            return ffmpeg, untrunc

    if sistema in ("Darwin", "Linux"):
        if missing_ffmpeg:
            install_ffmpeg_macos_linux()
            ffmpeg = find_ffmpeg()
        if missing_untrunc:
            untrunc = install_untrunc_macos_linux()
    elif sistema == "Windows":
        if missing_ffmpeg:
            install_ffmpeg_windows()
            ffmpeg = find_ffmpeg()
        if missing_untrunc:
            untrunc = install_untrunc_windows(auto_download=True)
            if not untrunc:
                print_warn("untrunc no esta disponible en Windows via gestor de paquetes.")
                print_info("Opciones:")
                print_info("  1. Menu -> Configurar ruta de untrunc.exe")
                print_info("  2. Descarga manual: https://github.com/anthwlock/untrunc/releases/latest")
    else:
        print_err(f"Sistema operativo no soportado: {sistema}")

    return ffmpeg, untrunc


# -----------------------------------------------------------------------------
# Validacion de archivos
# -----------------------------------------------------------------------------


def normalize_path(raw: str) -> Path:
    path = Path(raw.strip().strip('"').strip("'")).expanduser()
    return path.resolve()


def is_video_file(path: Path) -> bool:
    return path.is_file() and path.suffix.lower() in VIDEO_EXTENSIONS


def prompt_file_path(label: str, *, must_exist: bool = True) -> Path | None:
    while True:
        raw = input(f"{label}: ").strip()
        if not raw:
            print_warn("Debes ingresar una ruta.")
            continue
        try:
            path = normalize_path(raw)
        except OSError as exc:
            print_err(f"Ruta invalida: {exc}")
            continue

        if must_exist and not path.is_file():
            print_err(f"No se encontro el archivo: {path}")
            continue
        if must_exist and not is_video_file(path):
            print_warn(f"La extension '{path.suffix}' puede no ser compatible. Continuando de todos modos...")
        return path


def default_output_path(corrupt: Path, suffix: str) -> Path:
    return corrupt.with_name(f"{corrupt.stem}_{suffix}{corrupt.suffix}")


# -----------------------------------------------------------------------------
# Logica de reparacion
# -----------------------------------------------------------------------------


def output_indicates_retry(output: str) -> bool:
    lowered = output.lower()
    return any(pattern in lowered for pattern in UNTRUNC_RETRY_PATTERNS)


def build_untrunc_cmd(untrunc: str, reference: Path, corrupt: Path, *, skip_unknown: bool) -> list[str]:
    cmd = [untrunc]
    if skip_unknown:
        cmd.append("-s")
    cmd.extend([str(reference), str(corrupt)])
    return cmd


def run_untrunc_repair(untrunc: str, reference: Path, corrupt: Path) -> tuple[bool, Path | None, str]:
    expected = default_output_path(corrupt, "fixed")

    code, output = run_command_live(build_untrunc_cmd(untrunc, reference, corrupt, skip_unknown=False))

    success = code == 0 and expected.is_file()
    if success and not output_indicates_retry(output):
        return True, expected, output

    needs_retry = (not success) or output_indicates_retry(output)
    if needs_retry:
        print_warn("Reintentando untrunc con bandera -s (omitir secuencias desconocidas)...")
        code2, output2 = run_command_live(
            build_untrunc_cmd(untrunc, reference, corrupt, skip_unknown=True)
        )
        combined = output + "\n" + output2
        if code2 == 0 and expected.is_file():
            return True, expected, combined
        return False, expected if expected.is_file() else None, combined

    return False, None, output


def run_ffmpeg_remux(ffmpeg: str, corrupt: Path) -> tuple[bool, Path | None, str]:
    out_path = default_output_path(corrupt, "remux")
    strategies = [
        [
            ffmpeg, "-hide_banner", "-y",
            "-fflags", "+genpts+discardcorrupt",
            "-err_detect", "ignore_err",
            "-i", str(corrupt),
            "-c", "copy",
            "-movflags", "+faststart",
            str(out_path),
        ],
        [
            ffmpeg, "-hide_banner", "-y",
            "-i", str(corrupt),
            "-c", "copy",
            str(out_path),
        ],
    ]

    combined_output: list[str] = []
    for idx, cmd in enumerate(strategies, start=1):
        print_info(f"Estrategia ffmpeg #{idx}...")
        code, output = run_command_live(cmd)
        combined_output.append(output)
        if code == 0 and out_path.is_file() and out_path.stat().st_size > 0:
            return True, out_path, "\n".join(combined_output)

    return False, None, "\n".join(combined_output)


def repair_video(reference: Path, corrupt: Path) -> None:
    ffmpeg, untrunc = ensure_dependencies(interactive=False)

    print()
    print_info(f"Referencia: {reference}")
    print_info(f"Corrupto:   {corrupt}")
    print()

    if untrunc:
        print_info("Paso 1: Reparacion con untrunc")
        ok, out_file, log = run_untrunc_repair(untrunc, reference, corrupt)
        if ok and out_file:
            print_ok(f"Video reparado con untrunc: {out_file}")
            print_info(f"Tamano: {out_file.stat().st_size / (1024 * 1024):.2f} MB")
            return
        print_warn("untrunc no pudo reparar el archivo completamente.")
        if out_file and out_file.is_file():
            print_info(f"Se genero un archivo parcial: {out_file}")
    else:
        print_warn("untrunc no disponible. Se omitira la reparacion estructural.")

    if ffmpeg:
        print()
        print_info("Paso 2: Respaldo con ffmpeg (remux / copia de flujo)")
        ok, out_file, _ = run_ffmpeg_remux(ffmpeg, corrupt)
        if ok and out_file:
            print_ok(f"Remux completado: {out_file}")
            print_info(f"Tamano: {out_file.stat().st_size / (1024 * 1024):.2f} MB")
            return
        print_err("ffmpeg tampoco pudo recuperar el video.")
    else:
        print_err("ffmpeg no disponible. No hay mas opciones de respaldo.")

    print_err("La reparacion fallo. Verifica que el video de referencia sea del mismo dispositivo/formato.")


# -----------------------------------------------------------------------------
# Menus
# -----------------------------------------------------------------------------


def menu_configure_untrunc() -> None:
    print()
    print_info("Configuracion de untrunc (principalmente para Windows)")
    print_info("Descarga oficial: https://github.com/anthwlock/untrunc/releases/latest")
    print()

    if platform.system() == "Windows":
        resp = input("Deseas descargar untrunc automaticamente desde GitHub? (s/n): ").strip().lower()
        if resp in ("s", "si", "y", "yes"):
            path = install_untrunc_windows(auto_download=True)
            if path:
                print_ok(f"untrunc listo: {path}")
                pause()
                return

    raw = input("Ingresa la ruta completa a untrunc" + (".exe" if platform.system() == "Windows" else "") + ": ").strip()
    if not raw:
        print_warn("No se ingreso ninguna ruta.")
        pause()
        return

    try:
        path = normalize_path(raw)
    except OSError as exc:
        print_err(str(exc))
        pause()
        return

    if not path.is_file():
        print_err("El archivo no existe.")
        pause()
        return

    set_untrunc_custom_path(str(path))
    print_ok(f"Ruta guardada: {path}")
    pause()


def menu_check_dependencies() -> None:
    print()
    ffmpeg = find_ffmpeg()
    untrunc = find_untrunc()
    brew = find_brew()
    choco = find_choco()
    winget = find_winget()

    print_info("Estado de dependencias:")
    print(f"  ffmpeg:  {ffmpeg or 'NO ENCONTRADO'}")
    print(f"  untrunc: {untrunc or 'NO ENCONTRADO'}")
    print()

    sistema = platform.system()
    if sistema in ("Darwin", "Linux"):
        print(f"  brew:    {brew or 'NO ENCONTRADO'}")
    elif sistema == "Windows":
        print(f"  choco:   {choco or 'NO ENCONTRADO'}")
        print(f"  winget:  {winget or 'NO ENCONTRADO'}")

    if not ffmpeg or not untrunc:
        print()
        ensure_dependencies(interactive=True)
    else:
        print_ok("Todas las dependencias principales estan listas.")

    pause()


def menu_repair() -> None:
    print()
    print_info("Selecciona el video de REFERENCIA (sano, del mismo origen).")
    reference = prompt_file_path("Ruta del video de referencia")
    if not reference:
        return

    print()
    print_info("Selecciona el video CORRUPTO o TRUNCADO a reparar.")
    corrupt = prompt_file_path("Ruta del video corrupto")
    if not corrupt:
        return

    if reference.resolve() == corrupt.resolve():
        print_err("Los dos archivos son el mismo. Abortando.")
        pause()
        return

    print()
    confirm = input("Iniciar reparacion? (s/n): ").strip().lower()
    if confirm not in ("s", "si", "y", "yes"):
        print_warn("Reparacion cancelada.")
        pause()
        return

    repair_video(reference, corrupt)
    pause()


def show_main_menu() -> None:
    while True:
        clear_screen()
        print_header()

        ffmpeg = find_ffmpeg()
        untrunc = find_untrunc()
        dep_status = "LISTO" if (ffmpeg and untrunc) else "INCOMPLETO"
        print(f"Dependencias: {dep_status}")
        if ffmpeg:
            print(f"  ffmpeg:  {ffmpeg}")
        if untrunc:
            print(f"  untrunc: {untrunc}")
        print()

        print("Menu principal:")
        print("  1. Reparar video truncado/corrupto")
        print("  2. Verificar / instalar dependencias")
        print("  3. Configurar ruta de untrunc")
        print("  4. Salir")
        print()

        choice = input("Selecciona una opcion (1-4): ").strip()

        if choice == "1":
            menu_repair()
        elif choice == "2":
            menu_check_dependencies()
        elif choice == "3":
            menu_configure_untrunc()
        elif choice == "4":
            print_info("Saliendo...")
            sys.exit(0)
        else:
            print_warn("Opcion invalida.")
            time.sleep(1)


# -----------------------------------------------------------------------------
# Punto de entrada CLI
# -----------------------------------------------------------------------------


def parse_cli_args() -> dict:
    args = {
        "reference": None,
        "corrupt": None,
        "untrunc_path": None,
        "install_deps": False,
        "no_menu": False,
    }
    argv = sys.argv[1:]
    i = 0
    while i < len(argv):
        token = argv[i]
        if token in ("-h", "--help"):
            print(__doc__)
            print("Uso:")
            print("  python 06_reparar_video_mp4.py")
            print("  python 06_reparar_video_mp4.py --install-deps")
            print("  python 06_reparar_video_mp4.py --reference OK.mp4 --corrupt BAD.mp4")
            print("  python 06_reparar_video_mp4.py --untrunc-path C:\\tools\\untrunc.exe")
            sys.exit(0)
        elif token == "--install-deps":
            args["install_deps"] = True
        elif token == "--no-menu":
            args["no_menu"] = True
        elif token == "--reference" and i + 1 < len(argv):
            i += 1
            args["reference"] = argv[i]
        elif token == "--corrupt" and i + 1 < len(argv):
            i += 1
            args["corrupt"] = argv[i]
        elif token == "--untrunc-path" and i + 1 < len(argv):
            i += 1
            args["untrunc_path"] = argv[i]
        i += 1
    return args


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        try:
            sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, OSError, ValueError):
            pass
    if hasattr(sys.stdin, "reconfigure"):
        try:
            sys.stdin.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, OSError, ValueError):
            pass

    args = parse_cli_args()

    if args["untrunc_path"]:
        try:
            p = normalize_path(args["untrunc_path"])
            if p.is_file():
                set_untrunc_custom_path(str(p))
            else:
                print_err(f"untrunc no encontrado en: {p}")
                sys.exit(1)
        except OSError as exc:
            print_err(str(exc))
            sys.exit(1)

    if args["install_deps"]:
        ensure_dependencies(interactive=False)
        sys.exit(0)

    if args["reference"] and args["corrupt"]:
        try:
            reference = normalize_path(args["reference"])
            corrupt = normalize_path(args["corrupt"])
        except OSError as exc:
            print_err(str(exc))
            sys.exit(1)
        if not reference.is_file() or not corrupt.is_file():
            print_err("Uno o ambos archivos de video no existen.")
            sys.exit(1)
        repair_video(reference, corrupt)
        sys.exit(0)

    show_main_menu()


if __name__ == "__main__":
    main()