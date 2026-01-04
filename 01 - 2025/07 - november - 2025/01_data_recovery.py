#!/usr/bin/env python3
"""
Script de backup y recuperación para Android (ADB) e iPhone (idevicebackup2)
Requiere: adb (Android), idevicebackup2/idevice_id (iOS), 7z (opcional)
Autor: Snocomm - 2025
"""

import sys

# Verificar versión de Python
if sys.version_info < (3, 6):
    print("Error: Se requiere Python 3.6 o superior.", file=sys.stderr)
    sys.exit(1)

import argparse
import os
import shutil
import subprocess
import sys
import datetime
from pathlib import Path

def check_cmd(name):
    return shutil.which(name) is not None

def run(cmd, cwd=None, capture=False):
    """Ejecuta un comando y retorna el resultado."""
    try:
        return subprocess.run(cmd, cwd=cwd, check=False, text=True,
                              stdout=(subprocess.PIPE if capture else None),
                              stderr=(subprocess.PIPE if capture else None))
    except (OSError, ValueError) as e:
        print(f"Error ejecutando comando: {e}", file=sys.stderr)
        return subprocess.CompletedProcess(cmd, 1, stdout="", stderr=str(e))

def ensure_dir(p: Path):
    p.mkdir(parents=True, exist_ok=True)

def backup_android(dest: Path):
    if not check_cmd("adb"):
        print("ERROR: adb no encontrado en PATH.")
        return False
    # Detectar dispositivos
    res = run(["adb", "devices"], capture=True)
    lines = (res.stdout or "").strip().splitlines()
    devices = [l.split()[0] for l in lines[1:] if l.strip() and "device" in l and not "offline" in l]
    if not devices:
        print("No hay dispositivos Android en estado 'device'.")
        return False
    ok_any = False
    for d in devices:
        print(f"Android detectado: {d}")
        stamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        outdir = dest / f"android_{d}_{stamp}"
        ensure_dir(outdir)
        # Carpetas comunes de medios y descargas
        src_dirs = ["/sdcard/DCIM", "/sdcard/Pictures", "/sdcard/Movies",
                    "/sdcard/Music", "/sdcard/Download", "/sdcard/Documents"]
        for sd in src_dirs:
            # Verificar existencia
            chk = run(["adb", "-s", d, "shell", "ls", "-d", sd], capture=True)
            if chk.returncode == 0:
                print(f"Copiando {sd} ...")
                run(["adb", "-s", d, "pull", sd, str(outdir)])
            else:
                print(f"Omitido (no existe): {sd}")
        ok_any = True
        print(f"Backup Android listo en: {outdir}")
    return ok_any

def backup_ios(dest: Path, udid=None):
    if not check_cmd("idevicebackup2") or not check_cmd("idevice_id"):
        print("ADVERTENCIA: idevicebackup2/idevice_id no disponibles en PATH.")
        return False
    # Listar dispositivos iOS
    ids = run(["idevice_id", "-l"], capture=True)
    udids = (ids.stdout or "").strip().splitlines()
    if not udids:
        print("No hay iPhone conectado/trust.")
        return False
    targets = [udid] if udid and udid in udids else udids
    ok_any = False
    for u in targets:
        print(f"iPhone detectado: {u}")
        stamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        outdir = dest / f"ios_{u}_{stamp}"
        ensure_dir(outdir)
        # Respaldo completo
        cmd = ["idevicebackup2", "backup", "--full", str(outdir)]
        print("Ejecutando:", " ".join(cmd))
        r = run(cmd)
        if r.returncode == 0:
            ok_any = True
            print(f"Backup iOS listo en: {outdir}")
        else:
            print("Fallo de idevicebackup2 (revisa trust/cable/bloqueo).")
    return ok_any

def sevenzip_encrypt(source_dir: Path, password: str, out_path: Path = None):
    if not check_cmd("7z"):
        print("ADVERTENCIA: 7z no disponible; saltando compresión.")
        return None
    if out_path is None:
        out_path = source_dir.with_suffix(".7z")
    cmd = ["7z", "a", "-t7z", str(out_path), str(source_dir)]
    if password:
        cmd += [f"-p{password}", "-mhe=on"]
    print("Comprimiendo:", " ".join(cmd))
    r = run(cmd)
    if r.returncode == 0:
        print(f"Archivo 7z creado: {out_path}")
        return out_path
    else:
        print("Error al comprimir con 7z.")
        return None

def main():
    parser = argparse.ArgumentParser(description="Respaldo Android/iPhone con cifrado opcional (7-Zip).")
    parser.add_argument("--modo", choices=["android", "ios", "ambos"], default="ambos", help="Qué respaldar.")
    parser.add_argument("--dest", required=True, help="Carpeta destino de respaldos.")
    parser.add_argument("--zip-pass", default="", help="Contraseña para .7z (opcional).")
    parser.add_argument("--ios-udid", default=None, help="UDID específico del iPhone (opcional).")
    args = parser.parse_args()

    dest = Path(args.dest).expanduser().resolve()
    ensure_dir(dest)

    ok = False
    if args.modo in ("android", "ambos"):
        ok |= backup_android(dest)
    if args.modo in ("ios", "ambos"):
        ok |= backup_ios(dest, args.ios_udid)

    # Comprimir y cifrar la carpeta raíz de la sesión
    if ok:
        session_marker = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        session_dir = dest / f"session_{session_marker}"
        # Reunir respaldos creados en esta ejecución
        created = [p for p in dest.iterdir() if p.is_dir() and any(tag in p.name for tag in ["android_", "ios_"])]
        if created:
            session_dir.mkdir(exist_ok=True)
            for p in created:
                # mover dentro de la sesión
                try:
                    p.rename(session_dir / p.name)
                except Exception:
                    # fallback: copiar por sistema (simple)
                    run(["cmd", "/c", "robocopy", str(p), str(session_dir / p.name), "/E"])
                    shutil.rmtree(p, ignore_errors=True)
            sevenzip_encrypt(session_dir, args.zip_pass)
    else:
        print("No se generó ningún backup (verifica conexión, drivers y permisos).")
        return 1
    return 0

if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\nOperación cancelada por el usuario.", file=sys.stderr)
        sys.exit(130)
    except Exception as e:
        print(f"Error inesperado: {e}", file=sys.stderr)
        sys.exit(1)
