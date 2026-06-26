#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "→ Generando iconos…"
"$ROOT/Scripts/generate_app_icon.swift"

echo "→ Compilando binario universal…"
xcodebuild \
  -project TerminalStyles.xcodeproj \
  -scheme "Terminal Styles" \
  -configuration Release \
  ONLY_ACTIVE_ARCH=NO \
  ARCHS="arm64 x86_64" \
  clean build

DERIVED="$HOME/Library/Developer/Xcode/DerivedData"
PRODUCT="$(find "$DERIVED" -path "*/Build/Products/Release/Terminal Styles.app" -type d | head -1)"

if [[ -z "$PRODUCT" ]]; then
  echo "No se encontró el .app compilado." >&2
  exit 1
fi

mkdir -p "$ROOT/dist"
rm -rf "$ROOT/dist/Terminal Styles.app"
cp -R "$PRODUCT" "$ROOT/dist/"

/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister \
  -f -R -trusted "$ROOT/dist/Terminal Styles.app"

echo "✓ Listo: $ROOT/dist/Terminal Styles.app"
ls -la "$ROOT/dist/Terminal Styles.app/Contents/Resources/"