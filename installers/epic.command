#!/bin/bash
set -euo pipefail

echo "Fetching Epic Games Launcher DMG..."

# Public direct DMG URL used by Epic
DMG_URL="https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncher.dmg"

TMP_DMG="/tmp/epicgames.dmg"
MOUNT_POINT="/tmp/EpicMount"
EXTRACT_DIR="/tmp/EpicExtract"

# --- CLEAN ---
rm -rf "$TMP_DMG" "$MOUNT_POINT" "$EXTRACT_DIR"

echo "Downloading from:"
echo "$DMG_URL"

curl -L --fail --show-error "$DMG_URL" -o "$TMP_DMG"

# --- VALIDATE DMG ---
FILE_TYPE=$(file "$TMP_DMG")
if ! echo "$FILE_TYPE" | grep -qi "apple disk image"; then
    echo "ERROR: Download is not a valid DMG (got something else)"
    exit 1
fi

echo "Mounting DMG..."
mkdir -p "$MOUNT_POINT"

# Attach without opening Finder
hdiutil attach "$TMP_DMG" -mountpoint "$MOUNT_POINT" -nobrowse -quiet

# Ensure we always detach on exit
cleanup() {
    hdiutil detach "$MOUNT_POINT" -quiet || true
}
trap cleanup EXIT

echo "Searching for app in mounted DMG..."
APP_IN_DMG=$(find "$MOUNT_POINT" -maxdepth 3 -name "*.app" | head -n 1)

if [ -z "${APP_IN_DMG:-}" ]; then
    echo "Could not find Epic app in DMG"
    exit 1
fi

echo "Found app: $APP_IN_DMG"

# Copy app out before patching
mkdir -p "$EXTRACT_DIR"
cp -R "$APP_IN_DMG" "$EXTRACT_DIR/"

APP=$(find "$EXTRACT_DIR" -maxdepth 2 -name "*.app" | head -n 1)
if [ -z "${APP:-}" ]; then
    echo "Failed to copy app from DMG"
    exit 1
fi

echo "Copied app to: $APP"

# =========================
# PATCH SECTION
# =========================

echo "Removing signature..."
codesign --remove-signature "$APP" 2>/dev/null || true

MACOS_DIR="$APP/Contents/MacOS"
PLIST="$APP/Contents/Info.plist"

if [ ! -d "$MACOS_DIR" ]; then
    echo "Missing MacOS directory in app bundle"
    exit 1
fi

if [ ! -f "$PLIST" ]; then
    echo "Missing Info.plist in app bundle"
    exit 1
fi

echo "Renaming binaries..."

# Epic's main executable is typically "EpicGamesLauncher"
if [ -f "$MACOS_DIR/EpicGamesLauncher" ]; then
    mv "$MACOS_DIR/EpicGamesLauncher" "$MACOS_DIR/r"
else
    # Fallback: rename first executable file found
    FIRST_BIN=$(find "$MACOS_DIR" -type f -perm +111 | head -n 1 || true)
    if [ -n "${FIRST_BIN:-}" ]; then
        mv "$FIRST_BIN" "$MACOS_DIR/r"
    else
        echo "No executable binary found to rename"
        exit 1
    fi
fi

echo "Editing Info.plist..."

# CFBundleExecutable -> r
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable r" "$PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string r" "$PLIST"

# CFBundleIdentifier -> leo.nel.com
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier leo.nel.com" "$PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string leo.nel.com" "$PLIST"

echo "Re-signing (ad-hoc)..."
codesign --force --deep --sign - "$APP"

echo "Verifying signature..."
codesign --verify --deep --strict "$APP" || true

# --- INSTALL ---
INSTALL_DIR="$HOME/Applications"
mkdir -p "$INSTALL_DIR"

APP_NAME="r.app"
FINAL_APP_PATH="$INSTALL_DIR/$APP_NAME"

rm -rf "$FINAL_APP_PATH"
mv "$APP" "$FINAL_APP_PATH"

echo "Installed successfully to $FINAL_APP_PATH"

# =========================
# LAUNCHER CREATION
# =========================

echo "Creating launch_r shortcut..."

LAUNCHER="$INSTALL_DIR/launch_r"

cat > "$LAUNCHER" <<EOF
#!/bin/bash
exec "$FINAL_APP_PATH/Contents/MacOS/r" "\$@"
EOF

chmod +x "$LAUNCHER"

echo "Launcher created at: $LAUNCHER"