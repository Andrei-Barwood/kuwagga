#!/bin/zsh

echo "🧼 Desinstalando CleanMyMac (cualquier versión)..."
echo "==========================================="

# Buscar cualquier versión de la app
echo "🔍 Buscando CleanMyMac en /Applications..."
FOUND_APP=$(find /Applications -maxdepth 1 -iname "CleanMyMac*.app" | head -n 1)

if [[ -n "$FOUND_APP" ]]; then
    echo "📦 Eliminando aplicación: $FOUND_APP"
    sudo rm -rf "$FOUND_APP"
else
    echo "❌ No se encontró ninguna aplicación CleanMyMac*.app"
fi

# LaunchAgents y Daemons
echo "🧩 Eliminando LaunchAgents y Daemons..."
sudo rm -f /Library/LaunchAgents/com.macpaw.CleanMyMac4.Agent.plist
sudo rm -f /Library/LaunchDaemons/com.macpaw.CleanMyMac4.Scheduler.plist
rm -f ~/Library/LaunchAgents/com.macpaw.CleanMyMac4.Updater.plist

# Preferencias
echo "🗃️ Eliminando archivos de preferencias..."
rm -f ~/Library/Preferences/com.macpaw.CleanMyMac4*.plist
rm -f ~/Library/Preferences/com.macpaw.CleanMyMac*.plist

# Caches
echo "🧹 Eliminando cachés..."
rm -rf ~/Library/Caches/com.macpaw.CleanMyMac4
rm -rf ~/Library/Caches/com.macpaw.CleanMyMac*
sudo rm -rf /Library/Caches/com.macpaw.CleanMyMac*

# Application Support
echo "📂 Eliminando archivos de soporte..."
rm -rf ~/Library/Application\ Support/CleanMyMac*
sudo rm -rf /Library/Application\ Support/MacPaw/CleanMyMac*

# Logs
echo "🧾 Eliminando logs..."
rm -rf ~/Library/Logs/CleanMyMac*

# Login items (arranque)
echo "🚪 Eliminando login items..."
osascript -e 'tell application "System Events" to delete login item "CleanMyMac X"' 2>/dev/null

# Application Scripts (versiones App Store)
echo "🧨 Eliminando Application Scripts..."
rm -rf ~/Library/Application\ Scripts/S8EX82NJP6.com.macpaw.CleanMyMac-mas
rm -rf ~/Library/Application\ Scripts/com.macpaw.CleanMyMac-mas.*
rm -rf ~/Library/Application\ Scripts/com.macpaw.CleanMyMac*

# Group Containers
echo "🗑️ Eliminando Group Containers..."
rm -rf ~/Library/Group\ Containers/*.com.macpaw.CleanMyMac*

# App Containers
echo "📦 Eliminando Containers..."
rm -rf ~/Library/Containers/com.macpaw.CleanMyMac*
rm -rf ~/Library/Containers/S8EX82NJP6.com.macpaw.CleanMyMac-mas.*

# Saved Application State
echo "💾 Eliminando estado guardado de la aplicación..."
rm -rf ~/Library/Saved\ Application\ State/com.macpaw.CleanMyMac*.savedState

# Kernel extensions
echo "🧠 Verificando extensiones del kernel..."
kextstat | grep -i macpaw
if [[ $? -eq 0 ]]; then
    echo "⚠️ Se encontraron extensiones kext de MacPaw. Intentando eliminar..."
    sudo kextunload -b com.macpaw.CleanMyMac 2>/dev/null
    sudo rm -rf /Library/Extensions/CleanMyMac.kext
    sudo rm -rf /System/Library/Extensions/CleanMyMac.kext
else
    echo "✅ No se encontraron extensiones del kernel relacionadas."
fi

# Recibos del sistema
echo "🧾 Eliminando recibos del sistema (pkg receipts)..."
sudo rm -rf /private/var/db/receipts/com.macpaw.*

# Verificación Spotlight
echo "🔍 Verificación final de Spotlight:"
mdfind "kMDItemDisplayName == '*CleanMyMac*'" || echo "✅ Sin resultados."

echo "✅ CleanMyMac ha sido completamente eliminado."
echo "==========================================="

