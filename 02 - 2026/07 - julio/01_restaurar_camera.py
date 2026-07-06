#!/usr/bin/env python3
"""
Cross-Platform Camera Reset / Kill Tool
======================================
Funciona en macOS, Windows y Linux.
Mejor soporte en macOS.

Uso:
    python camera_reset.py --list
    python camera_reset.py --kill
    python camera_reset.py --macos-full
    python camera_reset.py --kill --force
"""

import argparse
import platform
import psutil
import subprocess
import sys
import os


def get_platform():
    system = platform.system()
    if system == "Darwin":
        return "macos"
    elif system == "Windows":
        return "windows"
    elif system == "Linux":
        if os.path.exists("/data/data/com.termux"):
            return "android"
        return "linux"
    return "unknown"


def find_camera_processes():
    keywords = [
        "camera", "vdcassistant", "applecamera", "webcam",
        "video", "frameserver", "cameraserver", "mediaserver"
    ]
    found = []
    for proc in psutil.process_iter(['pid', 'name', 'cmdline', 'username']):
        try:
            name = (proc.info.get('name') or "").lower()
            cmdline = " ".join(proc.info.get('cmdline') or []).lower()
            if any(kw in name or kw in cmdline for kw in keywords):
                found.append({
                    'pid': proc.info['pid'],
                    'name': proc.info.get('name', 'unknown'),
                    'username': proc.info.get('username', 'unknown'),
                    'cmdline': (proc.info.get('cmdline') or [])[:3]
                })
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue
    return found


def kill_pid(pid, force=False):
    try:
        p = psutil.Process(pid)
        p.kill() if force else p.terminate()
        return True
    except (psutil.NoSuchProcess, psutil.AccessDenied):
        return False


def macos_reset_camera(full=False):
    print("🍎 macOS Camera Reset")
    print("=" * 45)
    
    daemons = ["VDCAssistant"]
    if full:
        daemons += ["AppleCameraAssistant", "appleh13camerad"]
    
    for daemon in daemons:
        print(f"\n→ Matando {daemon}...")
        try:
            result = subprocess.run(
                ["sudo", "killall", daemon],
                capture_output=True, text=True, timeout=10
            )
            if result.returncode == 0:
                print(f"   ✅ {daemon} terminado correctamente")
            else:
                if "No matching processes" in result.stderr:
                    print(f"   ℹ️  No había proceso {daemon}")
                else:
                    print(f"   ⚠️  {result.stderr.strip()}")
        except Exception as e:
            print(f"   ❌ Error: {e}")
    
    print("\n✅ Los daemons de cámara se reiniciarán automáticamente cuando se necesiten.")
    print("   Prueba con Photo Booth, FaceTime o Zoom.")


def windows_reset_camera():
    print("🪟 Windows Camera Reset")
    print("=" * 45)
    print("\n→ Reiniciando servicio 'Windows Camera Frame Server'...")
    try:
        subprocess.run(["net", "stop", "FrameServer", "/y"], timeout=15)
        subprocess.run(["net", "start", "FrameServer"], timeout=15)
        print("   ✅ Intento de reinicio del servicio (requiere Administrador)")
    except Exception as e:
        print(f"   ⚠️  {e}")
    
    print("\n→ Matando procesos de usuario relacionados con cámara...")
    procs = find_camera_processes()
    for p in procs:
        if kill_pid(p['pid']):
            print(f"   ✅ PID {p['pid']} ({p['name']}) terminado")


def linux_reset_camera(android=False):
    if android:
        print("📱 Android (Termux) - Cámara")
        print("=" * 45)
        print("\n⚠️  Sin root es muy limitado. Solo puedes liberar la cámara desde tu propia app.")
        print("\nCon root (recomendado):")
        print("   su -c 'killall -9 cameraserver'")
        print("   su -c 'killall -9 mediaserver'")
        print("   su -c 'stop camera; start camera'   # según la ROM")
        return
    
    print("🐧 Linux Camera Reset")
    print("=" * 45)
    procs = find_camera_processes()
    if not procs:
        print("No se encontraron procesos de cámara.")
        return
    
    for p in procs:
        print(f"   {p['pid']}: {p['name']}")
    
    if input("\n¿Matar estos procesos? (y/N): ").lower() != "y":
        return
    
    for p in procs:
        if kill_pid(p['pid']):
            print(f"   ✅ {p['pid']} terminado")


def main():
    parser = argparse.ArgumentParser(description="Herramienta multiplataforma para reiniciar/matar la cámara")
    parser.add_argument("--list", action="store_true", help="Listar procesos relacionados con cámara")
    parser.add_argument("--kill", action="store_true", help="Matar procesos de cámara")
    parser.add_argument("--macos-full", action="store_true", help="Reset completo en macOS (todos los daemons)")
    parser.add_argument("--force", action="store_true", help="Forzar terminación (SIGKILL)")
    args = parser.parse_args()

    os_name = get_platform()
    print(f"Plataforma detectada: {os_name.upper()}\n")

    if args.list:
        procs = find_camera_processes()
        if procs:
            for p in procs:
                print(f"PID {p['pid']:>6} | {p['name']:<25} | {p['username']}")
        else:
            print("No se encontraron procesos relacionados con cámara.")
        return

    if args.kill or args.macos_full:
        if os_name == "macos":
            macos_reset_camera(full=args.macos_full)
        elif os_name == "windows":
            windows_reset_camera()
        elif os_name == "android":
            linux_reset_camera(android=True)
        elif os_name == "linux":
            linux_reset_camera()
        return

    parser.print_help()


if __name__ == "__main__":
    main()
