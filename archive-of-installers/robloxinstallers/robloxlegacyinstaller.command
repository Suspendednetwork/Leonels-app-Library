#!/bin/bash
set -e

echo "Fetching Roblox MacPlayer version..."

# --- GET VERSION HASH ---
ROBLOX_VERSION=$(
curl -fsSL "https://clientsettings.roblox.com/v2/client-version/MacPlayer/channel/LIVE" \
| python3 -c "import sys, json; print(json.load(sys.stdin)['clientVersionUpload'])"
)

if [ -z "$ROBLOX_VERSION" ]; then
    echo "Failed to fetch Roblox version"
    exit 1
fi

echo "Detected version: $ROBLOX_VERSION"

# --- CLEAN ---
rm -rf Roblox.app RobloxExtract /tmp/roblox.zip

# --- ARCH DETECTION ---
ARCH="arm64"
if [ "$(uname -m)" = "x86_64" ]; then
    ARCH="x86-64"
fi

# --- BUILD DOWNLOAD URL ---
DOWNLOAD_URL="https://setup-aws.rbxcdn.com/mac/${ARCH}/${ROBLOX_VERSION}-RobloxPlayer.zip"

echo "Downloading from:"
echo "$DOWNLOAD_URL"

curl -L --fail --show-error "$DOWNLOAD_URL" -o /tmp/roblox.zip

# --- VALIDATE ZIP ---
FILE_TYPE=$(file /tmp/roblox.zip)

if ! echo "$FILE_TYPE" | grep -q "Zip archive data"; then
    echo "ERROR: Download is not a valid ZIP (got HTML instead)"
    exit 1
fi

# --- EXTRACT ---
rm -rf RobloxExtract
mkdir -p RobloxExtract
unzip -q /tmp/roblox.zip -d RobloxExtract

APP=$(find RobloxExtract -name "*.app" | head -n 1)

if [ -z "$APP" ]; then
    echo "Could not find Roblox app"
    exit 1
fi

echo "Found app: $APP"

# =========================
# PATCH SECTION
# =========================

echo "Removing signature..."
codesign --remove-signature "$APP" 2>/dev/null || true

MACOS_DIR="$APP/Contents/MacOS"
PLIST="$APP/Contents/Info.plist"

echo "Renaming binaries..."

if [ -f "$MACOS_DIR/RobloxPlayer" ]; then
    mv "$MACOS_DIR/RobloxPlayer" "$MACOS_DIR/r"
fi

if [ -f "$MACOS_DIR/RobloxPlayerInstaller" ]; then
    mv "$MACOS_DIR/RobloxPlayerInstaller" "$MACOS_DIR/ro"
fi

echo "Editing Info.plist..."

# CFBundleExecutable -> r
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable r" "$PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string r" "$PLIST"

# CFBundleIdentifier -> leo.nel.com
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier leo.nel.com" "$PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string leo.nel.com" "$PLIST"

echo "Re-signing (ad-hoc)..."
codesign --force --deep --sign - "$APP"

echo "Verifying signature..."
codesign --verify --deep --strict "$APP" || true

# --- INSTALL ---
INSTALL_DIR="$HOME/Applications"
mkdir -p "$INSTALL_DIR"

APP_NAME="r.app"
FINAL_APP_PATH="$INSTALL_DIR/$APP_NAME"

rm -rf "$FINAL_APP_PATH"
mv "$APP" "$FINAL_APP_PATH"

echo "Installed successfully to $FINAL_APP_PATH"

# =========================
# LAUNCHER CREATION
# =========================

echo "Creating launch_r shortcut..."

LAUNCHER="$INSTALL_DIR/launch_r"

cat > "$LAUNCHER" <<EOF
#!/bin/bash
exec "$FINAL_APP_PATH/Contents/MacOS/r" "\$@"
EOF

chmod +x "$LAUNCHER"

echo "Launcher created at: $LAUNCHER"
