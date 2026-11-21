#!/bin/bash
set -e

echo "=========================================="
echo "  Roblox Studio Mac Installer"
echo "=========================================="

if [ "$(uname -s)" != "Darwin" ]; then
    echo "ERROR: Roblox Studio installer for macOS must run on a Mac."
    exit 1
fi

echo "Fetching Roblox Studio version..."

# --- GET VERSION HASH ---
ROBLOX_VERSION=$(
    curl -fsSL "https://clientsettings.roblox.com/v2/client-version/MacStudio" \
    | grep -o '"clientVersionUpload":"[^"]*"' | cut -d'"' -f4
)

if [ -z "$ROBLOX_VERSION" ]; then
    echo "Failed to fetch Roblox Studio version"
    exit 1
fi

echo "Detected version: $ROBLOX_VERSION"

# --- CLEAN ---
rm -rf ~/Applications/r.app ~/Applications/RobloxStudio.app /tmp/RobloxStudio.zip /tmp/RobloxStudioExtract

# --- ARCH DETECTION ---
ARCH="mac/arm64"
if [ "$(uname -m)" = "x86_64" ]; then
    ARCH="mac"
fi

# --- BUILD DOWNLOAD URL ---
DOWNLOAD_URL="https://setup.rbxcdn.com/${ARCH}/${ROBLOX_VERSION}-RobloxStudioApp.zip"

echo "Downloading from: $DOWNLOAD_URL"

curl -L --fail --show-error --progress-bar "$DOWNLOAD_URL" -o /tmp/RobloxStudio.zip

# --- VALIDATE ZIP ---
FILE_TYPE=$(file /tmp/RobloxStudio.zip)
if ! echo "$FILE_TYPE" | grep -q "Zip archive data"; then
    echo "ERROR: Download is not a valid ZIP"
    exit 1
fi

# --- EXTRACT ---
mkdir -p /tmp/RobloxStudioExtract
ditto -x -k /tmp/RobloxStudio.zip /tmp/RobloxStudioExtract

APP=$(find /tmp/RobloxStudioExtract -name "*.app" | head -n 1)
if [ -z "$APP" ]; then
    echo "Could not find Roblox Studio app"
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
if [ -f "$MACOS_DIR/RobloxStudio" ]; then
    mv "$MACOS_DIR/RobloxStudio" "$MACOS_DIR/r"
    echo "Renamed: RobloxStudio -> r"
else
    echo "ERROR: Could not find RobloxStudio executable"
    exit 1
fi

# Generate random bundle ID: leo.******.***
RANDOM_PART1=$(head /dev/urandom | LC_ALL=C tr -dc 'a-z0-9' | head -c 6)
RANDOM_PART2=$(head /dev/urandom | LC_ALL=C tr -dc 'a-z0-9' | head -c 3)
BUNDLE_ID="leo.${RANDOM_PART1}.${RANDOM_PART2}"

echo "Generated Bundle ID: $BUNDLE_ID"

# Edit plist - main executable and app name are 'r', with a random bundle ID
defaults write "$PLIST" CFBundleExecutable -string "r"
defaults write "$PLIST" CFBundleName -string "r"
defaults write "$PLIST" CFBundleDisplayName -string "r"
defaults write "$PLIST" CFBundleIdentifier -string "$BUNDLE_ID"

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

# --- LAUNCHERS ---
LAUNCHER="$INSTALL_DIR/launch_r"
rm -f "$INSTALL_DIR/rs" "$INSTALL_DIR/launch_RobloxStudio"
cat > "$LAUNCHER" << 'EOF'
#!/bin/bash
exec "$HOME/Applications/r.app/Contents/MacOS/r" "$@"
EOF
chmod +x "$LAUNCHER"

# Updater in the same folder as r.app
STUDIO_UPDATER="$INSTALL_DIR/RStudio updater.command"
cat > "$STUDIO_UPDATER" <<
