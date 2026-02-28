#!/bin/bash
set -euo pipefail

# Ensure cargo is on PATH when launched from Xcode (which has a minimal shell env)
if [ -f "$HOME/.cargo/env" ]; then
    source "$HOME/.cargo/env"
fi

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
RUST_DIR="$PROJECT_ROOT/cloom-core"
SWIFT_BRIDGE_DIR="$PROJECT_ROOT/CloomApp/Sources/Bridge/Generated"
TARGET="aarch64-apple-darwin"

# Derive GOOGLE_REVERSED_CLIENT_ID from GOOGLE_CLIENT_ID in Secrets.xcconfig
XCCONFIG="$PROJECT_ROOT/CloomApp/Resources/Secrets.xcconfig"
if [ -f "$XCCONFIG" ]; then
    CLIENT_ID=$(grep -E '^\s*GOOGLE_CLIENT_ID\s*=' "$XCCONFIG" | sed 's/.*=\s*//' | tr -d '[:space:]')
    if [ -n "$CLIENT_ID" ]; then
        REVERSED=$(echo "$CLIENT_ID" | tr '.' '\n' | tail -r | paste -sd '.' -)
        # Remove any existing GOOGLE_REVERSED_CLIENT_ID line and append the derived one
        grep -v '^\s*GOOGLE_REVERSED_CLIENT_ID' "$XCCONFIG" > "$XCCONFIG.tmp"
        echo "GOOGLE_REVERSED_CLIENT_ID = $REVERSED" >> "$XCCONFIG.tmp"
        mv "$XCCONFIG.tmp" "$XCCONFIG"
    fi
else
    echo "⚠️  Warning: Secrets.xcconfig not found."
    echo "   Copy Secrets.xcconfig.example → Secrets.xcconfig and fill in your Google Client ID."
    echo "   Google Drive upload will not work without it."
    echo ""
fi

echo "==> Building cloom-core (Rust) for $TARGET..."
cargo build --release \
    --manifest-path "$RUST_DIR/Cargo.toml" \
    --target "$TARGET"

echo "==> Generating Swift bindings via UniFFI..."
mkdir -p "$SWIFT_BRIDGE_DIR"
cd "$RUST_DIR"
cargo run --bin uniffi-bindgen -- generate \
    --library "target/$TARGET/release/libcloom_core.dylib" \
    --language swift \
    --out-dir "$SWIFT_BRIDGE_DIR"
cd "$PROJECT_ROOT"

# Copy the static library to a known location for Xcode to find
LIBS_DIR="$PROJECT_ROOT/libs"
mkdir -p "$LIBS_DIR"
cp "$RUST_DIR/target/$TARGET/release/libcloom_core.a" "$LIBS_DIR/"

echo "==> Build complete."
echo "    Static lib: $LIBS_DIR/libcloom_core.a"
echo "    Swift bindings: $SWIFT_BRIDGE_DIR/"
echo "    FFI header: $SWIFT_BRIDGE_DIR/cloom_coreFFI.h"
echo "    Module map: $SWIFT_BRIDGE_DIR/cloom_coreFFI.modulemap"
