#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import platform
import shlex
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Sequence


PlatformName = str
ServiceKey = str

SERVICE_ORDER: tuple[ServiceKey, ...] = (
    "onedrive",
    "downloads",
    "indexing",
    "snapshots",
    "failed_updates",
)

SERVICE_INFO: dict[ServiceKey, tuple[str, str]] = {
    "onedrive": (
        "OneDrive auto-actualizaciones",
        "Detiene OneDrive y desactiva tareas o agentes de update automatico.",
    ),
    "downloads": (
        "Descargas automaticas de OneDrive",
        "Fuerza modo bajo demanda cuando aplica y limpia cache/logs locales.",
    ),
    "indexing": (
        "Indexacion tipo Spotlight",
        "Desactiva servicios de indexado de archivos para reducir uso de disco.",
    ),
    "snapshots": (
        "Snapshots locales",
        "Desactiva y elimina snapshots (Time Machine, VSS, timeshift).",
    ),
    "failed_updates": (
        "Actualizaciones fallidas",
        "Limpia descargas y cache residual de updates incompletos.",
    ),
}


@dataclass
class CommandRecord:
    command: str
    returncode: int
    optional: bool
    stderr: str


class Runner:
    def __init__(self, apply_changes: bool, verbose: bool) -> None:
        self.apply_changes = apply_changes
        self.verbose = verbose
        self.records: list[CommandRecord] = []

    def run(
        self,
        cmd: Sequence[str] | str,
        *,
        optional: bool = True,
        shell: bool = False,
    ) -> subprocess.CompletedProcess[str] | None:
        printable = cmd if isinstance(cmd, str) else shlex.join(cmd)
        mode = "APPLY" if self.apply_changes else "DRY-RUN"
        print(f"[{mode}] {printable}")

        if not self.apply_changes:
            return None

        try:
            completed = subprocess.run(
                cmd,
                shell=shell,
                check=False,
                text=True,
                capture_output=True,
            )
        except FileNotFoundError as exc:
            message = f"command not found: {exc.filename}"
            level = "WARN" if optional else "ERROR"
            print(f"  -> {level}: {message}")
            self.records.append(CommandRecord(printable, 127, optional, message))
            return None

        if self.verbose and completed.stdout.strip():
            print("  stdout:")
            for line in completed.stdout.strip().splitlines():
                print(f"    {line}")

        if completed.returncode != 0:
            level = "WARN" if optional else "ERROR"
            stderr = completed.stderr.strip() or "no stderr output"
            print(f"  -> {level} (exit {completed.returncode}): {stderr}")

        self.records.append(
            CommandRecord(
                command=printable,
                returncode=completed.returncode,
                optional=optional,
                stderr=completed.stderr.strip(),
            )
        )
        return completed

    def summary(self) -> int:
        if not self.apply_changes:
            print("\nSummary: dry-run complete. No changes were applied.")
            return 0

        hard_failures = [r for r in self.records if r.returncode != 0 and not r.optional]
        soft_failures = [r for r in self.records if r.returncode != 0 and r.optional]

        print("\nSummary:")
        print(f"- Commands executed: {len(self.records)}")
        print(f"- Mandatory failures: {len(hard_failures)}")
        print(f"- Optional failures: {len(soft_failures)}")

        return 1 if hard_failures else 0


def section(title: str) -> None:
    print(f"\n== {title} ==")


def detect_platform(choice: str) -> PlatformName:
    if choice != "auto":
        return choice

    sys_name = platform.system().lower()
    if sys_name == "darwin":
        return "macos"
    if sys_name == "windows":
        return "windows"
    if sys_name == "linux":
        return "linux"
    raise RuntimeError(f"unsupported platform: {sys_name}")


def resolve_macos_onedrive_roots(override: str | None) -> list[Path]:
    if override:
        return [Path(override).expanduser()]

    roots: list[Path] = []
    cloud_storage = Path.home() / "Library" / "CloudStorage"
    if cloud_storage.exists():
        roots.extend(
            path for path in cloud_storage.iterdir() if path.is_dir() and path.name.lower().startswith("onedrive")
        )

    fallback = Path.home() / "OneDrive"
    if not roots and fallback.exists():
        roots.append(fallback)

    return roots


def resolve_windows_onedrive_root(override: str | None) -> Path | None:
    if override:
        return Path(override).expanduser()

    user_profile = os.environ.get("UserProfile")
    if not user_profile:
        return None

    candidate = Path(user_profile) / "OneDrive"
    return candidate


def resolve_linux_onedrive_root(override: str | None) -> Path:
    if override:
        return Path(override).expanduser()
    return Path.home() / "OneDrive"


