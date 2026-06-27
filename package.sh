#!/bin/bash
set -e

APP_NAME="OpenDevUtils"
BUILD_DIR=".build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
RESOURCES_DIR="$CONTENTS/Resources"
DMG_NAME="$BUILD_DIR/$APP_NAME.dmg"
DMG_TEMP="$BUILD_DIR/dmg-temp"
VERSION="1.0.0"

echo "========================================="
echo "  Packaging $APP_NAME v$VERSION"
echo "========================================="

# Step 1: Build
echo ""
echo "[1/4] Building release binary..."
./build.sh

# Step 2: Verify icon in .app bundle
echo ""
echo "[2/4] Verifying app icon..."
if [ -f "$RESOURCES_DIR/AppIcon.icns" ]; then
    echo "  AppIcon.icns verified ($(du -h "$RESOURCES_DIR/AppIcon.icns" | cut -f1))"
else
    echo "  Warning: AppIcon.icns not found"
fi

# Step 3: Create DMG with Applications shortcut
echo ""
echo "[3/4] Creating DMG..."

# Clean old DMG
rm -f "$DMG_NAME"
rm -rf "$DMG_TEMP"

# Create temp directory with app and symlink
mkdir -p "$DMG_TEMP"
cp -R "$APP_BUNDLE" "$DMG_TEMP/"
ln -s /Applications "$DMG_TEMP/Applications"

# Calculate DMG size (app size + 20MB buffer)
APP_SIZE=$(du -sm "$DMG_TEMP" | cut -f1)
DMG_SIZE=$((APP_SIZE + 20))

# Create DMG
echo "  Creating disk image (${DMG_SIZE}MB)..."
hdiutil create \
    -srcfolder "$DMG_TEMP" \
    -volname "$APP_NAME" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDBZ \
    -size "${DMG_SIZE}m" \
    "$DMG_NAME" \
    -quiet

# Step 4: Configure DMG window layout
echo ""
echo "[4/4] Configuring DMG window..."

# Mount the DMG
MOUNT_DIR="/Volumes/$APP_NAME"
hdiutil attach "$DMG_NAME" -readwrite -noverify -quiet

# Set Finder window properties via AppleScript
osascript << EOF
tell application "Finder"
    tell disk "$APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 640, 400}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 96
        set position of item "$APP_NAME.app" of container window to {140, 170}
        set position of item "Applications" of container window to {400, 170}
        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
EOF

# Unmount
hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null || true

# Clean temp
rm -rf "$DMG_TEMP"

# Verify DMG
if [ -f "$DMG_NAME" ]; then
    DMG_FILE_SIZE=$(du -h "$DMG_NAME" | cut -f1)
    echo ""
    echo "========================================="
    echo "  DMG Created Successfully!"
    echo "========================================="
    echo "  File: $(pwd)/$DMG_NAME"
    echo "  Size: $DMG_FILE_SIZE"
    echo "  Version: $VERSION"
    echo ""
    echo "  To install:"
    echo "  1. Open $DMG_NAME"
    echo "  2. Drag $APP_NAME to Applications"
    echo "========================================="
else
    echo "  DMG creation failed!"
    exit 1
fi
