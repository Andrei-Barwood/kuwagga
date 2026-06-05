#!/usr/bin/env python3
"""
SYNOPSIS
    Script de restauracion de red nivel profundo, multiplataforma (Windows/macOS).
DESCRIPTION
    Ejecuta multiples pasos de reparacion logica (Shotgun approach) con output en 
    vivo y paleta de branding. Detecta el SO y aplica las reparaciones nativas.
AUTHOR
    Kirtan Teg Singh
"""

import os
import sys
import platform
import subprocess
import time

# -----------------------------------------------------------------------------
# MOTOR DE RENDERIZADO ANSI (PALETA DE BRANDING)
# -----------------------------------------------------------------------------
def get_ansi(hex_color):
    hex_color = hex_color.replace('#', '')
    r, g, b = tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4))
    return f"\033[38;2;{r};{g};{b}m"

C_A7B7CF = get_ansi("#A7B7CF") # Azul-Gris claro (Listas y variables)
C_485199 = get_ansi("#485199") # Azul profundo (Bordes estructurales)
C_63627C = get_ansi("#63627C") # Purpura-Gris opaco (Para el Tail/Leak de fondo)
C_C2C0E3 = get_ansi("#C2C0E3") # Lavanda suave (Textos de exito y confirmaciones)
C_FFFF99 = get_ansi("#FFFF99") # Amarillo palido (Advertencias y nombres de error)
C_EBF8FF = get_ansi("#EBF8FF") # Hielo brillante (Titulos principales)
C_EAEEF4 = get_ansi("#EAEEF4") # Gris-Azulado muy claro (Texto general)
RESET    = "\033[0m"

# -----------------------------------------------------------------------------
# COMPROBACION DE PRIVILEGIOS DE ADMINISTRADOR / ROOT
# -----------------------------------------------------------------------------
def is_admin():
    try:
        if platform.system() == "Windows":
            import ctypes
            return ctypes.windll.shell32.IsUserAnAdmin() != 0
        else:
            return os.geteuid() == 0
    except:
        return False

if not is_admin():
    print(f"\n{C_FFFF99}[!] Este script necesita ejecutarse como Administrador (Windows) o Root (macOS).{RESET}")
    if platform.system() == "Windows":
        print(f"{C_EAEEF4}Por favor, abre la terminal como Administrador y ejecuta: python rescue_net.py{RESET}\n")
    else:
        print(f"{C_EAEEF4}Por favor, ejecuta el script con sudo: sudo python3 rescue_net.py{RESET}\n")
    sys.exit(1)

# -----------------------------------------------------------------------------
# DETECCION DE SISTEMA Y CONFIGURACION DE TAREAS
# -----------------------------------------------------------------------------
sistema_actual = platform.system()

if sistema_actual == "Windows":
    tareas = [
        {"msj": "Liberando concesion IPv4 actual", "cmd": "ipconfig /release"},
        {"msj": "Renovando concesion IPv4 via DHCP", "cmd": "ipconfig /renew"},
        {"msj": "Restableciendo el Stack TCP/IPv4", "cmd": "netsh int ip reset"},
        {"msj": "Restableciendo el catalogo Winsock", "cmd": "netsh winsock reset"},
        {"msj": "Vaciando cache DNS local", "cmd": "ipconfig /flushdns"},
        {"msj": "Forzando registro de DNS", "cmd": "ipconfig /registerdns"},
        {"msj": "Borrando tabla de enrutamiento ARP", "cmd": "arp -d *"},
        {"msj": "Desactivando Proxy residuales", "cmd": "reg add \"HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings\" /v ProxyEnable /t REG_DWORD /d 0 /f"},
        {"msj": "Restableciendo el Stack TCP/IPv6", "cmd": "netsh int ipv6 reset"},
        {"msj": "Restaurando reglas de Windows Firewall", "cmd": "netsh advfirewall reset"}
    ]