def macos_disable_onedrive_updates(runner: Runner) -> None:
    section("macOS: disable OneDrive and Microsoft AutoUpdate")
    runner.run(["pkill", "-f", "OneDrive"], optional=True)
    runner.run(
        ["defaults", "write", "com.microsoft.autoupdate2", "HowToCheck", "-string", "Manual"],
        optional=True,
    )
    runner.run(
        ["defaults", "write", "com.microsoft.autoupdate2", "AutomaticDownload", "-bool", "false"],
        optional=True,
    )

    agents = [
        Path.home() / "Library" / "LaunchAgents" / "com.microsoft.OneDriveStandaloneUpdater.plist",
        Path.home() / "Library" / "LaunchAgents" / "com.microsoft.update.agent.plist",
        Path("/Library/LaunchAgents/com.microsoft.update.agent.plist"),
    ]
    for agent in agents:
        if agent.exists():
            runner.run(["launchctl", "unload", "-w", str(agent)], optional=True)
        else:
            print(f"[INFO] LaunchAgent not found: {agent}")


def macos_reduce_onedrive_downloads(runner: Runner, onedrive_path: str | None) -> None:
    section("macOS: reduce automatic OneDrive local downloads")
    roots = resolve_macos_onedrive_roots(onedrive_path)
    if not roots:
        print("[INFO] OneDrive folder not found automatically. Use --onedrive-path if needed.")

    if shutil.which("fileproviderctl"):
        for root in roots:
            runner.run(["fileproviderctl", "evict", str(root)], optional=True)
    else:
        print("[INFO] fileproviderctl not available; skipping cloud file eviction.")

    onedrive_cache = Path.home() / "Library" / "Containers" / "com.microsoft.OneDrive-mac" / "Data" / "Library" / "Caches"
    runner.run(f'rm -rf "{onedrive_cache}"/*', shell=True, optional=True)
    runner.run(f'rm -rf "{Path.home() / "Library" / "Logs" / "OneDrive"}"/*', shell=True, optional=True)


def macos_disable_indexing(runner: Runner) -> None:
    section("macOS: disable Spotlight indexing")
    runner.run(["sudo", "mdutil", "-i", "off", "/"], optional=False)
    runner.run(["sudo", "mdutil", "-E", "/"], optional=True)


def macos_purge_snapshots(runner: Runner) -> None:
    section("macOS: disable Time Machine and purge local snapshots")
    runner.run(["sudo", "tmutil", "disable"], optional=True)
    list_result = runner.run(["tmutil", "listlocalsnapshots", "/"], optional=True)

    if not list_result or list_result.returncode != 0:
        print("[INFO] Could not list local snapshots.")
        return

    marker = "com.apple.TimeMachine."
    snapshots: list[str] = []
    for line in list_result.stdout.splitlines():
        if marker in line:
            snapshots.append(line.split(marker, 1)[1].strip())

    if not snapshots:
        print("[INFO] No local snapshots found.")
        return

    for snapshot in snapshots:
        runner.run(["sudo", "tmutil", "deletelocalsnapshots", snapshot], optional=True)


def macos_cleanup_failed_updates(runner: Runner) -> None:
    section("macOS: cleanup failed update leftovers")
    runner.run("sudo rm -rf /Library/Updates/*", shell=True, optional=True)
    runner.run(f'rm -rf "{Path.home() / "Library" / "Caches" / "com.apple.SoftwareUpdate"}"/*', shell=True, optional=True)


def windows_disable_onedrive_updates(runner: Runner) -> None:
    section("Windows: disable OneDrive auto-updates and background tasks")
    disable_tasks_script = (
        "Get-ScheduledTask | "
        "Where-Object { $_.TaskName -like '*OneDrive*' -or $_.TaskPath -like '*OneDrive*' } | "
        "Disable-ScheduledTask -ErrorAction SilentlyContinue"
    )
    runner.run(
        ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", disable_tasks_script],
        optional=True,
    )
    runner.run(["taskkill", "/IM", "OneDrive.exe", "/F"], optional=True)
    runner.run(
        r'reg add "HKCU\Software\Microsoft\OneDrive" /v EnableAutoUpdate /t REG_DWORD /d 0 /f',
        shell=True,
        optional=True,
    )
    runner.run(
        r'reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v OneDrive /f',
        shell=True,
        optional=True,
    )


