#!/bin/bash

echo "=========================================="
echo "  Prism Launcher for Minecraft (Cracked edition) "
echo "=========================================="

DOWNLOAD_URL="https://github.com/Diegiwg/PrismLauncher-Cracked/releases/download/11.0.3/PrismLauncher-macOS-11.0.3.zip"

echo "Downloading..."

# --- CLEAN ---
rm -rf /tmp/prism.zip /tmp/PrismLauncher.app ~/Applications/s.app /tmp/extract

# --- DOWNLOAD ---
curl -L -A "Mozilla/5.0" --progress-bar "$DOWNLOAD_URL" -o /tmp/prism_download

FILE_TYPE=$(file /tmp/prism_download)
echo "File type: $FILE_TYPE"

# --- EXTRACT ---
if echo "$FILE_TYPE" | grep -q "Zip"; then
    echo "Extracting ZIP..."
    mv /tmp/prism_download /tmp/prism.zip
    mkdir -p /tmp/extract
    unzip -q /tmp/prism.zip -d /tmp/extract
    APP=$(find /tmp/extract -name "*.app" -maxdepth 2 | head -n 1)
else
    echo "Not a ZIP"
    exit 1
fi

if [ -z "$APP" ]; then
    echo "Could not find PrismLauncher app"
    exit 1
fi

echo "Found: $APP"

cp -R "$APP" /tmp/PrismLauncher.app
APP="/tmp/PrismLauncher.app"
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

/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier Leo.312.com" "$PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string Leo.312.com" "$PLIST"

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

# Cleanup
rm -rf /tmp/prism.zip /tmp/extract

echo ""
echo "=========================================="
echo "  Launching Prism Launcher"
echo "=========================================="

# Launch detached - terminal can close, app keeps running
nohup "$FINAL_APP_PATH/Contents/MacOS/s" > /tmp/prism.log 2>&1 &
disown

echo "Launched! (Logs: /tmp/prism.log)"

echo ""
echo "=========================================="
echo "  Done!"
echo "=========================================="
echo ""
sleep 10
open "https://apps.suspendednetwork.tech/"

exit 0