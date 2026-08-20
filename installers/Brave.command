#!/bin/bash

echo "=========================================="
echo "  Brave Browser Installer "
echo "=========================================="

DOWNLOAD_URL="https://github.com/brave/brave-browser/releases/download/v1.93.136/Brave-Browser-universal.dmg"

echo "Downloading..."

# --- CLEAN ---
rm -rf /tmp/brave.zip /tmp/brave.dmg /tmp/brave.tar.xz /tmp/Brave\ Browser.app /tmp/Brave.app ~/Applications/s.app /tmp/extract /tmp/mount /tmp/brave_extracted.dmg

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

elif echo "$FILE_TYPE" | grep -qi "xz compressed"; then
    echo "XZ compressed file detected..."
    
    # Check if it's a tar.xz or just an xz-compressed file
    if tar -tf /tmp/brave_download >/dev/null 2>&1; then
        echo "Extracting tar.xz archive..."
        mkdir -p /tmp/extract
        tar -xf /tmp/brave_download -C /tmp/extract
        APP=$(find /tmp/extract -name "*.app" -maxdepth 3 | head -n 1)
    else
        # It's likely an xz-compressed DMG or single file
        echo "Decompressing XZ file..."
        
        # Try using macOS tar to decompress (it can handle single xz files too)
        if tar -xJf /tmp/brave_download -C /tmp 2>/dev/null; then
            echo "Decompressed with tar"
        else
            # Alternative: use python lzma module
            echo "Using Python to decompress..."
            python3 -c "
import lzma
import sys
with lzma.open('/tmp/brave_download', 'rb') as f_in:
    with open('/tmp/brave_extracted.dmg', 'wb') as f_out:
        f_out.write(f_in.read())
"
            echo "Decompressed to /tmp/brave_extracted.dmg"
        fi
        
        # Now check what we got
        if [ -f "/tmp/brave_extracted.dmg" ]; then
            FILE_TYPE2=$(file /tmp/brave_extracted.dmg)
            echo "Decompressed file type: $FILE_TYPE2"
            
            # FIX: Check for Apple/HFS/DMG signatures instead of just "zlib"
            if echo "$FILE_TYPE2" | grep -qiE "(Apple|HFS|Driver Map|partition)"; then
                echo "Mounting decompressed DMG..."
                mkdir -p /tmp/mount
                if hdiutil attach /tmp/brave_extracted.dmg -mountpoint /tmp/mount -nobrowse -quiet; then
                    APP=$(find /tmp/mount -name "*.app" -maxdepth 1 | head -n 1)
                    if [ -n "$APP" ]; then
                        cp -R "$APP" /tmp/
                        APP=$(find /tmp -name "*.app" -maxdepth 1 | head -n 1)
                    fi
                    hdiutil detach /tmp/mount -quiet 2>/dev/null || true
                else
                    echo "Failed to mount DMG"
                fi
            fi
        fi
        
        # Also check if tar extracted something or if app is elsewhere
        if [ -z "$APP" ]; then
            APP=$(find /tmp -name "*.app" -maxdepth 3 2>/dev/null | head -n 1)
        fi
    fi

else
    echo "Unknown file type: $FILE_TYPE"
    exit 1
fi

if [ -z "$APP" ] || [ ! -d "$APP" ]; then
    echo "Could not find Brave app"
    echo "Contents of /tmp:"
    ls -la /tmp/ | grep -E "(brave|Brave|extract|mount|\\.app)"
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

/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier Leo.23r.com" "$PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string Leo.23r.com" "$PLIST"

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
rm -rf /tmp/brave.zip /tmp/brave.dmg /tmp/brave.tar.xz /tmp/extract /tmp/mount /tmp/brave_extracted.dmg

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
open "https://tiktok.com/@itsleonelofficial/"
exit 0