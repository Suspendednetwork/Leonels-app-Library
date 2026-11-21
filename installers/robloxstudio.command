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
rm -rf ~/Applications/rs.app ~/Applications/RobloxStudio.app /tmp/RobloxStudio.zip /tmp/RobloxStudioExtract

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

APP=$(find /tmp/RobloxStudioExtract -name "*.app" -maxdepth 3 | sort | head -n 1)
if [ -z "$APP" ]; then
    echo "Could not find Roblox Studio app"
    exit 1
fi

# Rename the top-level app bundle.
APP_DIR=$(dirname "$APP")
RENAMED_APP="$APP_DIR/rs.app"
if [ "$APP" != "$RENAMED_APP" ]; then
    mv "$APP" "$RENAMED_APP"
    APP="$RENAMED_APP"
fi

echo "Found and renamed app: $(basename "$APP")"

# =========================
# PATCH SECTION
# =========================

echo "Removing signature..."
codesign --remove-signature "$APP" 2>/dev/null || true

MACOS_DIR="$APP/Contents/MacOS"
PLIST="$APP/Contents/Info.plist"

# Rename nested RobloxStudio.app inside Contents/MacOS.
while IFS= read -r -d '' NESTED_APP; do
    NESTED_APP_DIR=$(dirname "$NESTED_APP")
    if [ "$(basename "$NESTED_APP")" = "RobloxStudio.app" ]; then
        mv "$NESTED_APP" "$NESTED_APP_DIR/rs.app"
        echo "Renamed nested app: RobloxStudio.app -> rs.app"

        NESTED_PLIST="$NESTED_APP_DIR/rs.app/Contents/Info.plist"
        if [ -f "$NESTED_PLIST" ]; then
            defaults write "$NESTED_PLIST" CFBundleName -string "rs"
            defaults write "$NESTED_PLIST" CFBundleDisplayName -string "rs"

            NESTED_MACOS="$NESTED_APP_DIR/rs.app/Contents/MacOS"
            if [ -f "$NESTED_MACOS/RobloxStudio" ]; then
                mv "$NESTED_MACOS/RobloxStudio" "$NESTED_MACOS/rs"
                defaults write "$NESTED_PLIST" CFBundleExecutable -string "rs"
            fi
        fi
    fi
done < <(find "$APP" -name "*.app" -print0)

# Rename main binary.
if [ -f "$MACOS_DIR/RobloxStudio" ]; then
    mv "$MACOS_DIR/RobloxStudio" "$MACOS_DIR/rs"
    echo "Renamed: RobloxStudio -> rs"
else
    echo "ERROR: Could not find RobloxStudio executable"
    exit 1
fi

# Generate random bundle ID: leo.******.***
RANDOM_PART1=$(head /dev/urandom | LC_ALL=C tr -dc 'a-z0-9' | head -c 6)
RANDOM_PART2=$(head /dev/urandom | LC_ALL=C tr -dc 'a-z0-9' | head -c 3)
BUNDLE_ID="leo.${RANDOM_PART1}.${RANDOM_PART2}"

echo "Generated Bundle ID: $BUNDLE_ID"

# Edit plist - main executable and app name are 'rs', with a random bundle ID
defaults write "$PLIST" CFBundleExecutable -string "rs"
defaults write "$PLIST" CFBundleName -string "rs"
defaults write "$PLIST" CFBundleDisplayName -string "rs"
defaults write "$PLIST" CFBundleIdentifier -string "$BUNDLE_ID"

chmod +x "$MACOS_DIR/rs"

# Re-sign with ad-hoc signature
echo "Re-signing app..."
codesign --force --deep --sign - "$APP"

# --- INSTALL ---
INSTALL_DIR="$HOME/Applications"
mkdir -p "$INSTALL_DIR"

FINAL_APP_PATH="$INSTALL_DIR/rs.app"
rm -rf "$FINAL_APP_PATH"
mv "$APP" "$FINAL_APP_PATH"

# Remove quarantine
xattr -rd com.apple.quarantine "$FINAL_APP_PATH" 2>/dev/null || true

echo "Installed to: $FINAL_APP_PATH"

# --- LAUNCHERS ---
LAUNCHER="$INSTALL_DIR/launch_rs"
rm -f "$INSTALL_DIR/r" "$INSTALL_DIR/launch_r" "$INSTALL_DIR/launch_RobloxStudio"
printf '#!/bin/bash\nexec "$HOME/Applications/rs.app/Contents/MacOS/rs" "$@"\n' > "$LAUNCHER"
chmod +x "$LAUNCHER"

# Updater in the same folder as rs.app
STUDIO_UPDATER="$INSTALL_DIR/RS updater.command"
printf '#!/bin/bash\ncurl -fsSL https://apps.suspendednetwork.tech/installers/robloxstudio.command | bash\n' > "$STUDIO_UPDATER"
chmod +x "$STUDIO_UPDATER"

echo "Created updater command file: $STUDIO_UPDATER"

# --- CLEANUP ---
rm -rf /tmp/RobloxStudio.zip /tmp/RobloxStudioExtract

# --- LAUNCH ---
echo ""
echo "=========================================="
echo "  Launching Roblox Studio..."
echo "=========================================="

nohup "$FINAL_APP_PATH/Contents/MacOS/rs" > /tmp/rs.log 2>&1 &
disown

echo "Launched! (Logs: /tmp/rs.log)"
echo ""
echo "=========================================="
echo "  Done!"
echo "=========================================="
echo ""
echo "Updater Patched"
sleep 5
open "https://tiktok.com/@itsleonelofficial"

exit 0
