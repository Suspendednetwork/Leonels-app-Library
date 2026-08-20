#!/bin/bash
set -e

echo "=========================================="
echo "  Roblox MacPlayer Installer"
echo "=========================================="

echo "Fetching Roblox MacPlayer version..."

# --- GET VERSION HASH ---
ROBLOX_VERSION=$(
curl -fsSL "https://clientsettings.roblox.com/v2/client-version/MacPlayer/channel/LIVE" \
| grep -o '"clientVersionUpload":"[^"]*"' | cut -d'"' -f4
)

if [ -z "$ROBLOX_VERSION" ]; then
    echo "Failed to fetch Roblox version"
    exit 1
fi

echo "Detected version: $ROBLOX_VERSION"

# --- CLEAN ---
rm -rf ~/Applications/r.app /tmp/roblox.zip /tmp/RobloxExtract

# --- ARCH DETECTION ---
ARCH="arm64"
if [ "$(uname -m)" = "x86_64" ]; then
    ARCH="x86-64"
fi

# --- BUILD DOWNLOAD URL ---
DOWNLOAD_URL="https://setup-aws.rbxcdn.com/mac/${ARCH}/${ROBLOX_VERSION}-RobloxPlayer.zip"

echo "Downloading from: $DOWNLOAD_URL"

curl -L --fail --show-error --progress-bar "$DOWNLOAD_URL" -o /tmp/roblox.zip

# --- VALIDATE ZIP ---
FILE_TYPE=$(file /tmp/roblox.zip)
if ! echo "$FILE_TYPE" | grep -q "Zip archive data"; then
    echo "ERROR: Download is not a valid ZIP"
    exit 1
fi

# --- EXTRACT ---
mkdir -p /tmp/RobloxExtract
unzip -q /tmp/roblox.zip -d /tmp/RobloxExtract

APP=$(find /tmp/RobloxExtract -name "*.app" | head -n 1)
if [ -z "$APP" ]; then
    echo "Could not find Roblox app"
    exit 1
fi

echo "Found app: $(basename "$APP")"

# =========================
# PATCH SECTION
# =========================

echo "Removing signature..."
codesign --remove-signature "$APP" 2>/dev/null || true

MACOS_DIR="$APP/Contents/MacOS"
PLIST="$APP/Contents/Info.plist"

# Rename main binary
if [ -f "$MACOS_DIR/RobloxPlayer" ]; then
    mv "$MACOS_DIR/RobloxPlayer" "$MACOS_DIR/r"
    echo "Renamed: RobloxPlayer -> r"
fi

# DELETE the original updater binary
echo "Installing custom updater..."
rm -f "$MACOS_DIR/RobloxPlayerInstaller"

# Create script WITH ORIGINAL NAME that just launches the game
cat > "$MACOS_DIR/RobloxPlayerInstaller" << 'UPSCRIPT'
#!/bin/bash
# Fake updater - just launches the patched game instead of updating

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$APP_DIR/MacOS/r" "$@"
UPSCRIPT

chmod +x "$MACOS_DIR/RobloxPlayerInstaller"

# Edit plist - main executable is 'r', not the installer
echo "Editing Info.plist..."
defaults write "$PLIST" CFBundleExecutable -string "r"
defaults write "$PLIST" CFBundleIdentifier -string "leo.nel.com"

chmod +x "$MACOS_DIR/r"

# Re-sign with ad-hoc signature
echo "Re-signing app..."
codesign --force --deep --sign - "$APP"

# --- INSTALL ---
INSTALL_DIR="$HOME/Applications"
mkdir -p "$INSTALL_DIR"

FINAL_APP_PATH="$INSTALL_DIR/r.app"
rm -rf "$FINAL_APP_PATH"
mv "$APP" "$FINAL_APP_PATH"

# Remove quarantine
xattr -rd com.apple.quarantine "$FINAL_APP_PATH" 2>/dev/null || true

echo "Installed to: $FINAL_APP_PATH"

# --- LAUNCHER ---
LAUNCHER="$INSTALL_DIR/launch_r"
cat > "$LAUNCHER" << 'EOF'
#!/bin/bash
exec "$HOME/Applications/r.app/Contents/MacOS/r" "$@"
EOF
chmod +x "$LAUNCHER"

# --- CLEANUP ---
rm -rf /tmp/roblox.zip /tmp/RobloxExtract

# --- LAUNCH ---
echo ""
echo "=========================================="
echo "  Launching Roblox..."
echo "=========================================="

nohup "$FINAL_APP_PATH/Contents/MacOS/r" > /tmp/roblox.log 2>&1 &
disown

echo "Launched! (Logs: /tmp/roblox.log)"
echo ""
echo "=========================================="
echo "  Done!"
echo "=========================================="
echo ""
echo "Updater Patched"
sleep 5
open https://tiktok.com/@itsleonelofficial

exit 0