#!/bin/zsh

LOGFILE="$HOME/Desktop/bloqueo_red_$(date +%Y%m%d_%H%M%S).log"

echo "📋 Iniciando protección contra consumo inesperado de red..." | tee "$LOGFILE"

# 1. Desactivar softwareupdate y actualizaciones silenciosas
echo "🛑 Desactivando actualizaciones automáticas..." | tee -a "$LOGFILE"
sudo softwareupdate --schedule off
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool FALSE
sudo defaults write /Library/Preferences/com.apple.commerce AutoUpdate -bool FALSE

# 2. Detectar si la red actual es Personal Hotspot
CURRENT_SSID=$(networksetup -getairportnetwork en0 | awk -F': ' '{print $2}')
echo "📡 Red actual: $CURRENT_SSID" | tee -a "$LOGFILE"

if [[ "$CURRENT_SSID" == *"iPhone"* || "$CURRENT_SSID" == *"Android"* || "$CURRENT_SSID" == *"Hotspot"* ]]; then
  echo "⚠️ Red detectada como tethering (Hotspot). Activando medidas extra..." | tee -a "$LOGFILE"

  # 3. Bloquear conexiones a dominios de Apple a nivel de firewall
  echo "🔒 Bloqueando IPs de Apple relacionadas a iCloud y servicios del sistema..." | tee -a "$LOGFILE"

  APPLE_DOMAINS=(apple.com icloud.com swcdn.apple.com xp.apple.com guzzoni.apple.com configuration.apple.com)
  
  for domain in $APPLE_DOMAINS; do
    IPs=($(dig +short $domain | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'))
    for ip in $IPs; do
      echo "   ⛔ Bloqueando $domain [$ip]" | tee -a "$LOGFILE"
      sudo pfctl -t blocked -T add $ip
    done
  done

  # Aplicar reglas básicas de bloqueo con pf
  echo "🔧 Aplicando reglas temporales al firewall PF..." | tee -a "$LOGFILE"
  echo "table <blocked> persist" | sudo tee /etc/pf.anchors/blocked.apple > /dev/null
  echo "block drop out quick to <blocked>" | sudo tee -a /etc/pf.anchors/blocked.apple > /dev/null
  echo "anchor \"blocked.apple\"" | sudo tee -a /etc/pf.conf > /dev/null
  sudo pfctl -f /etc/pf.conf
  sudo pfctl -e
else
  echo "✅ Red no detectada como tethering. No se aplican reglas de bloqueo." | tee -a "$LOGFILE"
fi

echo "✅ Script completado. Log en: $LOGFILE" | tee -a "$LOGFILE"

