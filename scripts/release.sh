#!/bin/bash
set -euo pipefail

# Full local release pipeline for Cloom.
# Builds locally, creates GitHub Release, updates Homebrew tap, updates Sparkle appcast.
#
# Usage:
#   ./scripts/release.sh              # Full release (version from Info.plist)
#   ./scripts/release.sh 0.2.0        # Full release with explicit version
#   ./scripts/release.sh --build-only # Build DMG only, no publish

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
APP_NAME="Cloom"
REPO="iamsachin/cloom"
BUILD_ONLY=false

# Parse args
if [ "${1:-}" = "--build-only" ]; then
    BUILD_ONLY=true
    shift
fi

# Read version from Info.plist or use argument
if [ $# -ge 1 ]; then
    VERSION="$1"
else
    VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PROJECT_ROOT/CloomApp/Resources/Info.plist")
fi

TAG="v${VERSION}"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"

echo "==> Building Cloom v${VERSION}"
echo ""

# ── Step 1: Build Rust + UniFFI bindings ──────────────────────────────
echo "==> Step 1/6: Building Rust and generating UniFFI bindings..."
"$PROJECT_ROOT/build.sh"

# ── Step 2: Generate Xcode project ────────────────────────────────────
echo ""
echo "==> Step 2/6: Generating Xcode project..."
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
echo "==> Step 3/6: Archiving with Xcode (Release configuration)..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

ARCHIVE_PATH="$BUILD_DIR/${APP_NAME}.xcarchive"

xcodebuild archive \
    -scheme "$APP_NAME" \
    -archivePath "$ARCHIVE_PATH" \
    -destination 'generic/platform=macOS' \
    -configuration Release \
    ARCHS=arm64 \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_ALLOWED=YES \
    -quiet

# Extract .app from archive
APP_PATH="$BUILD_DIR/${APP_NAME}.app"
cp -R "$ARCHIVE_PATH/Products/Applications/${APP_NAME}.app" "$APP_PATH"

echo ""
echo "==> Step 4/6: Ad-hoc code signing..."
codesign --sign - --force --deep "$APP_PATH"
codesign --verify --verbose "$APP_PATH" 2>&1 || true

# ── Step 5: Create DMG ────────────────────────────────────────────────
echo ""
echo "==> Step 5/6: Creating DMG..."
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

if [ ! -f "$DMG_PATH" ]; then
    echo ""
    echo "Error: DMG creation failed."
    exit 1
fi

DMG_SIZE_HUMAN=$(du -h "$DMG_PATH" | cut -f1)
DMG_SIZE_BYTES=$(stat -f%z "$DMG_PATH")
SHA256=$(shasum -a 256 "$DMG_PATH" | cut -d ' ' -f 1)

echo "    DMG:      $DMG_PATH ($DMG_SIZE_HUMAN)"
echo "    SHA256:   $SHA256"

# ── Step 6: Sparkle EdDSA signing ─────────────────────────────────────
echo ""
echo "==> Step 6/6: Signing DMG with Sparkle EdDSA..."
ED_SIG=""
SIGN_TOOL=$(find ~/Library/Developer/Xcode/DerivedData -name "sign_update" -path "*/Sparkle/bin/*" 2>/dev/null | head -1 || true)
if [ -n "$SIGN_TOOL" ]; then
    ED_SIG=$("$SIGN_TOOL" "$DMG_PATH" -p 2>/dev/null || true)
fi

if [ -n "$ED_SIG" ]; then
    echo "    EdDSA:    $ED_SIG"
else
    echo "    EdDSA:    (no key in Keychain — sign_update not found or key missing)"
    echo "    Warning:  Sparkle appcast will NOT be updated without EdDSA signature."
fi

echo ""
echo "==> Build complete!"
echo "    Version:  v${VERSION}"
echo "    DMG:      $DMG_PATH ($DMG_SIZE_HUMAN)"
echo "    SHA256:   $SHA256"

if $BUILD_ONLY; then
    echo ""
    echo "==> --build-only: skipping publish steps."
    exit 0
fi

# ══════════════════════════════════════════════════════════════════════
# PUBLISH STEPS (GitHub Release, Homebrew tap, Sparkle appcast)
# ══════════════════════════════════════════════════════════════════════

echo ""
echo "==> Publishing release..."

# ── GitHub Release ────────────────────────────────────────────────────
echo ""
echo "==> Creating GitHub Release..."
CHANGELOG_NOTES=$(awk "/^## \\[${VERSION}\\]/{found=1; next} /^## \\[/{if(found) exit} found{print}" "$PROJECT_ROOT/CHANGELOG.md")
if [ -z "$CHANGELOG_NOTES" ]; then
    CHANGELOG_NOTES="No changelog entry for this version."
fi

cat > /tmp/cloom-release-body.md <<RELEASE_EOF
## What's Changed

${CHANGELOG_NOTES}

## Installation

1. Download \`Cloom-${VERSION}.dmg\` below
2. Open the DMG and drag **Cloom** to your Applications folder
3. On first launch, right-click the app and select **Open** (Gatekeeper bypass for unsigned apps)

**Homebrew:**
\`\`\`bash
brew tap iamsachin/cloom
brew install --cask cloom
\`\`\`

**SHA256:** \`${SHA256}\`

**System Requirements:** macOS 26.0 (Tahoe) or later, Apple Silicon (arm64)
RELEASE_EOF

gh release create "$TAG" \
    --repo "$REPO" \
    --title "Cloom ${TAG}" \
    --notes-file /tmp/cloom-release-body.md \
    "$DMG_PATH"

echo "    GitHub Release created: https://github.com/${REPO}/releases/tag/${TAG}"

# ── Homebrew tap ──────────────────────────────────────────────────────
echo ""
echo "==> Updating Homebrew tap..."
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${TAG}/Cloom-${VERSION}.dmg"

HOMEBREW_DIR=$(mktemp -d)
if git clone "https://github.com/iamsachin/homebrew-cloom.git" "$HOMEBREW_DIR" 2>/dev/null; then
    mkdir -p "$HOMEBREW_DIR/Casks"
    cat > "$HOMEBREW_DIR/Casks/cloom.rb" <<CASK_EOF
cask "cloom" do
  version "${VERSION}"
  sha256 "${SHA256}"

  url "${DOWNLOAD_URL}"
  name "Cloom"
  desc "Open-source screen recorder for macOS"
  homepage "https://github.com/${REPO}"

  depends_on macos: ">= :tahoe"
  depends_on arch: :arm64

  app "Cloom.app"

  zap trash: [
    "~/Library/Application Support/Cloom",
    "~/Library/Preferences/com.cloom.app.plist",
    "~/Library/Caches/com.cloom.app",
  ]
end
CASK_EOF

    cd "$HOMEBREW_DIR"
    git add Casks/cloom.rb
    if git diff --cached --quiet; then
        echo "    No changes to Homebrew cask."
    else
        git commit -m "Update cloom to ${VERSION}"
        git push origin main
        echo "    Homebrew tap updated."
    fi
    cd "$PROJECT_ROOT"
else
    echo "    Warning: Could not clone homebrew-cloom — skipping tap update."
fi
rm -rf "$HOMEBREW_DIR"

# ── Sparkle appcast ───────────────────────────────────────────────────
if [ -n "$ED_SIG" ]; then
    echo ""
    echo "==> Updating Sparkle appcast on gh-pages..."

    GHPAGES_DIR=$(mktemp -d)
    if git clone --branch gh-pages "https://github.com/${REPO}.git" "$GHPAGES_DIR" 2>/dev/null; then
        "$PROJECT_ROOT/scripts/generate-appcast.sh" "$VERSION" "$DMG_PATH" "$ED_SIG" "$DMG_SIZE_BYTES" "$GHPAGES_DIR"

        cd "$GHPAGES_DIR"
        git add appcast.xml
        if git diff --cached --quiet; then
            echo "    No appcast changes."
        else
            git commit -m "Update appcast for v${VERSION}"
            git push origin gh-pages
            echo "    Appcast updated: https://iamsachin.github.io/cloom/appcast.xml"
        fi
        cd "$PROJECT_ROOT"
    else
        echo "    Warning: Could not clone gh-pages — skipping appcast update."
    fi
    rm -rf "$GHPAGES_DIR"
else
    echo ""
    echo "==> Skipping Sparkle appcast — no EdDSA signature."
fi

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  Release v${VERSION} complete!"
echo "  GitHub:   https://github.com/${REPO}/releases/tag/${TAG}"
echo "  Appcast:  https://iamsachin.github.io/cloom/appcast.xml"
echo "  Homebrew: brew install iamsachin/cloom/cloom"
echo "══════════════════════════════════════════════════════════════"
