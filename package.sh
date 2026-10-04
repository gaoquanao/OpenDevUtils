#!/bin/bash
set -e

APP_NAME="OpenDevUtils"
BUILD_DIR=".build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
RESOURCES_DIR="$CONTENTS/Resources"
DMG_NAME="$BUILD_DIR/$APP_NAME.dmg"
DMG_RW="$BUILD_DIR/$APP_NAME-rw.dmg"
DMG_TEMP="$BUILD_DIR/dmg-temp"
DMG_BACKGROUND="packaging/dmg-background.png"
VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "1.0.0")

# Finder window bounds (includes ~28px title bar) => content area 660x400,
# which must match the background PNG size.
WINDOW_WIDTH=660
WINDOW_HEIGHT=428
ICON_POS_X=170
ICON_POS_Y=180
LINK_POS_X=490
LINK_POS_Y=180

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

# Step 3: Create DMG with background image and Applications shortcut
echo ""
echo "[3/4] Creating DMG..."

# Clean old DMG
rm -f "$DMG_NAME"
rm -rf "$DMG_TEMP"
rm -f "$DMG_RW"

# Create temp directory with app (create-dmg adds the Applications link itself)
mkdir -p "$DMG_TEMP"
cp -R "$APP_BUNDLE" "$DMG_TEMP/"

USE_CREATE_DMG=0
if [ -z "$CI" ] && command -v create-dmg >/dev/null 2>&1 && [ -f "$DMG_BACKGROUND" ]; then
    USE_CREATE_DMG=1
fi

if [ "$USE_CREATE_DMG" = "1" ]; then
    echo "  Using create-dmg (background image + icon positions)..."
    if ! create-dmg \
        --volname "$APP_NAME" \
        --background "$DMG_BACKGROUND" \
        --window-pos 100 100 \
        --window-size "$WINDOW_WIDTH" "$WINDOW_HEIGHT" \
        --icon-size 128 \
        --text-size 14 \
        --icon "$APP_NAME.app" "$ICON_POS_X" "$ICON_POS_Y" \
        --app-drop-link "$LINK_POS_X" "$LINK_POS_Y" \
        --format UDBZ \
        "$DMG_NAME" "$DMG_TEMP"; then
        echo "  Warning: create-dmg failed, falling back to plain DMG"
        USE_CREATE_DMG=0
        rm -f "$DMG_NAME"
    fi
fi

if [ "$USE_CREATE_DMG" = "0" ]; then
    # Manual flow: no background image, plain layout
    ln -s /Applications "$DMG_TEMP/Applications"

    # Calculate DMG size (app size + 20MB buffer)
    APP_SIZE=$(du -sm "$DMG_TEMP" | cut -f1)
    DMG_SIZE=$((APP_SIZE + 20))

    # Create a read-write image first: compressed formats (UDBZ/UDZO) are
    # read-only, so the Finder layout cannot be applied to them directly.
    echo "  Creating disk image (${DMG_SIZE}MB)..."
    hdiutil create \
        -srcfolder "$DMG_TEMP" \
        -volname "$APP_NAME" \
        -fs HFS+ \
        -fsargs "-c c=64,a=16,e=16" \
        -format UDRW \
        -size "${DMG_SIZE}m" \
        "$DMG_RW" \
        -quiet

    # Configure DMG window layout
    echo "  Configuring DMG window..."
    if [ -n "$CI" ]; then
        echo "  CI detected, skipping Finder window configuration"
    else
        MOUNT_DIR="/Volumes/$APP_NAME"
        if hdiutil attach "$DMG_RW" -readwrite -noverify -quiet; then
            osascript << EOF || echo "  Warning: Finder configuration skipped"
tell application "Finder"
    tell disk "$APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 740, 528}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 96
        set position of item "$APP_NAME.app" of container window to {$ICON_POS_X, $ICON_POS_Y}
        set position of item "Applications" of container window to {$LINK_POS_X, $LINK_POS_Y}
        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
EOF
            hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null || true
        else
            echo "  Warning: could not mount image for layout configuration"
        fi
    fi
    rm -rf "$DMG_TEMP"

    # Compress the configured image into the final DMG
    echo "  Compressing image..."
    hdiutil convert "$DMG_RW" -format UDBZ -o "$DMG_NAME" -quiet
    rm -f "$DMG_RW"
fi
rm -rf "$DMG_TEMP"

# Step 4: Verify DMG
echo ""
echo "[4/4] Verifying DMG..."
if [ -f "$DMG_NAME" ]; then
    DMG_FILE_SIZE=$(du -h "$DMG_NAME" | cut -f1)
    echo ""
    echo "========================================="
    echo "  DMG Created Successfully!"
    echo "========================================="
    echo "  File: $(pwd)/$DMG_NAME"
    echo "  Size: $DMG_FILE_SIZE"
    echo "  Version: $VERSION"
    if [ "$USE_CREATE_DMG" = "1" ]; then
        echo "  Layout: background image + positioned icons"
    else
        echo "  Layout: plain (create-dmg not used)"
    fi
    echo ""
    echo "  To install:"
    echo "  1. Open $DMG_NAME"
    echo "  2. Drag $APP_NAME to Applications"
    echo "========================================="
else
    echo "  DMG creation failed!"
    exit 1
fi
