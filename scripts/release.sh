#!/bin/bash
set -euo pipefail

# Release build script for Cloom
# Builds Rust + Swift, ad-hoc signs, and packages into a DMG.
#
# Usage:
#   ./scripts/release.sh          # Build DMG (version from Info.plist)
#   ./scripts/release.sh 0.2.0    # Build DMG with explicit version

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
APP_NAME="Cloom"

# Read version from Info.plist or use argument
if [ $# -ge 1 ]; then
    VERSION="$1"
else
    VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PROJECT_ROOT/CloomApp/Resources/Info.plist")
fi

DMG_NAME="${APP_NAME}-${VERSION}.dmg"

echo "==> Building Cloom v${VERSION}"
echo ""

# ── Step 1: Build Rust + UniFFI bindings ──────────────────────────────
echo "==> Step 1/5: Building Rust and generating UniFFI bindings..."
"$PROJECT_ROOT/build.sh"

# ── Step 2: Generate Xcode project ────────────────────────────────────
echo ""
echo "==> Step 2/5: Generating Xcode project..."
if ! command -v xcodegen &>/dev/null; then
    echo "Error: xcodegen is not installed. Install with: brew install xcodegen"
    exit 1
fi
cd "$PROJECT_ROOT"
xcodegen generate --quiet

# ── Step 3: Ensure Secrets.xcconfig exists ────────────────────────────
XCCONFIG="$PROJECT_ROOT/CloomApp/Resources/Secrets.xcconfig"
if [ ! -f "$XCCONFIG" ]; then
    echo "Warning: Secrets.xcconfig not found — creating stub for build."
    cp "$PROJECT_ROOT/CloomApp/Resources/Secrets.xcconfig.example" "$XCCONFIG"
fi

# ── Step 4: Archive + ad-hoc sign ─────────────────────────────────────
echo ""
echo "==> Step 3/5: Archiving with Xcode (Release configuration)..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

ARCHIVE_PATH="$BUILD_DIR/${APP_NAME}.xcarchive"

xcodebuild archive \
    -scheme "$APP_NAME" \
    -archivePath "$ARCHIVE_PATH" \
    -destination 'generic/platform=macOS' \
    -configuration Release \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_ALLOWED=YES \
    -quiet

# Extract .app from archive
APP_PATH="$BUILD_DIR/${APP_NAME}.app"
cp -R "$ARCHIVE_PATH/Products/Applications/${APP_NAME}.app" "$APP_PATH"

echo ""
echo "==> Step 4/5: Ad-hoc code signing..."
codesign --sign - --force --deep "$APP_PATH"

# Verify signature
codesign --verify --verbose "$APP_PATH" 2>&1 || true

# ── Step 5: Create DMG ────────────────────────────────────────────────
echo ""
echo "==> Step 5/5: Creating DMG..."
if ! command -v create-dmg &>/dev/null; then
    echo "Error: create-dmg is not installed. Install with: brew install create-dmg"
    exit 1
fi

DMG_PATH="$BUILD_DIR/$DMG_NAME"

# create-dmg returns exit code 2 if it can't set a custom icon (non-fatal)
create-dmg \
    --volname "$APP_NAME" \
    --volicon "$PROJECT_ROOT/CloomApp/Resources/Assets.xcassets/AppIcon.appiconset/icon_512x512@1x.png" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "${APP_NAME}.app" 175 190 \
    --app-drop-link 425 190 \
    --hide-extension "${APP_NAME}.app" \
    "$DMG_PATH" \
    "$APP_PATH" || true

if [ -f "$DMG_PATH" ]; then
    DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
    echo ""
    echo "==> Release build complete!"
    echo "    Version:  v${VERSION}"
    echo "    DMG:      $DMG_PATH ($DMG_SIZE)"
    echo "    Signing:  ad-hoc (users right-click → Open on first launch)"
else
    echo ""
    echo "Error: DMG creation failed."
    exit 1
fi