def windows_reduce_onedrive_downloads(runner: Runner, onedrive_path: str | None) -> None:
    section("Windows: reduce OneDrive automatic downloads")
    root = resolve_windows_onedrive_root(onedrive_path)
    if root:
        runner.run(f'attrib +U -P "{root}\\*" /S /D', shell=True, optional=True)
    else:
        print("[INFO] UserProfile not found; cannot derive OneDrive path.")

    runner.run(
        r'reg add "HKCU\Software\Microsoft\OneDrive" /v FilesOnDemandEnabled /t REG_DWORD /d 1 /f',
        shell=True,
        optional=True,
    )
    runner.run(
        r'cmd /c if exist "%LOCALAPPDATA%\Microsoft\OneDrive\logs" rd /s /q "%LOCALAPPDATA%\Microsoft\OneDrive\logs"',
        shell=True,
        optional=True,
    )


def windows_disable_indexing(runner: Runner) -> None:
    section("Windows: disable Search indexing service (Spotlight-like)")
    runner.run(["sc", "stop", "WSearch"], optional=True)
    runner.run(["sc", "config", "WSearch", "start=", "disabled"], optional=True)


def windows_purge_snapshots(runner: Runner) -> None:
    section("Windows: purge Volume Shadow Copy snapshots")
    runner.run(["vssadmin", "delete", "shadows", "/all", "/quiet"], optional=True)


def windows_cleanup_failed_updates(runner: Runner) -> None:
    section("Windows: cleanup failed Windows Update downloads")
    runner.run(["net", "stop", "wuauserv"], optional=True)
    runner.run(["net", "stop", "bits"], optional=True)
    runner.run(
        r'cmd /c if exist "%windir%\SoftwareDistribution\Download" rd /s /q "%windir%\SoftwareDistribution\Download"',
        shell=True,
        optional=True,
    )
    runner.run(["net", "start", "bits"], optional=True)
    runner.run(["net", "start", "wuauserv"], optional=True)


def linux_disable_onedrive_updates(runner: Runner) -> None:
    section("Linux: disable OneDrive auto-sync services")
    runner.run(["systemctl", "--user", "disable", "--now", "onedrive.service"], optional=True)
    runner.run(["systemctl", "--user", "disable", "--now", "onedrive.timer"], optional=True)
    runner.run(["sudo", "systemctl", "disable", "--now", "onedrive.service", "onedrive.timer"], optional=True)


def linux_reduce_onedrive_downloads(runner: Runner, onedrive_path: str | None) -> None:
    section("Linux: reduce OneDrive local disk usage")
    root = resolve_linux_onedrive_root(onedrive_path)
    if root.exists():
        runner.run(
            f'find "{root}" -type f \\( -name "*.tmp" -o -name "*.partial" -o -name "*.download" \\) -delete',
            shell=True,
            optional=True,
        )
    else:
        print(f"[INFO] OneDrive path not found: {root}")

    runner.run(f'rm -rf "{Path.home() / ".cache" / "onedrive"}"/*', shell=True, optional=True)


def linux_disable_indexing(runner: Runner) -> None:
    section("Linux: disable Tracker indexing (Spotlight-like)")
    runner.run(
        [
            "systemctl",
            "--user",
            "mask",
            "--now",
            "tracker-miner-fs-3.service",
            "tracker-extract-3.service",
            "tracker-store.service",
        ],
        optional=True,
    )
    runner.run(
        ["systemctl", "--user", "mask", "--now", "tracker-miner-fs.service", "tracker-store.service"],
        optional=True,
    )


def linux_purge_snapshots(runner: Runner) -> None:
    section("Linux: purge snapshot tools")
    if shutil.which("timeshift"):
        runner.run(["sudo", "systemctl", "disable", "--now", "timeshift.timer"], optional=True)
        runner.run(["sudo", "timeshift", "--delete-all", "--scripted"], optional=True)
    else:
        print("[INFO] timeshift not installed; generic snapshot purge skipped.")


def linux_cleanup_failed_updates(runner: Runner) -> None:
    section("Linux: cleanup failed update caches")
    if shutil.which("apt-get"):
        runner.run(["sudo", "systemctl", "disable", "--now", "apt-daily.timer", "apt-daily-upgrade.timer"], optional=True)
        runner.run(["sudo", "apt-get", "clean"], optional=True)
        runner.run(["sudo", "apt-get", "autoremove", "-y"], optional=True)
        runner.run("sudo rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/partial/*", shell=True, optional=True)

    if shutil.which("dnf"):
        runner.run(["sudo", "systemctl", "disable", "--now", "dnf-automatic.timer"], optional=True)
        runner.run(["sudo", "dnf", "clean", "all"], optional=True)

    if shutil.which("yum"):
        runner.run(["sudo", "yum", "clean", "all"], optional=True)

    if shutil.which("pacman"):
        runner.run(["sudo", "pacman", "-Scc", "--noconfirm"], optional=True)

    if shutil.which("zypper"):
        runner.run(["sudo", "zypper", "clean", "-a"], optional=True)

    if shutil.which("snap"):
        runner.run(["sudo", "systemctl", "disable", "--now", "snapd.refresh.timer"], optional=True)


