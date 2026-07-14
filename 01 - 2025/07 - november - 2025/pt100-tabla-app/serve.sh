#!/usr/bin/env bash
# Servidor estático local para la app (necesario para Service Worker / offline).
# Author: Kirtan Teg Singh (ਕੀਰਤਨ ਤੇਗ ਸਿੰਘ)
set -euo pipefail
cd "$(dirname "$0")"
PORT="${1:-8080}"
echo "Tabla PT100 — http://localhost:${PORT}"
echo "Ctrl+C para detener."
if command -v python3 >/dev/null 2>&1; then
  exec python3 -m http.server "$PORT"
elif command -v python >/dev/null 2>&1; then
  exec python -m http.server "$PORT"
else
  echo "Se necesita Python 3." >&2
  exit 1
fi
