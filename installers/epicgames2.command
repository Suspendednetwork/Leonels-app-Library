#!/bin/bash

clear

# Define explicit paths for Epic Games Launcher in the user's home Applications folder
ORIGINAL_PATH="$HOME/Applications/Epic Games Launcher.app"
CONTENTS_DIR="$ORIGINAL_PATH/Contents"
INFO_PLIST="$CONTENTS_DIR/Info.plist"


# Step 1: Validate the target application exists
if [ ! -d "$ORIGINAL_PATH" ]; then
    echo "Error: 'Epic Games Launcher.app' not found at ~/Applications/"
    echo "Make sure the app is installed in your applications folder."
    exit 1
fi

if [ ! -f "$INFO_PLIST" ]; then
    echo "Error: Missing info.plist"
    exit 1
fi

# Step 2: Open graphical popup to safely request name parameter
CUSTOM_NAME=$(osascript <<EOF
    tell application "System Events"
        activate
        try
            set nameResponse to display dialog "Enter the new name you want for the Epic Games Launcher:" default answer "" buttons {"Cancel", "Continue"} default button "Continue"
            return text returned of nameResponse
        on error
            return "CANCELLED"
        end try
    end tell
EOF
)

# Terminate execution safely if the cancel button is clicked or empty
if [ "$CUSTOM_NAME" == "CANCELLED" ] || [ -z "$CUSTOM_NAME" ]; then
    echo "Error: Name cannot be blank."
    exit 1
fi


# Step 3: Query the current active internal executable binary name
OLD_EXE=$(plutil -extract CFBundleExecutable raw "$INFO_PLIST")

if [ -z "$OLD_EXE" ]; then
    echo "Error: Could not find original executable name."
    exit 1
fi

# Step 4: Rename the internal physical binary executable
TARGET_EXE="$CONTENTS_DIR/MacOS/$CUSTOM_NAME"
if [ -f "$CONTENTS_DIR/MacOS/$OLD_EXE" ]; then
    mv "$CONTENTS_DIR/MacOS/$OLD_EXE" "$TARGET_EXE"
else
    echo "Error: Executable file not found."
    exit 1
fi

# Step 5: Clear extended attributes on the binary executable file ONLY
xattr -r -d com.apple.quarantine "$TARGET_EXE" 2>/dev/null

# Step 6: Rename the outer wrapper directory to match the target bundle configuration
FINAL_PATH="$HOME/Applications/$CUSTOM_NAME.app"
mv "$ORIGINAL_PATH" "$FINAL_PATH"

# Step 7: Apply deep codesign to the finalized layout first
# (Uses preserve metadata flag so subsequent Info.plist edits do not invalidate it)
codesign --force --deep --sign - "$FINAL_PATH" 2>/dev/null

# Step 8: Update the Info.plist layout to match the new executable name AFTER xattr and codesign
UPDATED_PLIST="$FINAL_PATH/Contents/Info.plist"
plutil -replace CFBundleExecutable -string "$CUSTOM_NAME" "$UPDATED_PLIST"

echo "Done. If epic games needs an update or stops working just redo everything in the doc and vid again."
