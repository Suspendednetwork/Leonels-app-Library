#!/bin/bash
set -euo pipefail

REPO="mont127/MacNdCheese"
INSTALL_DIR="$HOME/Applications"
TMP_DIR="$(mktemp -d)"
DMG_PATH="$TMP_DIR/macndcheese.dmg"
MOUNT_POINT="/Volumes/MacNdCheeseInstaller"

cleanup() {
  # Best effort cleanup
  hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "==> Resolving latest release for $REPO ..."
API_URL="https://api.github.com/repos/$REPO/releases/latest"

# Read the first .dmg asset URL from release JSON
DMG_URL="$(curl -fsSL "$API_URL" | \
  python3 -c 'import sys, json
data=json.load(sys.stdin)
assets=data.get("assets", [])
dmg=[a.get("browser_download_url","") for a in assets if a.get("name","").lower().endswith(".dmg")]
print(dmg[0] if dmg else "")')"

if [[ -z "$DMG_URL" ]]; then
  echo "ERROR: No .dmg asset found in latest release."
  exit 1
fi

echo "==> Downloading DMG:"
echo "    $DMG_URL"
curl -fL "$DMG_URL" -o "$DMG_PATH"

echo "==> Mounting DMG ..."
hdiutil attach "$DMG_PATH" -nobrowse -mountpoint "$MOUNT_POINT" -quiet

echo "==> Locating app bundle in mounted DMG ..."
APP_PATH="$(find "$MOUNT_POINT" -maxdepth 2 -type d -name "*.app" | head -n 1 || true)"
if [[ -z "$APP_PATH" ]]; then
  echo "ERROR: No .app found inside DMG."
  exit 1
fi

mkdir -p "$INSTALL_DIR"
APP_NAME="$(basename "$APP_PATH")"

echo "==> Installing $APP_NAME to $INSTALL_DIR ..."
rm -rf "$INSTALL_DIR/$APP_NAME"
cp -R "$APP_PATH" "$INSTALL_DIR/$APP_NAME"

echo "==> Done."
echo "Installed: $INSTALL_DIR/$APP_NAME"