def execute_service(target: PlatformName, service: ServiceKey, runner: Runner, onedrive_path: str | None) -> None:
    if target == "macos":
        if service == "onedrive":
            macos_disable_onedrive_updates(runner)
            return
        if service == "downloads":
            macos_reduce_onedrive_downloads(runner, onedrive_path)
            return
        if service == "indexing":
            macos_disable_indexing(runner)
            return
        if service == "snapshots":
            macos_purge_snapshots(runner)
            return
        if service == "failed_updates":
            macos_cleanup_failed_updates(runner)
            return

    if target == "windows":
        if service == "onedrive":
            windows_disable_onedrive_updates(runner)
            return
        if service == "downloads":
            windows_reduce_onedrive_downloads(runner, onedrive_path)
            return
        if service == "indexing":
            windows_disable_indexing(runner)
            return
        if service == "snapshots":
            windows_purge_snapshots(runner)
            return
        if service == "failed_updates":
            windows_cleanup_failed_updates(runner)
            return

    if target == "linux":
        if service == "onedrive":
            linux_disable_onedrive_updates(runner)
            return
        if service == "downloads":
            linux_reduce_onedrive_downloads(runner, onedrive_path)
            return
        if service == "indexing":
            linux_disable_indexing(runner)
            return
        if service == "snapshots":
            linux_purge_snapshots(runner)
            return
        if service == "failed_updates":
            linux_cleanup_failed_updates(runner)
            return

    raise RuntimeError(f"unsupported target/service combination: {target}/{service}")


def execute_selected_services(
    target: PlatformName,
    runner: Runner,
    onedrive_path: str | None,
    selected_services: Sequence[ServiceKey],
) -> None:
    for service in SERVICE_ORDER:
        if service in selected_services:
            execute_service(target, service, runner, onedrive_path)


def selected_services_from_args(args: argparse.Namespace) -> list[ServiceKey]:
    selected: list[ServiceKey] = []
    if not args.skip_onedrive:
        selected.append("onedrive")
    if not args.skip_downloads:
        selected.append("downloads")
    if not args.skip_indexing:
        selected.append("indexing")
    if not args.skip_snapshots:
        selected.append("snapshots")
    if not args.skip_failed_updates:
        selected.append("failed_updates")
    return selected


def run_actions(target: PlatformName, runner: Runner, args: argparse.Namespace) -> None:
    selected = selected_services_from_args(args)
    execute_selected_services(
        target=target,
        runner=runner,
        onedrive_path=args.onedrive_path,
        selected_services=selected,
    )


def print_menu_header(target: PlatformName, apply_changes: bool, onedrive_path: str | None) -> None:
    mode = "APPLY (real)" if apply_changes else "DRY-RUN (simulacion)"
    print("\n==================== Menu de Limpieza de Disco ====================")
    print("Objetivo: liberar espacio desactivando automatismos y limpiando cache residual.")
    print("Metodo: ejecuta comandos nativos del sistema (launchctl/systemctl/reg/tmutil/etc).")
    print(f"Plataforma actual: {target}")
    print(f"Modo actual: {mode}")
    print(f"Ruta OneDrive: {onedrive_path or 'auto-detectada'}")
    print("===================================================================")
    print_mode_explanation_for_menu(apply_changes=apply_changes)


def print_dry_run_explanation() -> None:
    print("\nExplicacion detallada de DRY-RUN:")
    print("- DRY-RUN es un modo de simulacion segura: no aplica cambios en el sistema.")
    print("- El script solo muestra los comandos que ejecutaria, marcados como [DRY-RUN].")
    print("- En este modo no se borran archivos, no se desactivan servicios y no se cambian registros.")
    print("- Tampoco se valida el resultado real de comandos (permisos, errores runtime, estado final).")
    print("- Sirve para auditar el plan: revisar rutas, comandos y alcance antes de tocar el sistema.")
    print("- Para ejecutar cambios reales debes activar APPLY (menu opcion 3 o flag --apply).")
    print('- En APPLY el script te pide confirmacion explicita escribiendo "SI".')
    print("")


def print_apply_explanation() -> None:
    print("\nExplicacion detallada de APPLY:")
    print("- APPLY ejecuta de verdad cada comando mostrado por el programa.")
    print("- Puede detener servicios, borrar cache/logs y modificar configuraciones del sistema.")
    print("- Algunas acciones necesitan permisos sudo/admin y pueden pedir credenciales.")
    print("- El resultado depende del estado real del equipo (rutas, servicios instalados, permisos).")
    print("- Antes de ejecutar, revisa la ruta de OneDrive y la plataforma seleccionada.")
    print('- Seguridad: antes de correr APPLY, debes confirmar escribiendo "SI".')
    print("")


