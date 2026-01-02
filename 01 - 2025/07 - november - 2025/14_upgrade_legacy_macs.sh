#!/bin/zsh

set -euo pipefail

echo "🥾 SCRIPT BOOTABLE LEGACY: Lion 10.7 → High Sierra 10.13"
echo "=================================================="
echo "⚠️  REQUIERE: 2 USB 16GB+, Internet, Backup del Mac objetivo."
echo ""

# 1. Detectar USBs (elige el mayor libre)
disks=$(diskutil list external physical | grep -E '/dev/disk[0-9]+' | awk '{print $6}')
echo "💾 USBs detectados:"
diskutil list | grep -E 'external|disk[0-9]' | head -10
echo ""
read "usb_vol?Ingresa volumen USB (ej: /Volumes/MyUSB1) [ENTER para listar]: "
if [[ -z "$usb_vol" ]]; then
  echo "Listando volúmenes montados..."
  diskutil list | grep -E 'Apple|USB'
  read "usb_vol?Volumen USB1 para El Capitan (ej: /Volumes/USB1): "
fi

# Desmontar si necesario
diskutil unmountDisk "${usb_vol%/}"

echo ""
echo "📥 1. Descargando instaladores (si no existen)..."

# High Sierra (10.13) - App Store o MrMac
if [[ ! -d "/Applications/Install macOS High Sierra.app" ]]; then
  echo "🟡 Abre App Store para High Sierra..."
  open "macappstore://itunes.apple.com/app/macos-high-sierra/id1246284741"
  read "?Pulsa ENTER cuando esté en /Applications/: "
fi

# El Capitan (10.11) - Directo Apple (fallback MrMac)
if [[ ! -d "/Applications/Install OS X El Capitan.app" ]]; then
  echo "🟡 Descargando El Capitan (directo Apple)..."
  open "https://support.apple.com/downloads/elcapitan"
  read "?Pulsa ENTER cuando esté listo: "
fi

echo ""
echo "🔨 2. Creando USB1: El Capitan (para Lion)..."

sudo /Applications/"Install OS X El Capitan.app"/Contents/Resources/createinstallmedia \
  --volume "$usb_vol" --nointeraction --applicationpath /Applications/"Install OS X El Capitan.app"

echo "✅ USB1 listo: $usb_vol (El Capitan)"

read "ready2?Expulsa USB1, inserta USB2 y presiona ENTER: "
read "usb_vol2?Volumen USB2 para High Sierra: "

diskutil unmountDisk "${usb_vol2%/}"

echo ""
echo "🔨 3. Creando USB2: High Sierra (para El Capitan+)..."

sudo /Applications/"Install macOS High Sierra.app"/Contents/Resources/createinstallmedia \
  --volume "$usb_vol2" --nointeraction

echo "✅ USB2 listo: $usb_vol2 (High Sierra)"

echo ""
echo "🎉 ¡BOOTABLES CREADOS!"
echo "📋 USO en Mac Lion:"
echo "1. Inserta USB1 (El Capitan) → Reinicia Cmd+R o Alt → Elige USB."
echo "2. Instala El Capitan (borra disco si quieres limpio)."
echo "3. Reinicia en El Capitan → Inserta USB2 (High Sierra) → Repite."
echo ""
echo "🔗 Fuentes: Apple | MrMac"

