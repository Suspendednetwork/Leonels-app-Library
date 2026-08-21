#!/bin/bash

# ==========================================
# Generic macOS App Installer 
# ==========================================

DOWNLOAD_URL="https://apps.suspendednetwork.tech/dmgs/spotify.dmg"
APP_NAME="stoppify"

echo "=========================================="
echo "  Modded spotify installer macOS"
echo "=========================================="

# --- GENERATE RANDOM BUNDLE ID ---
RANDOM_PART1=$(cat /dev/urandom | tr -dc 'a-z0-9' | head -c 3)
RANDOM_PART2=$(cat /dev/urandom | tr -dc 'a-z0-9' | head -c 3)
BUNDLE_ID="leo.${RANDOM_PART1}.${RANDOM_PART2}"

echo Follow @itsleonelofficial on tiktok!
echo Follow @itsleonelofficial on tiktok!
echo Follow @itsleonelofficial on tiktok!
echo Follow @itsleonelofficial on tiktok!
echo Follow @itsleonelofficial on tiktok!


# --- CONFIG ---
TEMP_DIR="/tmp/install_$$"
INSTALL_DIR="$HOME/Applications"
FINAL_NAME="${APP_NAME:-App}"

# --- CLEAN ---
rm -rf "$TEMP_DIR" "$INSTALL_DIR/${FINAL_NAME}.app"
mkdir -p "$TEMP_DIR"

# --- DOWNLOAD ---
echo "Downloading from $DOWNLOAD_URL..."
curl -L -A "Mozilla/5.0" --progress-bar "$DOWNLOAD_URL" -o "$TEMP_DIR/download" || {
    echo "Download failed!"
    exit 1
}

FILE_TYPE=$(file "$TEMP_DIR/download")
echo "Detected: $FILE_TYPE"

# --- EXTRACT ---
APP_PATH=""

if echo "$FILE_TYPE" | grep -qi "zip"; then
    echo "Extracting ZIP..."
    unzip -q "$TEMP_DIR/download" -d "$TEMP_DIR/extract"
    APP_PATH=$(find "$TEMP_DIR/extract" -name "*.app" -maxdepth 3 | head -n 1)
    
elif echo "$FILE_TYPE" | grep -qi "zlib\|compressed"; then
    echo "Extracting DMG..."
    mkdir -p "$TEMP_DIR/mount"
    hdiutil attach "$TEMP_DIR/download" -mountpoint "$TEMP_DIR/mount" -nobrowse -quiet
    APP_PATH=$(find "$TEMP_DIR/mount" -name "*.app" -maxdepth 1 | head -n 1)
    
    if [ -n "$APP_PATH" ]; then
        cp -R "$APP_PATH" "$TEMP_DIR/"
        APP_PATH=$(find "$TEMP_DIR" -name "*.app" -maxdepth 1 | head -n 1)
    fi
    
    hdiutil detach "$TEMP_DIR/mount" -quiet 2>/dev/null || true
    
else
    echo "Unknown file type. Trying as ZIP..."
    unzip -q "$TEMP_DIR/download" -d "$TEMP_DIR/extract" 2>/dev/null || {
        echo "Extraction failed!"
        exit 1
    }
    APP_PATH=$(find "$TEMP_DIR/extract" -name "*.app" -maxdepth 3 | head -n 1)
fi

# --- VERIFY ---
if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "Could not find .app bundle in download"
    exit 1
fi

echo "Found: $(basename "$APP_PATH")"

# --- PATCH ---
echo "Patching app..."

codesign --remove-signature "$APP_PATH" 2>/dev/null || true

MACOS_DIR="$APP_PATH/Contents/MacOS"
PLIST="$APP_PATH/Contents/Info.plist"

if [ -d "$MACOS_DIR" ]; then
    MAIN_BIN=$(find "$MACOS_DIR" -type f -perm +111 ! -name "*.*" | head -n 1 | xargs basename 2>/dev/null)
    
    if [ -n "$MAIN_BIN" ] && [ "$MAIN_BIN" != "s" ]; then
        mv "$MACOS_DIR/$MAIN_BIN" "$MACOS_DIR/s" 2>/dev/null && echo "Renamed binary: $MAIN_BIN -> s"
        
        # Update plist
        /usr/libexec/PlistBuddy -c "Set :CFBundleExecutable s" "$PLIST" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string s" "$PLIST" 2>/dev/null
    fi
    
    chmod +x "$MACOS_DIR"/s 2>/dev/null || chmod +x "$MACOS_DIR"/* 2>/dev/null
fi

# Set RANDOM bundle ID
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $BUNDLE_ID" "$PLIST" 2>/dev/null

/usr/libexec/PlistBuddy -c "Set :CFBundleName $FINAL_NAME" "$PLIST" 2>/dev/null || true

codesign --force --deep --sign - "$APP_PATH" 2>/dev/null || true

# --- INSTALL ---
mkdir -p "$INSTALL_DIR"
FINAL_PATH="$INSTALL_DIR/${FINAL_NAME}.app"

rm -rf "$FINAL_PATH"
mv "$APP_PATH" "$FINAL_PATH"

xattr -rd com.apple.quarantine "$FINAL_PATH" 2>/dev/null || true

echo "Installed to: $FINAL_PATH"
echo "Bundle ID: $BUNDLE_ID"

# --- LAUNCHER ---
LAUNCHER="$INSTALL_DIR/launch_${FINAL_NAME,,}"
cat > "$LAUNCHER" << EOF
#!/bin/bash
exec "$FINAL_PATH/Contents/MacOS/s" "\$@" 2>/dev/null || exec "$FINAL_PATH/Contents/MacOS/"* "\$@"
EOF
chmod +x "$LAUNCHER"

# --- CLEANUP ---
rm -rf "$TEMP_DIR"

echo ""
echo "=========================================="
echo "  Done! Launching $FINAL_NAME..."
echo "=========================================="

# Try to launch
if [ -x "$FINAL_PATH/Contents/MacOS/s" ]; then
    "$FINAL_PATH/Contents/MacOS/s" &
elif [ -n "$(ls "$FINAL_PATH/Contents/MacOS/" 2>/dev/null | head -1)" ]; then
    "$FINAL_PATH/Contents/MacOS/"$(ls "$FINAL_PATH/Contents/MacOS/" | head -1) &
fi

open https://apps.suspendednetwork.tech/

exit 0