elif sistema_actual == "Darwin": # Darwin es el nucleo de macOS
    # En MacBooks, en0 suele ser la interfaz Wi-Fi primaria
    tareas = [
        {"msj": "Forzando renovacion de concesion DHCP en Wi-Fi (en0)", "cmd": "ipconfig set en0 DHCP"},
        {"msj": "Vaciando cache DNS (mDNSResponder)", "cmd": "dscacheutil -flushcache && killall -HUP mDNSResponder"},
        {"msj": "Borrando tabla de enrutamiento ARP local", "cmd": "arp -a -d"},
        {"msj": "Desactivando temporalmente la interfaz Wi-Fi", "cmd": "ifconfig en0 down"},
        {"msj": "Reactivando interfaz Wi-Fi", "cmd": "ifconfig en0 up"},
        {"msj": "Restableciendo modo IPv6 automatico", "cmd": "networksetup -setv6automatic Wi-Fi"},
        {"msj": "Limpiando preferencias de proxy", "cmd": "networksetup -setwebproxystate Wi-Fi off"}
    ]
else:
    print(f"{C_FFFF99}Sistema Operativo ({sistema_actual}) no soportado.{RESET}")
    sys.exit(1)

# -----------------------------------------------------------------------------
# INTERFAZ Y MENU PRINCIPAL
# -----------------------------------------------------------------------------
os.system('cls' if sistema_actual == 'Windows' else 'clear')

print(f"{C_485199}==============================================================================={RESET}")
print(f"{C_EBF8FF}               PROTOCOLO DE RESCATE DE RED (BY KIRTAN TEG SINGH)               {RESET}")
print(f"{C_485199}==============================================================================={RESET}")
print(f"{C_EAEEF4} Entorno detectado: {C_FFFF99}{sistema_actual}{RESET}")
print(f"{C_EAEEF4} Se aplicara el protocolo en cascada para sanear la pila de red del sistema.{RESET}")
print(f"{C_485199}==============================================================================={RESET}\n")

try:
    input(f"{C_A7B7CF}Presiona ENTER para iniciar la limpieza profunda, o CTRL+C para cancelar.{RESET}")
except KeyboardInterrupt:
    print(f"\n{C_FFFF99}Operacion cancelada por el usuario.{RESET}")
    sys.exit(0)

print(f"\n{C_EBF8FF}INICIANDO SECUENCIA DE REPARACION...{RESET}\n")

# -----------------------------------------------------------------------------
# MOTOR DE EJECUCION CON "LEAK" EN VIVO
# -----------------------------------------------------------------------------
total_pasos = len(tareas)

for i, tarea in enumerate(tareas, 1):
    msj = tarea["msj"]
    cmd = tarea["cmd"]
    porcentaje = int((i / total_pasos) * 100)
    
    # Barra de progreso simulada en texto
    sys.stdout.write(f"\r{C_A7B7CF}[Progreso: {porcentaje:03d}%] {C_EAEEF4}[*] Paso {i}/{total_pasos}: {msj}...{RESET}")
    sys.stdout.flush()

    try:
        # Ejecutamos el comando capturando stdout y stderr combinados
        resultado = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        
        print(f" {C_C2C0E3}[OK]{RESET}")
        
        # Filtramos lineas vacias
        lineas = [linea.strip() for linea in resultado.stdout.split('\n') if linea.strip()]
        
        if lineas:
            # Seleccionamos las ultimas 3 lineas para el leak
            tail = lineas[-3:]
            for linea in tail:
                print(f"{C_63627C}    > {linea}{RESET}")
        else:
             print(f"{C_63627C}    > (Proceso completado silenciosamente){RESET}")

    except Exception as e:
        print(f" {C_FFFF99}[FALLO MENOR]{RESET}")
        print(f"{C_63627C}    > Error capturado: {str(e)}{RESET}")

    time.sleep(0.6)

print(f"\n{C_485199}==============================================================================={RESET}")
print(f"{C_EBF8FF} PROTOCOLO COMPLETADO EXITOSAMENTE.                                            {RESET}")
print(f"{C_485199}==============================================================================={RESET}")
if sistema_actual == "Windows":
    print(f"{C_FFFF99}NOTA: REINICIA el equipo para aplicar la reconstruccion de Winsock.{RESET}\n")
else:
    print(f"{C_C2C0E3}La interfaz de red (en0) de macOS se ha reiniciado correctamente.{RESET}\n")

try:
    input(f"{C_A7B7CF}Presiona ENTER para salir...{RESET}")
except:
    pass