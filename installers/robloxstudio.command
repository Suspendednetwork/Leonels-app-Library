#!/bin/bash
set -e

echo "=========================================="
echo "  Roblox Studio Mac Installer"
echo "=========================================="

if [ "$(uname -s)" != "Darwin" ]; then
    echo "ERROR: Roblox Studio installer for macOS must run on a Mac."
    exit 1
fi

DMG="/tmp/RobloxStudio.dmg"
MOUNT_DIR="/tmp/RobloxStudioMount"

rm -f "$DMG"
rm -rf "$MOUNT_DIR"
mkdir -p "$MOUNT_DIR"

if [ "$(uname -m)" = "arm64" ]; then
    DOWNLOAD_URLS=(
        "https://setup.rbxcdn.com/channel/zmacarm64/mac/arm64/RobloxStudio.dmg"
        "https://setup.rbxcdn.com/mac/RobloxStudio.dmg"
    )
else
    DOWNLOAD_URLS=(
        "https://setup.rbxcdn.com/mac/RobloxStudio.dmg"
        "https://setup.rbxcdn.com/channel/zmacarm64/mac/arm64/RobloxStudio.dmg"
    )
fi

DOWNLOADED=false
for DOWNLOAD_URL in "${DOWNLOAD_URLS[@]}"; do
    echo "Downloading from: $DOWNLOAD_URL"
    if curl -L --fail --show-error --progress-bar "$DOWNLOAD_URL" -o "$DMG"; then
        if file "$DMG" | grep -Eq "Apple Disk Image|bzip2 compressed|zlib compressed"; then
            DOWNLOADED=true
            break
        fi
    fi
    rm -f "$DMG"
done

if [ "$DOWNLOADED" != "true" ]; then
    echo "ERROR: Could not download a valid Roblox Studio disk image."
    exit 1
fi

echo "Mounting installer..."
hdiutil attach "$DMG" -nobrowse -readonly -mountpoint "$MOUNT_DIR" >/dev/null

SOURCE_APP=$(find "$MOUNT_DIR" -maxdepth 2 -name "RobloxStudio.app" -print -quit)
if [ -z "$SOURCE_APP" ]; then
    hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true
    rm -f "$DMG"
    rm -rf "$MOUNT_DIR"
    echo "ERROR: RobloxStudio.app was not found in the disk image."
    exit 1
fi

FINAL_APP="/Applications/RobloxStudio.app"

echo "Installing to: $FINAL_APP"
rm -rf "$FINAL_APP"
ditto "$SOURCE_APP" "$FINAL_APP"

hdiutil detach "$MOUNT_DIR" >/dev/null
xattr -rd com.apple.quarantine "$FINAL_APP" 2>/dev/null || true

rm -f "$DMG"
rm -rf "$MOUNT_DIR"

echo ""
echo "=========================================="
echo "  Roblox Studio installed"
echo "=========================================="

open "$FINAL_APP"

exit 0
