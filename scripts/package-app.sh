#!/usr/bin/env bash
# Package the SPM-built binary into a standalone .app bundle
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
BINARY_PATH="$BUILD_DIR/release/ClaudeNotifier"
APP_NAME="ClaudeNotifier"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

echo "📦 Packaging $APP_NAME.app..."

# Clean previous
rm -rf "$APP_BUNDLE"

# Create bundle structure
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Copy binary
cp "$BINARY_PATH" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

# Copy Info.plist
cp "$PROJECT_DIR/Sources/ClaudeNotifier/App/Info.plist" "$CONTENTS/Info.plist"

# Copy icons
mkdir -p "$RESOURCES_DIR"
cp -R "$PROJECT_DIR/Resources/Assets.xcassets/AppIcon.appiconset" "$RESOURCES_DIR/AppIcon.appiconset" 2>/dev/null || true

# Create an icon from our PNGs using iconutil
ICONSET_DIR="$RESOURCES_DIR/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"

# Copy and rename PNG files to iconset naming convention
declare -A MAPPING=(
    ["icon_16.png"]="icon_16x16.png"
    ["icon_32.png"]="icon_16x16@2x.png"
    ["icon_64.png"]="icon_32x32@2x.png"
    ["icon_128.png"]="icon_128x128.png"
    ["icon_256.png"]="icon_128x128@2x.png"
    ["icon_512.png"]="icon_256x256@2x.png"
)

for src in "${!MAPPING[@]}"; do
    dst="${MAPPING[$src]}"
    src_path="$PROJECT_DIR/Resources/Assets.xcassets/AppIcon.appiconset/$src"
    if [ -f "$src_path" ]; then
        cp "$src_path" "$ICONSET_DIR/$dst"
    fi
done

# Generate .icns from iconset
if command -v iconutil >/dev/null 2>&1; then
    iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns" 2>/dev/null || true
fi
rm -rf "$ICONSET_DIR"

# Copy the generated icns to where Info.plist expects it
if [ -f "$RESOURCES_DIR/AppIcon.icns" ]; then
    echo "  ✅ AppIcon.icns created"
fi

echo ""
echo "✅ App bundle created at: $APP_BUNDLE"
echo ""
echo "   You can now run: open $APP_BUNDLE"
echo "   Or install: cp -R $APP_BUNDLE /Applications/"
