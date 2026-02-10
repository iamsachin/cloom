#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
RUST_DIR="$PROJECT_ROOT/cloom-core"
SWIFT_BRIDGE_DIR="$PROJECT_ROOT/CloomApp/Sources/Bridge/Generated"
TARGET="aarch64-apple-darwin"

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
