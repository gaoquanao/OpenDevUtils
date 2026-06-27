#!/bin/bash
set -e

APP_NAME="OpenDevUtils"
BUILD_DIR=".build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

echo "Building $APP_NAME..."

# Clean
rm -rf "$APP_BUNDLE"

# Build universal binary (arm64 + x86_64)
swift build -c release --arch arm64 --arch x86_64 2>&1

# Create .app bundle structure
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy universal binary
cp "$BUILD_DIR/apple/Products/Release/$APP_NAME" "$MACOS_DIR/$APP_NAME"

# Verify universal binary
file "$MACOS_DIR/$APP_NAME"

# Copy icon directly
ICNS_SRC="devUtils/Assets.xcassets/icon_full.icns"
if [ -f "$ICNS_SRC" ]; then
    cp "$ICNS_SRC" "$RESOURCES_DIR/AppIcon.icns"
    echo "  App icon: icon_full.icns → AppIcon.icns"
else
    echo "  Warning: icon_full.icns not found"
fi

# Create Info.plist
cat > "$CONTENTS/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleExecutable</key>
    <string>OpenDevUtils</string>
    <key>CFBundleIdentifier</key>
    <string>com.xiaomi.opendevutils</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>OpenDevUtils</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.developer-tools</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon.icns</string>
</dict>
</plist>
EOF

echo "Done! App bundle created at: $APP_BUNDLE"
