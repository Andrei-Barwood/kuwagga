#!/usr/bin/env bash
# Release arm64 → dist/emodolls studio.app
# No notariza. Arrastrar el .app a /Applications.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PROJ="$ROOT/EmodollsStudio"
DIST="$ROOT/dist"
DERIVED="$ROOT/build"
APP_NAME="emodolls studio.app"

cd "$PROJ"
xcodebuild \
  -scheme EmodollsStudio \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$DERIVED" \
  -allowProvisioningUpdates \
  build

SRC="$DERIVED/Build/Products/Release/$APP_NAME"
test -d "$SRC"

rm -rf "$DIST"
mkdir -p "$DIST"
ditto "$SRC" "$DIST/$APP_NAME"

cat > "$DIST/LEEME.txt" <<'EOF'
emodolls studio

Arrastra «emodolls studio.app» a /Applications.

No está notarizado. En esta Mac, si Gatekeeper avisa: clic derecho → Abrir.
EOF

echo "OK $DIST/$APP_NAME"
