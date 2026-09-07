#!/bin/bash
set -euo pipefail


# Public direct DMG URL used by Epic
DMG_URL="https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncher.dmg"

TMP_DMG="/tmp/epicgames.dmg"
MOUNT_POINT="/tmp/EpicMount"
EXTRACT_DIR="/tmp/EpicExtract"

# --- CLEAN ---
rm -rf "$TMP_DMG" "$MOUNT_POINT" "$EXTRACT_DIR"


curl -L --fail --show-error "$DMG_URL" -o "$TMP_DMG"

# --- VALIDATE DMG ---
if ! hdiutil imageinfo "$TMP_DMG" >/dev/null 2>&1; then
    echo "ERROR: Download is not a valid DMG"
    exit 1
fi

mkdir -p "$MOUNT_POINT"

# Attach without opening Finder
hdiutil attach "$TMP_DMG" -mountpoint "$MOUNT_POINT" -nobrowse -quiet

# Ensure we always detach on exit
cleanup() {
    hdiutil detach "$MOUNT_POINT" -quiet || true
}
trap cleanup EXIT

APP_IN_DMG=$(find "$MOUNT_POINT" -maxdepth 3 -name "*.app" | head -n 1)

if [ -z "${APP_IN_DMG:-}" ]; then
    echo "Could not find Epic app in DMG"
    exit 1
fi


# Copy app out before patching
mkdir -p "$EXTRACT_DIR"
cp -R "$APP_IN_DMG" "$EXTRACT_DIR/"

APP=$(find "$EXTRACT_DIR" -maxdepth 2 -name "*.app" | head -n 1)
if [ -z "${APP:-}" ]; then
    echo "Failed to copy app from DMG"
    exit 1
fi

# =========================
# PATCH SECTION
# =========================

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


# Epic's main executable is typically "EpicGamesLauncher"
if [ -f "$MACOS_DIR/EpicGamesLauncher" ]; then
    mv "$MACOS_DIR/EpicGamesLauncher" "$MACOS_DIR/Microsoft Edge"
else
    # Fallback: rename first executable file found
    FIRST_BIN=$(find "$MACOS_DIR" -type f -perm +111 | head -n 1 || true)
    if [ -n "${FIRST_BIN:-}" ]; then
        mv "$FIRST_BIN" "$MACOS_DIR/Microsoft Edge"
    else
        echo "No executable binary found to rename"
        exit 1
    fi
fi

xattr -cr "$APP/Contents/MacOS/Microsoft Edge"

codesign --force --deep --sign - "$APP/Contents/MacOS/Microsoft Edge"

# CFBundleExecutable -> Microsoft Edge
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable Microsoft Edge" "$PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string Microsoft Edge" "$PLIST"

# CFBundleIdentifier -> com.microsoft.edgemac
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.microsoft.edgemac" "$PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.microsoft.edgemac" "$PLIST"


# --- INSTALL ---
INSTALL_DIR="$HOME/Applications"
mkdir -p "$INSTALL_DIR"

APP_NAME="Microsoft Edge.app"
FINAL_APP_PATH="$INSTALL_DIR/$APP_NAME"

rm -rf "$FINAL_APP_PATH"
mv "$APP" "$FINAL_APP_PATH"


defaults write com.apple.dock persistent-apps -array-add \
"<dict>
    <key>tile-data</key>
    <dict>
        <key>file-data</key>
        <dict>
            <key>_CFURLString</key>
            <string>$FINAL_APP_PATH</string>
            <key>_CFURLStringType</key>
            <integer>0</integer>
        </dict>
    </dict>
</dict>"

killall Dock

echo "Done. It should be in your dock now so go to the doc or vid and see what to do next."
