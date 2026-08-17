#!/bin/bash
set -euo pipefail

echo "Fetching Epic Games Launcher DMG..."

DMG_URL="https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncher.dmg"

TMP_DMG="/tmp/epicgames.dmg"
MOUNT_POINT="/tmp/EpicMount"
EXTRACT_DIR="/tmp/EpicExtract"

# --- CLEAN ---
rm -rf "$TMP_DMG" "$MOUNT_POINT" "$EXTRACT_DIR"

echo "Downloading..."
curl -L --progress-bar "$DMG_URL" -o "$TMP_DMG"

echo "Mounting..."
mkdir -p "$MOUNT_POINT"
hdiutil attach "$TMP_DMG" -mountpoint "$MOUNT_POINT" -nobrowse -quiet

cleanup() {
    hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
}
trap cleanup EXIT

echo "Finding app..."
APP_IN_DMG=$(find "$MOUNT_POINT" -maxdepth 3 -name "*.app" | head -n 1)

if [ -z "$APP_IN_DMG" ]; then
    echo "Could not find Epic app"
    exit 1
fi

echo "Found: $(basename "$APP_IN_DMG")"

# Copy out
mkdir -p "$EXTRACT_DIR"
cp -R "$APP_IN_DMG" "$EXTRACT_DIR/"

APP=$(find "$EXTRACT_DIR" -maxdepth 2 -name "*.app" | head -n 1)
echo "Copied to: $APP"

# =========================
# PATCH SECTION
# =========================

echo "Patching..."

codesign --remove-signature "$APP" 2>/dev/null || true

MACOS_DIR="$APP/Contents/MacOS"
PLIST="$APP/Contents/Info.plist"

echo "Renaming binary..."

# Epic's binary is "EpicGamesLauncher" - check if it exists
if [ -f "$MACOS_DIR/EpicGamesLauncher" ]; then
    mv "$MACOS_DIR/EpicGamesLauncher" "$MACOS_DIR/r"
    echo "Renamed EpicGamesLauncher -> r"
else
    # Find any Mach-O executable
    for f in "$MACOS_DIR"/*; do
        if [ -f "$f" ] && file "$f" | grep -q "Mach-O.*executable"; then
            BASENAME=$(basename "$f")
            mv "$f" "$MACOS_DIR/r"
            echo "Renamed $BASENAME -> r"
            break
        fi
    done
fi

# Verify rename worked
if [ ! -f "$MACOS_DIR/r" ]; then
    echo "Warning: Could not rename binary, continuing..."
    # List what we found
    ls -la "$MACOS_DIR/"
fi

echo "Editing Info.plist..."

/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable r" "$PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string r" "$PLIST"

/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier leo.nel.com" "$PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string leo.nel.com" "$PLIST"

echo "Re-signing..."
codesign --force --deep --sign - "$APP" 2>/dev/null || true

# --- INSTALL ---
INSTALL_DIR="$HOME/Applications"
mkdir -p "$INSTALL_DIR"

FINAL_APP_PATH="$INSTALL_DIR/r.app"

rm -rf "$FINAL_APP_PATH"
mv "$APP" "$FINAL_APP_PATH"

xattr -rd com.apple.quarantine "$FINAL_APP_PATH" 2>/dev/null || true

echo "Installed to: $FINAL_APP_PATH"

# =========================
# LAUNCHER
# =========================

LAUNCHER="$INSTALL_DIR/launch_r"

cat > "$LAUNCHER" << 'EOF'
#!/bin/bash
exec "$HOME/Applications/r.app/Contents/MacOS/r" "$@"
EOF

chmod +x "$LAUNCHER"

echo "Done! Launch with: $LAUNCHER"

exit 0