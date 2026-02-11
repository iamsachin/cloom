#!/usr/bin/env bash
set -euo pipefail

# Navigate to project root (where this script lives: .claude/skills/build/)
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$PROJECT_ROOT"

echo "==> Project root: $PROJECT_ROOT"

# Step 1: Build Rust + generate UniFFI bindings
echo "==> Building Rust & generating UniFFI bindings..."
./build.sh

# Step 2: Build Xcode project
echo ""
echo "==> Building Xcode project..."
BUILD_OUTPUT=$(xcodebuild -project Cloom.xcodeproj -scheme Cloom -configuration Debug build 2>&1) || true

# Step 3: Parse results
ERRORS=$(echo "$BUILD_OUTPUT" | grep -c "error:" 2>/dev/null || echo "0")
WARNINGS=$(echo "$BUILD_OUTPUT" | grep -c "warning:" 2>/dev/null || echo "0")

if echo "$BUILD_OUTPUT" | grep -q "BUILD SUCCEEDED"; then
    echo ""
    echo "BUILD SUCCEEDED ($WARNINGS warnings)"
    echo ""
    echo "==> Resetting TCC permissions for debug build..."
    tccutil reset Camera com.cloom.app 2>/dev/null || true
    tccutil reset Microphone com.cloom.app 2>/dev/null || true
    tccutil reset ScreenCapture com.cloom.app 2>/dev/null || true
    echo "    TCC reset done (Camera, Microphone, ScreenCapture)"
else
    echo ""
    echo "BUILD FAILED ($ERRORS errors, $WARNINGS warnings)"
    echo ""
    echo "==> Errors:"
    echo "$BUILD_OUTPUT" | grep -A2 "error:" | head -60
fi
