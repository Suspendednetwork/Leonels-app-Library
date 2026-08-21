#!/bin/bash

# ==========================================
# Generic macOS App Installer (Fixed)
# ==========================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

DOWNLOAD_URL="https://apps.suspendednetwork.tech/dmgs/spotify.dmg"
APP_NAME="stoppify"

echo "=========================================="
echo "  Modded spotify installer macOS"
echo "=========================================="

# --- GENERATE RANDOM BUNDLE ID (Fixed for macOS) ---
RANDOM_PART1=$(LC_ALL=C tr -dc 'a-z0-9' < /dev/urandom | head -c 3)
RANDOM_PART2=$(LC_ALL=C tr -dc 'a-z0-9' < /dev/urandom | head -c 3)
BUNDLE_ID="leo.${RANDOM_PART1}.${RANDOM_PART2}"

echo "Follow @itsleonelofficial on tiktok!"
echo "Follow @itsleonelofficial on tiktok!"
echo "Follow @itsleonelofficial on tiktok!"
echo "Follow @itsleonelofficial on tiktok!"
echo "Follow @itsleonelofficial on tiktok!"

# --- CONFIG ---
TEMP_DIR="/tmp/install_$$"
INSTALL_DIR="$HOME/Applications"
FINAL_NAME="${APP_NAME:-App}"

# --- CLEAN ---
rm -rf "$TEMP_DIR" "$INSTALL_DIR/${FINAL_NAME}.app"
mkdir -p "$TEMP_DIR"

# --- DOWNLOAD (Fixed with proper error handling) ---
echo "Downloading from $DOWNLOAD_URL..."

HTTP_CODE=$(curl -L -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
    --progress-bar \
    --max-time 120 \
    --retry 3 \
    --retry-delay 2 \
    -w "%{http_code}" \
    -o "$TEMP_DIR/download" \
    "$DOWNLOAD_URL" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" != "200" ]; then
    echo "ERROR: Download failed with HTTP code $HTTP_CODE"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Verify file isn't HTML error page
if grep -q "<html" "$TEMP_DIR/download" 2>/dev/null || grep -q "<!DOCTYPE" "$TEMP_DIR/download" 2>/dev/null; then
    echo "ERROR: Downloaded file is HTML (likely an error page or redirect)"
    echo "Content preview:"
    head -c 500 "$TEMP_DIR/download"
    rm -rf "$TEMP_DIR"
    exit 1
fi

FILE_TYPE=$(file "$TEMP_DIR/download")
echo "Detected: $FILE_TYPE"

# --- EXTRACT (Fixed detection logic) ---
APP_PATH=""

# Check if it's a DMG (various signatures)
if echo "$FILE_TYPE" | grep -qiE "(zlib|compressed|VAX COFF|data|UDIF|Apple_HFS)" || \
   file -b "$TEMP_DIR/download" | grep -qiE "(UDIF|Apple_HFS|HFS|dmg)" || \
   [ "${DOWNLOAD_URL##*.}" = "dmg" ]; then
    
    echo "Extracting DMG..."
    mkdir -p "$TEMP_DIR/mount"
    
    if ! hdiutil attach "$TEMP_DIR/download" -mountpoint "$TEMP_DIR/mount" -nobrowse -quiet 2>/dev/null; then
        echo "ERROR: Failed to mount DMG"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    APP_PATH=$(find "$TEMP_DIR/mount" -name "*.app" -maxdepth 3 -print -quit 2>/dev/null | head -n 1)
    
    if [ -n "$APP_PATH" ] && [ -d "$APP_PATH" ]; then
        cp -R "$APP_PATH" "$TEMP_DIR/"
        APP_PATH=$(find "$TEMP_DIR" -maxdepth 1 -name "*.app" -print -quit)
    fi
    
    hdiutil detach "$TEMP_DIR/mount" -quiet 2>/dev/null || true

# Check if it's a ZIP
elif echo "$FILE_TYPE" | grep -qi "zip"; then
    echo "Extracting ZIP..."
    mkdir -p "$TEMP_DIR/extract"
    
    if ! unzip -q "$TEMP_DIR/download" -d "$TEMP_DIR/extract" 2>/dev/null; then
        echo "ERROR: Failed to extract ZIP"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    APP_PATH=$(find "$TEMP_DIR/extract" -name "*.app" -maxdepth 3 -print -quit 2>/dev/null | head -n 1)

# Try as DMG anyway if file command is inconclusive
else
    echo "Unknown file type, attempting DMG extraction..."
    mkdir -p "$TEMP_DIR/mount"
    
    if hdiutil attach "$TEMP_DIR/download" -mountpoint "$TEMP_DIR/mount" -nobrowse -quiet 2>/dev/null; then
        APP_PATH=$(find "$TEMP_DIR/mount" -name "*.app" -maxdepth 3 -print -quit 2>/dev/null | head -n 1)
        
        if [ -n "$APP_PATH" ] && [ -d "$APP_PATH" ]; then
            cp -R "$APP_PATH" "$TEMP_DIR/"
            APP_PATH=$(find "$TEMP_DIR" -maxdepth 1 -name "*.app" -print -quit)
        fi
        
        hdiutil detach "$TEMP_DIR/mount" -quiet 2>/dev/null || true
    else
        echo "ERROR: Could not extract file"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
fi

# --- VERIFY ---
if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "ERROR: Could not find .app bundle in download"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo "Found: $(basename "$APP_PATH")"

# --- PATCH ---
echo "Patching app..."

codesign --remove-signature "$APP_PATH" 2>/dev/null || true

MACOS_DIR="$APP_PATH/Contents/MacOS"
PLIST="$APP_PATH/Contents/Info.plist"

if [ -d "$MACOS_DIR" ]; then
    MAIN_BIN=$(find "$MACOS_DIR" -type f -perm /111 ! -name "*.*" -print -quit 2>/dev/null | xargs basename 2>/dev/null || true)
    
    if [ -n "$MAIN_BIN" ] && [ "$MAIN_BIN" != "s" ]; then
        mv "$MACOS_DIR/$MAIN_BIN" "$MACOS_DIR/s" 2>/dev/null && echo "Renamed binary: $MAIN_BIN -> s"
        
        /usr/libexec/PlistBuddy -c "Set :CFBundleExecutable s" "$PLIST" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string s" "$PLIST" 2>/dev/null || true
    fi
    
    chmod +x "$MACOS_DIR"/s 2>/dev/null || chmod +x "$MACOS_DIR"/* 2>/dev/null || true
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $BUNDLE_ID" "$PLIST" 2>/dev/null || true

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

# --- CLEANUP ---
rm -rf "$TEMP_DIR"

echo ""
echo "=========================================="
echo "  Done! Launching $FINAL_NAME..."
echo "=========================================="

open "$FINAL_PATH"

(nohup open "https://apps.suspendednetwork.tech/" >/dev/null 2>&1 &)

exit 0