def print_mode_explanation_for_menu(apply_changes: bool) -> None:
    if apply_changes:
        print_apply_explanation()
    else:
        print_dry_run_explanation()


def print_macos_setup_guide() -> None:
    print("\nSetup completo para macOS (sin salir de terminal):")
    print("1) Instalar Homebrew (si no lo tienes):")
    print('   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"')
    print("2) Instalar pyenv y plugin de virtualenv:")
    print("   brew update")
    print("   brew install pyenv pyenv-virtualenv")
    print("3) Inicializar pyenv en zsh y recargar shell:")
    print('   echo \'export PYENV_ROOT=\"$HOME/.pyenv\"\' >> ~/.zshrc')
    print('   echo \'export PATH=\"$PYENV_ROOT/bin:$PATH\"\' >> ~/.zshrc')
    print('   echo \'eval \"$(pyenv init - zsh)\"\' >> ~/.zshrc')
    print('   echo \'eval \"$(pyenv virtualenv-init -)\"\' >> ~/.zshrc')
    print('   exec \"$SHELL\"')
    print("4) Instalar Python 3.13.9 y crear entorno:")
    print("   pyenv install 3.13.9")
    print("   pyenv virtualenv 3.13.9 hokkaido")
    print("5) Activar en este proyecto y ejecutar:")
    print("   pyenv local hokkaido")
    print("   python --version")
    print("   python onedrive_space_optimizer.py --menu")


def print_windows_setup_guide() -> None:
    print("\nSetup completo para Windows (PowerShell como Administrador):")
    print("1) Instalar Chocolatey desde linea de comandos:")
    print("   Set-ExecutionPolicy Bypass -Scope Process -Force;")
    print("   [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072;")
    print("   iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))")
    print("2) Verificar Chocolatey:")
    print("   choco -v")
    print("3) Instalar pyenv-win:")
    print("   choco install pyenv-win -y")
    print("4) Cerrar y abrir PowerShell para refrescar PATH, luego:")
    print("   pyenv install 3.13.9")
    print("   pyenv local 3.13.9")
    print("5) Crear y activar entorno virtual:")
    print("   python -m venv hokkaido")
    print("   .\\hokkaido\\Scripts\\Activate.ps1")
    print("6) Verificar y ejecutar:")
    print("   python --version")
    print("   python .\\onedrive_space_optimizer.py --menu")
    print("Nota cmd.exe:")
    print("   hokkaido\\Scripts\\activate.bat")


