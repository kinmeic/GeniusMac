#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/build/xcode-derived-data"
PRODUCTS_DIR="$DERIVED_DATA/Build/Products/Debug"
APP_PATH="$PRODUCTS_DIR/GeniusMac.app"

cd "$ROOT_DIR"

xcodebuild \
  -project Genius.xcodeproj \
  -scheme GeniusMac \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build

echo "Built app:"
echo "$APP_PATH"
