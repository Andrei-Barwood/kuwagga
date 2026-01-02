#!/usr/bin/env python3
# Snocomm - 2025
# instalador y orquestador de dependencias + automatizaciones.

import subprocess
import shutil
import sys
import os
import platform
from pathlib import Path
import argparse
from datetime import datetime

def run(cmd, check=False, capture=False, shell=False):
    return subprocess.run(cmd, check=check, text=True, capture_output=capture, shell=shell)

def which(cmd):
    return shutil.which(cmd) is not None

def notify_linux(summary, body=""):
    if which("notify-send"):
        run(["notify-send", summary, body])

def notify_macos(summary, body=""):
    if which("osascript"):
        osa = f'display notification "{body}" with title "{summary}"'
        run(["osascript", "-e", osa])

def ensure_winget():
    return which("winget")

def ensure_brew():
    return which("brew")

def os_name():
    return platform.system()

def install_windows(packages):
    # Intenta instalar con WinGet de forma silenciosa
    if not ensure_winget():
        print("WinGet no disponible; instala Desktop App Installer desde Microsoft Store o habilita winget.", flush=True)
        return False
    ok = True
    for pkg in packages:
        print(f"Instalando con winget: {pkg}")
        r = run(["winget", "install", "--silent", "--accept-package-agreements", "--accept-source-agreements", pkg])
        ok = ok and (r.returncode == 0)
    return ok

def install_macos(packages):
    if not ensure_brew():
        print("Homebrew no encontrado; instala brew y reintenta.", flush=True)
        return False
    ok = True
    for pkg in packages:
        print(f"brew install {pkg}")
        r = run(["brew", "install", pkg])
        ok = ok and (r.returncode == 0)
    return ok

def install_linux_apt(packages):
    cmds = [["sudo", "apt", "update"], ["sudo", "apt", "install", "-y"] + packages]
    ok = True
    for c in cmds:
        print(" ".join(c))
        r = run(c)
        ok = ok and (r.returncode == 0)
    return ok

def install_linux_dnf(packages):
    cmds = [["sudo", "dnf", "install", "-y"] + packages]
    ok = True
    for c in cmds:
        print(" ".join(c))
        r = run(c)
        ok = ok and (r.returncode == 0)
    return ok

def install_linux_pacman(packages):
    cmds = [["sudo", "pacman", "-Syu", "--noconfirm"], ["sudo", "pacman", "-S", "--noconfirm"] + packages]
    ok = True
    for c in cmds:
        print(" ".join(c))
        r = run(c)
        ok = ok and (r.returncode == 0)
    return ok

def schedule_windows(task_name, time_hhmm, py_exe, backup_script, dest, modo="ambos", zip_pass=""):
    # Crea tarea diaria a la hora indicada
    tr = f'"{py_exe}" "{backup_script}" --modo {modo} --dest "{dest}"' + (f' --zip-pass "{zip_pass}"' if zip_pass else "")
    cmd = ["schtasks", "/Create", "/TN", task_name, "/SC", "DAILY", "/ST", time_hhmm, "/TR", tr, "/RL", "HIGHEST", "/F"]
    print(" ".join(cmd))
    return run(cmd).returncode == 0

def schedule_macos(label, time_hhmm, py_exe, backup_script, dest, modo="ambos", zip_pass=""):
    # Crea LaunchAgent en ~/Library/LaunchAgents
    hh, mm = time_hhmm.split(":")
    launch_agents = Path.home() / "Library" / "LaunchAgents"
    launch_agents.mkdir(parents=True, exist_ok=True)
    plist = launch_agents / f"{label}.plist"
    program_args = [
        py_exe, backup_script, "--modo", modo, "--dest", dest
    ] + (["--zip-pass", zip_pass] if zip_pass else [])
    pa_xml = "".join([f"<string>{arg}</string>" for arg in program_args])
    plist_content = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>{label}</string>
  <key>ProgramArguments</key>
  <array>{pa_xml}</array>
  <key>StartCalendarInterval</key>
  <dict><key>Hour</key><integer>{int(hh)}</integer><key>Minute</key><integer>{int(mm)}</integer></dict>
  <key>StandardOutPath</key><string>{str(Path.home() / f"{label}.log")}</string>
  <key>StandardErrorPath</key><string>{str(Path.home() / f"{label}.err")}</string>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><false/>
