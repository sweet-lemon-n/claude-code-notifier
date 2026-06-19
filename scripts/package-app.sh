#!/usr/bin/env bash
# Package the SPM-built binary into a standalone .app bundle
# Compatible with bash 3.2 (macOS default)
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

# Check binary exists
if [ ! -f "$BINARY_PATH" ]; then
    echo "❌ Binary not found: $BINARY_PATH"
    echo "   Run: swift build -c release"
    exit 1
fi

# Clean previous
rm -rf "$APP_BUNDLE"

# Create bundle structure
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Copy binary
cp "$BINARY_PATH" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

# Copy Info.plist
cp "$PROJECT_DIR/Sources/ClaudeNotifier/App/Info.plist" "$CONTENTS/Info.plist"

# Copy notification artwork
if [ -d "$PROJECT_DIR/Resources/NotificationIcons" ]; then
    cp "$PROJECT_DIR/Resources/NotificationIcons/"*.png "$RESOURCES_DIR/" 2>/dev/null || true
fi

# Build .icns from our PNGs using iconutil
ICONSET_DIR="$RESOURCES_DIR/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"

ICON_SRC="$PROJECT_DIR/Resources/Assets.xcassets/AppIcon.appiconset"

# Map pixel sizes to iconset names
# icon_16.png  → icon_16x16.png
# icon_32.png  → icon_16x16@2x.png
# icon_64.png  → icon_32x32@2x.png
# icon_128.png → icon_128x128.png
# icon_256.png → icon_128x128@2x.png (use for 256)
# icon_512.png → icon_256x256@2x.png (use for 512)

copy_icon() {
    src="$ICON_SRC/$1"
    dst="$ICONSET_DIR/$2"
    if [ -f "$src" ]; then
        cp "$src" "$dst"
    fi
}

copy_icon "icon_16.png"  "icon_16x16.png"
copy_icon "icon_32.png"  "icon_16x16@2x.png"
copy_icon "icon_32.png"  "icon_32x32.png"
copy_icon "icon_64.png"  "icon_32x32@2x.png"
copy_icon "icon_128.png" "icon_128x128.png"
copy_icon "icon_256.png" "icon_128x128@2x.png"
copy_icon "icon_256.png" "icon_256x256.png"
copy_icon "icon_512.png" "icon_256x256@2x.png"
copy_icon "icon_512.png" "icon_512x512.png"
copy_icon "icon_512.png" "icon_512x512@2x.png"

# Generate .icns from iconset
if command -v iconutil >/dev/null 2>&1; then
    iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns" 2>/dev/null && \
        echo "  ✅ AppIcon.icns created" || echo "  ⚠️  iconutil failed (non-fatal)"
fi
rm -rf "$ICONSET_DIR"

# Ad-hoc code sign — required for UNUserNotificationCenter to deliver
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null && \
    echo "  ✅ Codesigned" || echo "  ⚠️  Codesign failed (non-fatal)"

echo ""
echo "✅ App bundle: $APP_BUNDLE"
echo "   Binary: $MACOS_DIR/$APP_NAME"
