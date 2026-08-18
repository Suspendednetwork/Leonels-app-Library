#!/bin/bash

set -e

echo "=== PlayCover Installer ==="

# --- 1️⃣ Ensure ~/bin exists ---
BIN_DIR="$HOME/bin"
mkdir -p "$BIN_DIR"

# --- 2️⃣ Detect shell and add ~/bin to PATH ---
if [ -n "$ZSH_VERSION" ]; then
    SHELL_RC="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ]; then
    SHELL_RC="$HOME/.bash_profile"
else
    SHELL_RC="$HOME/.profile"
fi

touch "$SHELL_RC"

if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$SHELL_RC"; then
    echo 'export PATH="$HOME/bin:$PATH"' >> "$SHELL_RC"
    echo "Added $BIN_DIR to PATH in $SHELL_RC"
fi

export PATH="$HOME/bin:$PATH"

# --- 3️⃣ Download Injure.app ---
APP_URL="https://github.com/Suspendednetwork/PlayCover/releases/download/injure/injure.zip"
APP_TMP="$(mktemp -d)"

echo "Downloading Injure..."
curl -fsSL "$APP_URL" -o "$APP_TMP/injure.zip"

echo "Unzipping Injure..."
unzip -q "$APP_TMP/injure.zip" -d "$APP_TMP"

mkdir -p "$HOME/Applications"
if [ -d "$HOME/Applications/injure.app" ]; then
    echo "Injure.app already exists, replacing..."
    rm -rf "$HOME/Applications/injure.app"
fi

mv "$APP_TMP/injure.app" "$HOME/Applications/"

echo "Installation complete!"
echo "Restart your terminal or run 'source $SHELL_RC'"
