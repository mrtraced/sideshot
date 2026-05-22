#!/bin/bash
set -e

APP_NAME="SideSync"
BUNDLE_ID="com.sidesync.app"
BUILD_DIR=$(swift build --product SideSyncApp -c release --show-bin-path 2>/dev/null || echo ".build/arm64-apple-macosx/release")
APP_DIR="$APP_NAME.app"

echo "Building release binary..."
swift build --product SideSyncApp -c release

echo "Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy binary
cp "$BUILD_DIR/SideSyncApp" "$APP_DIR/Contents/MacOS/$APP_NAME"

# Create Info.plist
cat > "$APP_DIR/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>SideSync</string>
    <key>CFBundleDisplayName</key>
    <string>SideSync</string>
    <key>CFBundleIdentifier</key>
    <string>com.sidesync.app</string>
    <key>CFBundleVersion</key>
    <string>0.1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleExecutable</key>
    <string>SideSync</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <true/>
</dict>
</plist>
PLIST

# Copy icon
if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"
    echo "Icon included."
elif [ -f "icon-raw.png" ]; then
    echo "Generating icon from icon-raw.png..."
    mkdir -p /tmp/AppIcon.iconset
    sips -z 16 16 icon-raw.png --out /tmp/AppIcon.iconset/icon_16x16.png >/dev/null
    sips -z 32 32 icon-raw.png --out /tmp/AppIcon.iconset/icon_16x16@2x.png >/dev/null
    sips -z 32 32 icon-raw.png --out /tmp/AppIcon.iconset/icon_32x32.png >/dev/null
    sips -z 64 64 icon-raw.png --out /tmp/AppIcon.iconset/icon_32x32@2x.png >/dev/null
    sips -z 128 128 icon-raw.png --out /tmp/AppIcon.iconset/icon_128x128.png >/dev/null
    sips -z 256 256 icon-raw.png --out /tmp/AppIcon.iconset/icon_128x128@2x.png >/dev/null
    sips -z 256 256 icon-raw.png --out /tmp/AppIcon.iconset/icon_256x256.png >/dev/null
    sips -z 512 512 icon-raw.png --out /tmp/AppIcon.iconset/icon_256x256@2x.png >/dev/null
    sips -z 512 512 icon-raw.png --out /tmp/AppIcon.iconset/icon_512x512.png >/dev/null
    cp icon-raw.png /tmp/AppIcon.iconset/icon_512x512@2x.png
    iconutil -c icns /tmp/AppIcon.iconset -o "$APP_DIR/Contents/Resources/AppIcon.icns"
    rm -rf /tmp/AppIcon.iconset
    echo "Icon generated and included."
fi

# Create PkgInfo
echo -n "APPL????" > "$APP_DIR/Contents/PkgInfo"

echo ""
echo "Done! Created $APP_DIR"
echo ""
echo "To install:"
echo "  cp -r $APP_DIR /Applications/"
echo ""
echo "Or just double-click $APP_DIR in Finder."
