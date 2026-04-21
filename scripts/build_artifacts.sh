#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Genius.xcodeproj"
SCHEME="GeniusMac"
APP_NAME="GeniusMac"
INFO_PLIST="$ROOT_DIR/GeniusMac/Resources/Info.plist"
CONFIGURATIONS_STRING="${CONFIGURATIONS:-Debug Release}"
DERIVED_DATA_ROOT="${DERIVED_DATA_ROOT:-$ROOT_DIR/build/derived-data}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/build/artifacts}"

if [[ -n "${RELEASE_VERSION:-}" ]]; then
  VERSION="$RELEASE_VERSION"
else
  VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$INFO_PLIST")"
fi

rm -rf "$OUTPUT_ROOT"
mkdir -p "$OUTPUT_ROOT"

for CONFIGURATION in ${(z)CONFIGURATIONS_STRING}; do
  DERIVED_DATA_PATH="$DERIVED_DATA_ROOT/$CONFIGURATION"
  PRODUCT_DIR="$OUTPUT_ROOT/$CONFIGURATION"
  APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME.app"
  DSYM_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME.app.dSYM"
  APP_ARCHIVE="$PRODUCT_DIR/${APP_NAME}-${VERSION}-${CONFIGURATION}.zip"
  DSYM_ARCHIVE="$PRODUCT_DIR/${APP_NAME}-${VERSION}-${CONFIGURATION}-dSYM.zip"

  rm -rf "$DERIVED_DATA_PATH" "$PRODUCT_DIR"
  mkdir -p "$PRODUCT_DIR"

  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    build

  if [[ ! -d "$APP_PATH" ]]; then
    echo "Expected app bundle was not produced at $APP_PATH" >&2
    exit 1
  fi

  ditto "$APP_PATH" "$PRODUCT_DIR/$APP_NAME.app"
  ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$APP_ARCHIVE"

  if [[ -d "$DSYM_PATH" ]]; then
    ditto "$DSYM_PATH" "$PRODUCT_DIR/$APP_NAME.app.dSYM"
    ditto -c -k --sequesterRsrc --keepParent "$DSYM_PATH" "$DSYM_ARCHIVE"
  fi

  (
    cd "$PRODUCT_DIR"
    shasum -a 256 ./*.zip > SHA256SUMS.txt
  )
done

echo "Created build artifacts:"
find "$OUTPUT_ROOT" -maxdepth 2 -type f | sort