def print_linux_setup_guide() -> None:
    print("\nSetup completo para Linux (sin salir de terminal):")
    print("1) Instalar dependencias segun gestor detectado:")
    print("   if command -v apt >/dev/null 2>&1; then")
    print("     sudo apt update && sudo apt install -y pyenv build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev libffi-dev liblzma-dev tk-dev")
    print("   elif command -v dnf >/dev/null 2>&1; then")
    print("     sudo dnf install -y pyenv gcc make patch zlib-devel bzip2 bzip2-devel readline-devel sqlite sqlite-devel openssl-devel libffi-devel xz-devel tk-devel")
    print("   elif command -v pacman >/dev/null 2>&1; then")
    print("     sudo pacman -S --needed pyenv base-devel openssl zlib xz tk")
    print("   elif command -v zypper >/dev/null 2>&1; then")
    print("     sudo zypper install -y pyenv gcc make patch zlib-devel libbz2-devel readline-devel sqlite3-devel libopenssl-devel libffi-devel xz-devel tk-devel")
    print("   else")
    print("     echo \"No se detecto gestor nativo. Instalando Linuxbrew...\"")
    print("     /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"")
    print("     if [ -d /home/linuxbrew/.linuxbrew ]; then")
    print("       eval \"$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\"")
    print("     elif [ -d \"$HOME/.linuxbrew\" ]; then")
    print("       eval \"$(~/.linuxbrew/bin/brew shellenv)\"")
    print("     fi")
    print("     brew install pyenv")
    print("   fi")
    print("2) Si instalaste pyenv con script, agrega inicializacion al shell:")
    print("   echo 'export PYENV_ROOT=\"$HOME/.pyenv\"' >> ~/.bashrc")
    print("   echo 'export PATH=\"$PYENV_ROOT/bin:$PATH\"' >> ~/.bashrc")
    print("   echo 'eval \"$(pyenv init -)\"' >> ~/.bashrc")
    print("   exec \"$SHELL\"")
    print("3) Instalar Python 3.13.9 y crear entorno virtual:")
    print("   pyenv install 3.13.9")
    print("   pyenv local 3.13.9")
    print("   python -m venv hokkaido")
    print("   source hokkaido/bin/activate")
    print("4) Verificar y ejecutar:")
    print("   python --version")
    print("   python onedrive_space_optimizer.py --menu")


def print_complete_setup_guide(target: PlatformName) -> None:
    print("\nGuia completa de instalacion (desde cero):")
    print("- Esta guia evita salir del producto para instalar dependencias base.")
    print("- Incluye gestor de paquetes cuando falta y setup de Python 3.13.9.")
    print("- Usa el bloque de tu plataforma actual o cambia plataforma en opcion 4.")

    if target == "macos":
        print_macos_setup_guide()
        return

    if target == "windows":
        print_windows_setup_guide()
        return

    if target == "linux":
        print_linux_setup_guide()
        return

    print("[INFO] Plataforma no soportada para guia automatica.")


def install_package_manager_macos(runner: Runner) -> None:
    section("macOS: instalar/validar Homebrew")
    if shutil.which("brew"):
        print("[INFO] Homebrew ya esta instalado.")
        runner.run(["brew", "--version"], optional=True)
        return

    runner.run(
        '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"',
        shell=True,
        optional=False,
    )
    runner.run(["brew", "--version"], optional=True)


def install_package_manager_windows(runner: Runner) -> None:
    section("Windows: instalar/validar Chocolatey")
    if shutil.which("choco"):
        print("[INFO] Chocolatey ya esta instalado.")
        runner.run(["choco", "-v"], optional=True)
        return

    script = (
        "Set-ExecutionPolicy Bypass -Scope Process -Force; "
        "[System.Net.ServicePointManager]::SecurityProtocol = "
        "[System.Net.ServicePointManager]::SecurityProtocol -bor 3072; "
        "iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
    )
    runner.run(
        ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script],
        optional=False,
    )
    runner.run(["choco", "-v"], optional=True)


def linux_native_manager() -> str | None:
    for manager in ("apt", "dnf", "pacman", "zypper"):
        if shutil.which(manager):
            return manager
    return None


def install_package_manager_linux(runner: Runner) -> None:
    section("Linux: instalar/validar gestor de paquetes")
    native = linux_native_manager()
    if native:
        print(f"[INFO] Gestor nativo detectado ({native}). No se requiere instalacion adicional.")
        return

    if shutil.which("brew"):
        print("[INFO] Linuxbrew ya esta instalado.")
        runner.run(["brew", "--version"], optional=True)
        return

    print("[INFO] No hay gestor nativo detectado. Se instalara Linuxbrew.")
    runner.run(
        '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"',
        shell=True,
        optional=False,
    )
    runner.run(
        'if [ -d /home/linuxbrew/.linuxbrew ]; then '
        'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"; '
        'elif [ -d "$HOME/.linuxbrew" ]; then '
        'eval "$(~/.linuxbrew/bin/brew shellenv)"; '
        "fi; brew --version",
        shell=True,
        optional=True,
    )


def execute_package_manager_installation(target: PlatformName, apply_changes: bool, verbose: bool) -> int:
    print("\nInstalacion automatica del gestor de paquetes")
    print(f"- Plataforma objetivo: {target}")
    print(f"- Modo: {'APPLY (real)' if apply_changes else 'DRY-RUN (simulacion)'}")
    print("- Alcance: solo instala/valida gestor de paquetes, no ejecuta limpieza de OneDrive.")

    try:
        host_target = detect_platform("auto")
    except RuntimeError:
        host_target = "unknown"

    if apply_changes and host_target != "unknown" and target != host_target:
        print("[ERROR] APPLY bloqueado: no puedes instalar gestor de otra plataforma desde este sistema.")
        print(f"[INFO] Plataforma detectada localmente: {host_target}.")
        return 2

    if apply_changes:
        confirmation = input('Confirmar instalacion en APPLY. Escribe "SI" para continuar: ').strip()
        if confirmation != "SI":
            print("Instalacion cancelada por el usuario.")
            return 0

    runner = Runner(apply_changes=apply_changes, verbose=verbose)

    if target == "macos":
        install_package_manager_macos(runner)
    elif target == "windows":
        install_package_manager_windows(runner)
    elif target == "linux":
        install_package_manager_linux(runner)
    else:
        print(f"[ERROR] Plataforma no soportada: {target}")
        return 2

    return runner.summary()