</dict>
</plist>
"""
    plist.write_text(plist_content, encoding="utf-8")
    run(["launchctl", "unload", str(plist)])
    r = run(["launchctl", "load", str(plist)])
    return r.returncode == 0

def schedule_linux_cron(time_hhmm, py_exe, backup_script, dest, modo="ambos", zip_pass=""):
    # Añade línea a crontab del usuario: mm hh * * *
    hh, mm = time_hhmm.split(":")
    entry = f"{int(mm)} {int(hh)} * * * {py_exe} {backup_script} --modo {modo} --dest \"{dest}\""
    if zip_pass:
        entry += f' --zip-pass "{zip_pass}"'
    # instalar o actualizar crontab
    current = run(["crontab", "-l"], capture=True)
    text = current.stdout if current.returncode == 0 else ""
    if entry not in text:
        text = (text + "\n" + entry + "\n").strip() + "\n"
        p = run(["crontab", "-"], capture=True, shell=False)
        # El método anterior no pasa stdin, hacemos:
        proc = subprocess.Popen(["crontab", "-"], stdin=subprocess.PIPE, text=True)
        proc.communicate(text)
        return proc.returncode == 0
    return True

def main():
    ap = argparse.ArgumentParser(description="Instalador y automatizador para backups móviles (ADB/libimobiledevice/7-Zip).")
    ap.add_argument("--instalar", action="store_true", help="Instalar dependencias según el sistema.")
    ap.add_argument("--programar", action="store_true", help="Crear tarea/cron/launchd para ejecutar el backup diariamente.")
    ap.add_argument("--hora", default="20:00", help="Hora HH:MM local para la automatización diaria.")
    ap.add_argument("--python", default=sys.executable, help="Ruta a python.exe/python3 a usar en el programado.")
    ap.add_argument("--script-backup", required=True, help="Ruta a operacion_jp_respaldo.py.")
    ap.add_argument("--dest", required=True, help="Destino de backups.")
    ap.add_argument("--modo", choices=["android", "ios", "ambos"], default="ambos", help="Modo por defecto del backup programado.")
    ap.add_argument("--zip-pass", default="", help="Contraseña para cifrado 7z en el backup programado (opcional).")
    args = ap.parse_args()

    system = os_name()
    print(f"Sistema detectado: {system}")

    installed = True
    if args.instalar:
        if system == "Windows":
            # Paquetes Winget: 7zip y Platform-Tools (si están en catálogo local)
            pkgs = ["7zip.7zip", "Google.AndroidSDK.PlatformTools"]
            installed = install_windows(pkgs)
        elif system == "Darwin":
            # macOS: brew install android-platform-tools libimobiledevice p7zip
            pkgs = ["android-platform-tools", "libimobiledevice", "p7zip"]
            installed = install_macos(pkgs)
        elif system == "Linux":
            # Intento heurístico según gestor disponible
            if which("apt"):
                pkgs = ["android-tools-adb", "libimobiledevice-utils", "p7zip-full", "libnotify-bin"]
                installed = install_linux_apt(pkgs)
            elif which("dnf"):
                pkgs = ["android-tools", "libimobiledevice", "p7zip", "libnotify"]
                installed = install_linux_dnf(pkgs)
            elif which("pacman"):
                pkgs = ["android-tools", "libimobiledevice", "p7zip", "libnotify"]
                installed = install_linux_pacman(pkgs)
            else:
                print("No se detectó apt/dnf/pacman; instala manualmente ADB, libimobiledevice y p7zip.")
                installed = False

        # Notificación básica
        if system == "Linux":
            notify_linux("Instalación completada", "Dependencias instaladas o verificadas.")
        elif system == "Darwin":
            notify_macos("Instalación completada", "Dependencias instaladas o verificadas.")

    scheduled = True
    if args.programar:
        if system == "Windows":
            scheduled = schedule_windows("JdP_Backup_Movil", args.hora, args.python, args.script-backup, args.dest, args.modo, args.zip_pass)
        elif system == "Darwin":
            scheduled = schedule_macos("cl.jdp.backup.movil", args.hora, args.python, args.script-backup, args.dest, args.modo, args.zip_pass)
        elif system == "Linux":
            scheduled = schedule_linux_cron(args.hora, args.python, args.script-backup, args.dest, args.modo, args.zip_pass)

        if system == "Linux":
            notify_linux("Programación creada", f"Ejecución diaria a las {args.hora}.")
        elif system == "Darwin":
            notify_macos("Programación creada", f"Ejecución diaria a las {args.hora}.")

    # Comprobaciones informativas
    print("\nVerificación de binarios clave:")
    for b in ["adb", "idevicebackup2", "7z"]:
        print(f" - {b}: {'OK' if which(b) else 'NO'}")

    # Recordatorio para iOS en Windows si falta idevicebackup2
    if system == "Windows" and not which("idevicebackup2"):
        print("Aviso: idevicebackup2 no está disponible en PATH; iOS backup se omitirá en Windows hasta instalar libimobiledevice.")
        if system == "Windows":
            pass

    ok = (not args.instalar or installed) and (not args.programar or scheduled)
    sys.exit(0 if ok else 1)

if __name__ == "__main__":
    main()
