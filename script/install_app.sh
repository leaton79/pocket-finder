#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="DesktopFileWidget"
BUNDLE_PATH="$ROOT_DIR/dist/$APP_NAME.app"
TARGET_DIR="/Applications"

if [[ ! -d "$BUNDLE_PATH" ]]; then
  "$ROOT_DIR/script/package_app.sh" >/dev/null
fi

if [[ ! -w "$TARGET_DIR" ]]; then
  TARGET_DIR="$HOME/Applications"
  mkdir -p "$TARGET_DIR"
fi

/usr/bin/ditto "$BUNDLE_PATH" "$TARGET_DIR/$APP_NAME.app"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$TARGET_DIR/$APP_NAME.app"

echo "$TARGET_DIR/$APP_NAME.app"