def run_setup_submenu(target: PlatformName, apply_changes: bool, verbose: bool) -> None:
    while True:
        print("\nSubmenu de instalacion:")
        print("1. Ver guia completa de instalacion")
        print("2. Instalar gestor de paquetes automaticamente")
        print("0. Volver al menu principal")
        choice = input("Selecciona una opcion: ").strip()

        if choice == "1":
            print_complete_setup_guide(target=target)
            continue

        if choice == "2":
            exit_code = execute_package_manager_installation(
                target=target,
                apply_changes=apply_changes,
                verbose=verbose,
            )
            print(f"[INFO] Resultado instalacion de gestor: exit code {exit_code}")
            continue

        if choice == "0":
            return

        print("Opcion invalida. Intenta de nuevo.")


def print_service_catalog() -> None:
    print("\nServicios disponibles:")
    for index, key in enumerate(SERVICE_ORDER, start=1):
        title, desc = SERVICE_INFO[key]
        print(f"{index}. {title}: {desc}")


def prompt_platform(current: PlatformName) -> PlatformName:
    options = {
        "1": "macos",
        "2": "windows",
        "3": "linux",
    }
    print(f"\nPlataforma actual: {current}")
    print("1. macOS")
    print("2. Windows")
    print("3. Linux")
    print("0. Mantener actual")
    while True:
        choice = input("Selecciona plataforma: ").strip()
        if choice == "0" or choice == "":
            return current
        if choice in options:
            return options[choice]
        print("Entrada invalida. Usa 0, 1, 2 o 3.")


def prompt_onedrive_path(current: str | None) -> str | None:
    print(f"\nRuta actual OneDrive: {current or 'auto-detectada'}")
    print("Escribe una ruta nueva o deja vacio para mantener la actual.")
    path = input("Nueva ruta: ").strip()
    return path if path else current


def prompt_service_selection() -> list[ServiceKey] | None:
    print_service_catalog()
    print("Seleccion multiple: escribe numeros separados por coma (ejemplo: 1,3,5).")
    print("6. Todos los servicios")
    print("0. Cancelar")
    while True:
        raw = input("Seleccion: ").strip()
        if raw == "0":
            return None
        if not raw:
            print("Entrada vacia. Intenta de nuevo.")
            continue

        tokens = [token.strip() for token in raw.split(",") if token.strip()]
        numbers: list[int] = []
        valid = True
        for token in tokens:
            if not token.isdigit():
                valid = False
                break
            numbers.append(int(token))
        if not valid:
            print("Formato invalido. Usa solo numeros y comas.")
            continue

        if any(number < 0 or number > 6 for number in numbers):
            print("Seleccion fuera de rango. Usa valores entre 0 y 6.")
            continue

        if 6 in numbers:
            return list(SERVICE_ORDER)

        selected: list[ServiceKey] = []
        for idx, service in enumerate(SERVICE_ORDER, start=1):
            if idx in numbers and service not in selected:
                selected.append(service)

        if not selected:
            print("No seleccionaste servicios. Intenta de nuevo.")
            continue
        return selected


def describe_selected_services(selected: Sequence[ServiceKey]) -> None:
    print("\nPlan de ejecucion:")
    for service in SERVICE_ORDER:
        if service in selected:
            title, desc = SERVICE_INFO[service]
            print(f"- {title}: {desc}")


def print_execution_method(target: PlatformName, selected_services: Sequence[ServiceKey], apply_changes: bool) -> None:
    mode = "APPLY (real)" if apply_changes else "DRY-RUN (simulacion)"
    print("\nComo lo hara el programa en esta sesion:")
    print(f"1) Validara plataforma objetivo: {target}.")
    print(f"2) Recorrera {len(selected_services)} servicio(s) en orden controlado.")
    print(f"3) Mostrara cada comando en pantalla con etiqueta de modo actual ({mode}).")
    if apply_changes:
        print("4) Ejecutara comandos reales y reportara errores obligatorios/opcionales.")
    else:
        print("4) No ejecutara cambios reales; solo simulacion de comandos.")
    print("5) Mostrara resumen final con conteo de comandos y fallos.")


def execute_session(
    target: PlatformName,
    apply_changes: bool,
    verbose: bool,
    onedrive_path: str | None,
    selected_services: Sequence[ServiceKey],
) -> int:
    describe_selected_services(selected_services)
    print_execution_method(
        target=target,
        selected_services=selected_services,
        apply_changes=apply_changes,
    )
    mode = "APPLY (real)" if apply_changes else "DRY-RUN (simulacion)"
    print(f"- Modo: {mode}")
    print(f"- Plataforma: {target}")
    print("Requiere permisos sudo/admin para algunas acciones.")

    if apply_changes:
        confirmation = input('Confirmar APPLY. Escribe "SI" para continuar: ').strip()
        if confirmation != "SI":
            print("Ejecucion cancelada por el usuario.")
            return 0

    runner = Runner(apply_changes=apply_changes, verbose=verbose)
    execute_selected_services(
        target=target,
        runner=runner,
        onedrive_path=onedrive_path,
        selected_services=selected_services,
    )
    return runner.summary()


