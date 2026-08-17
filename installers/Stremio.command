#!/bin/bash

echo "=========================================="
echo "  Stremio + Torrentio Installer"
echo "=========================================="

DOWNLOAD_URL="https://dl.strem.io/apple/macos/release/Stremio-2.0.4-19-4-1-155a8be13bad.zip"

echo "Downloading..."

# --- CLEAN ---
rm -rf /tmp/stremio.zip /tmp/Stremio.app ~/Applications/s.app /tmp/extract

# --- DOWNLOAD ---
curl -L -A "Mozilla/5.0" --progress-bar "$DOWNLOAD_URL" -o /tmp/stremio_download

FILE_TYPE=$(file /tmp/stremio_download)
echo "File type: $FILE_TYPE"

# --- EXTRACT ---
if echo "$FILE_TYPE" | grep -q "Zip"; then
    echo "Extracting ZIP..."
    mv /tmp/stremio_download /tmp/stremio.zip
    mkdir -p /tmp/extract
    unzip -q /tmp/stremio.zip -d /tmp/extract
    APP=$(find /tmp/extract -name "*.app" -maxdepth 2 | head -n 1)
else
    echo "Not a ZIP"
    exit 1
fi

if [ -z "$APP" ]; then
    echo "Could not find Stremio app"
    exit 1
fi

echo "Found: $APP"

cp -R "$APP" /tmp/Stremio.app
APP="/tmp/Stremio.app"
MACOS_DIR="$APP/Contents/MacOS"
PLIST="$APP/Contents/Info.plist"

# =========================
# PATCH SECTION
# =========================

echo "Patching..."

codesign --remove-signature "$APP" 2>/dev/null || true

MAIN_BIN=$(find "$MACOS_DIR" -type f -perm +111 | head -n 1 | xargs basename)

if [ -n "$MAIN_BIN" ] && [ "$MAIN_BIN" != "s" ]; then
    mv "$MACOS_DIR/$MAIN_BIN" "$MACOS_DIR/s"
    echo "Renamed $MAIN_BIN -> s"
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable s" "$PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string s" "$PLIST"

/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier Leo.nel.com" "$PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string Leo.nel.com" "$PLIST"

/usr/libexec/PlistBuddy -c "Set :CFBundleName s" "$PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleName string s" "$PLIST"

codesign --force --deep --sign - "$APP" 2>/dev/null || true
chmod +x "$MACOS_DIR/s" 2>/dev/null || true

# --- INSTALL ---
INSTALL_DIR="$HOME/Applications"
mkdir -p "$INSTALL_DIR"

FINAL_APP_PATH="$INSTALL_DIR/s.app"

rm -rf "$FINAL_APP_PATH"
mv "$APP" "$FINAL_APP_PATH"

xattr -rd com.apple.quarantine "$FINAL_APP_PATH" 2>/dev/null || true

echo "Installed to: $FINAL_APP_PATH"

# =========================
# LAUNCHER SCRIPTS
# =========================

echo "Creating launchers..."

# Basic launcher
LAUNCHER="$INSTALL_DIR/launch_st"
cat > "$LAUNCHER" << EOF
#!/bin/bash
exec "$FINAL_APP_PATH/Contents/MacOS/s" "\$@"
EOF
chmod +x "$LAUNCHER"

# Open helper (removes quarantine)
OPEN_HELPER="$INSTALL_DIR/Launch_st"
cat > "$OPEN_HELPER" << 'EOF'
#!/bin/bash
APP="$HOME/Applications/s.app"
xattr -rd com.apple.quarantine "$APP" 2>/dev/null
"$APP/Contents/MacOS/s" &
EOF
chmod +x "$OPEN_HELPER"

# Cleanup
rm -rf /tmp/stremio.zip /tmp/extract

# =========================
# AUTO TORRENTIO INSTALL
# =========================

echo ""
echo "=========================================="
echo "  Launching Stremio + Installing Torrentio..."
echo "=========================================="

# Launch Stremio in background
open "$FINAL_APP_PATH"

# Wait for Stremio to fully initialize
echo "Waiting for Stremio to start (5 seconds)..."
sleep 5

# Open Torrentio addon URL (triggers install dialog in Stremio)
echo "Opening Torrentio addon..."
open "stremio://torrentio.strem.fun/manifest.json"

echo ""
echo "=========================================="
echo "  Done!"
echo "=========================================="
echo ""
echo "Click 'Install' in the Stremio window!"
echo ""
echo "App: $FINAL_APP_PATH"
echo "Launch: $OPEN_HELPER"
echo ""
sleep 10
open "https://suspendednetwork.github.io/Leonels-app-Library/"

exit 0