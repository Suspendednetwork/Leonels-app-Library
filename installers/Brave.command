#!/bin/bash

echo "=========================================="
echo "  Brave Browser Installer "
echo "=========================================="

DOWNLOAD_URL="https://laptop-updates.brave.com/download/BRV090?bitness=64"

echo "Downloading..."

# --- CLEAN ---
rm -rf /tmp/brave.zip /tmp/brave.dmg /tmp/Brave\ Browser.app /tmp/Brave.app ~/Applications/s.app /tmp/extract /tmp/mount

# --- DOWNLOAD ---
curl -L -A "Mozilla/5.0" --progress-bar "$DOWNLOAD_URL" -o /tmp/brave_download

FILE_TYPE=$(file /tmp/brave_download)
echo "File type: $FILE_TYPE"

# --- EXTRACT ---
if echo "$FILE_TYPE" | grep -q "Zip"; then
    echo "Extracting ZIP..."
    mv /tmp/brave_download /tmp/brave.zip
    mkdir -p /tmp/extract
    unzip -q /tmp/brave.zip -d /tmp/extract
    APP=$(find /tmp/extract -name "*.app" -maxdepth 2 | head -n 1)
elif echo "$FILE_TYPE" | grep -q "zlib"; then
    echo "Extracting DMG..."
    mv /tmp/brave_download /tmp/brave.dmg
    mkdir -p /tmp/mount
    hdiutil attach /tmp/brave.dmg -mountpoint /tmp/mount -nobrowse -quiet
    APP=$(find /tmp/mount -name "*.app" -maxdepth 1 | head -n 1)
    cp -R "$APP" /tmp/
    APP=$(find /tmp -name "*.app" -maxdepth 1 | head -n 1)
    hdiutil detach /tmp/mount -quiet
else
    echo "Unknown file type"
    exit 1
fi

if [ -z "$APP" ]; then
    echo "Could not find Brave app"
    exit 1
fi

echo "Found: $APP"

cp -R "$APP" /tmp/Brave.app
APP="/tmp/Brave.app"
MACOS_DIR="$APP/Contents/MacOS"
PLIST="$APP/Contents/Info.plist"

# =========================
# PATCH SECTION
# =========================

echo "Patching..."

codesign --remove-signature "$APP" 2>/dev/null || true

MAIN_BIN=$(find "$MACOS_DIR" -type f -perm +111 | grep -v "Helper" | head -n 1 | xargs basename)

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
LAUNCHER="$INSTALL_DIR/launch_brave"
cat > "$LAUNCHER" << EOF
#!/bin/bash
exec "$FINAL_APP_PATH/Contents/MacOS/s" "\$@"
EOF
chmod +x "$LAUNCHER"

# Open helper (removes quarantine)
OPEN_HELPER="$INSTALL_DIR/Launch_Brave"
cat > "$OPEN_HELPER" << 'EOF'
#!/bin/bash
APP="$HOME/Applications/s.app"
xattr -rd com.apple.quarantine "$APP" 2>/dev/null
"$APP/Contents/MacOS/s" &
EOF
chmod +x "$OPEN_HELPER"

# Cleanup
rm -rf /tmp/brave.zip /tmp/brave.dmg /tmp/extract /tmp/mount

echo ""
echo "=========================================="
echo "  Launching Brave Browser"
echo "=========================================="

"$FINAL_APP_PATH/Contents/MacOS/s" &

echo ""
echo "=========================================="
echo "  Done!"
echo "=========================================="
echo ""
sleep 10
open "https://suspendednetwork.github.io/Leonels-app-Library/"

exit 0