def run_interactive_menu(args: argparse.Namespace) -> int:
    try:
        target = detect_platform(args.platform)
    except RuntimeError as exc:
        print(f"Error: {exc}")
        return 2

    apply_changes = args.apply
    onedrive_path = args.onedrive_path

    while True:
        print_menu_header(target=target, apply_changes=apply_changes, onedrive_path=onedrive_path)
        print("1. Ejecutar TODOS los servicios en una misma sesion")
        print("2. Elegir servicios de forma independiente")
        print("3. Cambiar modo DRY-RUN/APPLY")
        print("4. Cambiar plataforma")
        print("5. Cambiar ruta OneDrive")
        print("6. Ver informacion de servicios")
        print("7. Explicacion detallada del modo actual")
        print("8. Guia e instalacion de gestor (por plataforma)")
        print("0. Salir")

        choice = input("Selecciona una opcion: ").strip()

        if choice == "1":
            return execute_session(
                target=target,
                apply_changes=apply_changes,
                verbose=args.verbose,
                onedrive_path=onedrive_path,
                selected_services=list(SERVICE_ORDER),
            )

        if choice == "2":
            selected = prompt_service_selection()
            if selected is None:
                continue
            return execute_session(
                target=target,
                apply_changes=apply_changes,
                verbose=args.verbose,
                onedrive_path=onedrive_path,
                selected_services=selected,
            )

        if choice == "3":
            apply_changes = not apply_changes
            mode = "APPLY (real)" if apply_changes else "DRY-RUN (simulacion)"
            print(f"Modo cambiado a: {mode}")
            continue

        if choice == "4":
            target = prompt_platform(current=target)
            continue

        if choice == "5":
            onedrive_path = prompt_onedrive_path(current=onedrive_path)
            continue

        if choice == "6":
            print_service_catalog()
            continue

        if choice == "7":
            print_mode_explanation_for_menu(apply_changes=apply_changes)
            continue

        if choice == "8":
            run_setup_submenu(
                target=target,
                apply_changes=apply_changes,
                verbose=args.verbose,
            )
            continue

        if choice == "0":
            print("Sin cambios. Saliendo.")
            return 0

        print("Opcion invalida. Intenta de nuevo.")


def should_open_menu(args: argparse.Namespace) -> bool:
    if args.no_menu:
        return False
    if args.menu:
        return True
    return len(sys.argv) == 1 and sys.stdin.isatty()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Cross-platform disk cleanup focused on OneDrive auto-updates, automatic downloads, "
            "indexing services, snapshots, and failed update caches."
        )
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Apply changes. Without this flag the script only prints what it would do.",
    )
    parser.add_argument(
        "--platform",
        choices=["auto", "macos", "windows", "linux"],
        default="auto",
        help="Target platform. Default: auto-detect current OS.",
    )
    parser.add_argument(
        "--onedrive-path",
        default=None,
        help="Override OneDrive folder path.",
    )
    menu_group = parser.add_mutually_exclusive_group()
    menu_group.add_argument("--menu", action="store_true", help="Open interactive menu.")
    menu_group.add_argument("--no-menu", action="store_true", help="Disable interactive menu.")
    parser.add_argument("--skip-onedrive", action="store_true", help="Skip OneDrive update actions.")
    parser.add_argument("--skip-downloads", action="store_true", help="Skip automatic download reduction actions.")
    parser.add_argument("--skip-indexing", action="store_true", help="Skip indexing service actions.")
    parser.add_argument("--skip-snapshots", action="store_true", help="Skip snapshot purge actions.")
    parser.add_argument("--skip-failed-updates", action="store_true", help="Skip failed update cache cleanup.")
    parser.add_argument("--verbose", action="store_true", help="Print stdout for executed commands.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if should_open_menu(args):
        return run_interactive_menu(args)

    try:
        target = detect_platform(args.platform)
    except RuntimeError as exc:
        print(f"Error: {exc}")
        return 2

    print(f"Target platform: {target}")
    if not args.apply:
        print("Running in dry-run mode. Add --apply to perform real changes.")
        print_dry_run_explanation()
    print("Some operations require sudo/admin privileges.")

    runner = Runner(apply_changes=args.apply, verbose=args.verbose)
    run_actions(target=target, runner=runner, args=args)
    return runner.summary()


if __name__ == "__main__":
    sys.exit(main())
