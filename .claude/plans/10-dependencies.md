# Dependencies & Setup

## Prerequisites

| Tool | Required For | Install |
|------|-------------|---------|
| Xcode 26.2+ | macOS 26 SDK, SwiftUI, AppKit | Mac App Store |
| Rust toolchain | cloom-core | `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \| sh` |
| xcodegen | Generate Cloom.xcodeproj from project.yml | `brew install xcodegen` |
| Apple Developer Program membership | Developer ID signing + notarization (Phase 18) | developer.apple.com |

> **Note:** UniFFI CLI is local to the Rust crate (`cd cloom-core && cargo run --bin uniffi-bindgen`). No global install needed.

## Rust Crate Dependencies (Cargo.toml)

### Production Dependencies

| Crate | Version | Purpose |
|-------|---------|---------|
| `uniffi` | 0.31 (cli feature) | FFI bindings generation (proc macros) |
| `serde` + `serde_json` | 1.x | Serialization (API responses) |
| `tokio` | 1.x (rt-multi-thread) | Async runtime (AI API calls) |
| `reqwest` | 0.12 (json, multipart, rustls-tls) | HTTP client for OpenAI APIs |
| `symphonia` | 0.5 (aac, isomp4) | Audio decoding (AAC/M4A from MP4 containers) |
| `thiserror` | 2.x | Error type derive macros |
| `uuid` | 1.x | Chapter ID generation |

### Dev Dependencies

| Crate | Purpose |
|-------|---------|
| `wiremock` | 0.6 — HTTP mocking for AI API tests |
| `tempfile` | 3.x — Temporary files/dirs in tests |
| `tokio` | 1.x (macros) — Async test utilities |

### Removed / Changed from Original Plan

| Original | Actual | Reason |
|----------|--------|--------|
| `gifski` | Removed (Phase 24) | AGPL-licensed; GIF export removed |
| `png` + `imgref` + `rgb` | Removed (Phase 24) | Only needed for gifski |
| `hound` | `symphonia` | symphonia handles AAC/M4A (not just WAV) |
| `rstest` | Not used | Standard `#[test]` sufficient |
| `mockall` | Not used | Concrete classes, no trait mocking needed |
| `tokio-test` | `tokio` macros | `#[tokio::test]` macro from main tokio crate |
| `log` + `env_logger` | Not used | Minimal Rust logging needs |
| `rusqlite` | SwiftData | Swift owns persistence |
| `mp4` + `bytes` | AVFoundation | Encoding moved to Swift |
| `uuid` (for Swift) | Swift Foundation | UUIDs generated in Swift |
| `chrono` | Swift Foundation | Dates handled in Swift |

## Swift Frameworks (System — no external deps)

| Framework | Purpose |
|-----------|---------|
| `SwiftUI` | UI |
| `AppKit` | NSPanel, NSWindow, NSStatusItem, NSAppearance |
| `ScreenCaptureKit` | Screen recording (SCStream, SCStreamOutput, SCContentSharingPicker) |
| `AVFoundation` | Camera, audio, video playback, compositing, export |
| `VideoToolbox` | Hardware video encoding (HEVC/H.264) via AVAssetWriter |
| `Vision` | Person segmentation (VNGeneratePersonSegmentationRequest) |
| `CoreImage` | GPU-accelerated image processing, filter pipelines, annotation rendering |
| `CoreGraphics` | Shape masking, path construction |
| `Metal` | GPU compositing (via CIContext) |
| `SwiftData` | Data persistence (@Model, @Query, ModelContainer) |
| `UniformTypeIdentifiers` | File type handling |
| `ServiceManagement` | Launch at startup (SMAppService) |
| `UserNotifications` | Notifications (UNUserNotificationCenter) |

### Not Used (Changed from Plan)

| Original | Reason |
|----------|--------|
| `Security` (Keychain) | API keys stored in file (not Keychain) to avoid debug rebuild prompts |
| `Carbon` (RegisterEventHotKey) | CGEvent tap used instead for global hotkeys |
| `GRDB` (SQLite FTS) | SwiftData predicate filtering sufficient for search |

## Swift Package Dependencies (Third-Party)

| Package | Version | Purpose |
|---------|---------|---------|
| `GoogleSignIn` | 8.0+ | Google OAuth for Drive uploads |
| `LaunchAtLogin` | 1.1+ | SMAppService wrapper for login item |
| `KeyboardShortcuts` | 2.0+ | Global keyboard shortcut recording UI |
| `Sparkle` | 2.6+ | In-app auto-updates (appcast + EdDSA verification + install + relaunch) |

## macOS Info.plist Keys

```xml
NSScreenCaptureUsageDescription — "Cloom needs screen recording access to capture your screen."
NSCameraUsageDescription — "Cloom needs camera access for webcam recording."
NSMicrophoneUsageDescription — "Cloom needs microphone access to record audio."
SUFeedURL — "https://iamsachin.github.io/cloom/appcast.xml"
SUPublicEDKey — EdDSA public key for Sparkle update verification
```

## Entitlements (Cloom.entitlements)

- App Sandbox (with exceptions for recording)
- Camera access
- Microphone access

## Build System

### xcodegen (project.yml → Cloom.xcodeproj)

- **Targets:** Cloom (app), CloomTests (unit-test)
- **Deployment:** macOS 26.0
- **Key settings:**
  - `LIBRARY_SEARCH_PATHS: $(PROJECT_DIR)/libs`
  - `SWIFT_INCLUDE_PATHS: $(PROJECT_DIR)/CloomApp/Sources/Bridge/Generated`
  - `SWIFT_ENABLE_EXPLICIT_MODULES: NO` (workaround for Xcode 26 UniFFI modulemap)
  - `SWIFT_OBJC_BRIDGING_HEADER: CloomApp/Sources/Bridge/Cloom-Bridging-Header.h`
  - Linker flag: `-lcloom_core`
- Run `xcodegen generate` after changing project.yml or adding files/directories

### build.sh (Rust → Swift bindings)

1. Source `~/.cargo/env` (for Xcode Build Phase compatibility)
2. `cargo build --release --target aarch64-apple-darwin` → `libcloom_core.a` + `libcloom_core.dylib`
3. `cd cloom-core && cargo run --bin uniffi-bindgen generate` → `CloomApp/Sources/Bridge/Generated/`
4. Copy `libcloom_core.a` to `libs/`
5. Runs as Xcode pre-build script phase

**Apple Silicon only** (`aarch64-apple-darwin`) for v1.

## Distribution

1. Ad-hoc code signing (`codesign --sign -`)
2. DMG packaging via `create-dmg`
3. GitHub Releases hosting
4. Homebrew tap (`iamsachin/homebrew-cloom`)
5. **Auto-updates via Sparkle** — appcast.xml hosted on GitHub Pages (`iamsachin.github.io/cloom/appcast.xml`), EdDSA-signed DMGs, in-app download + install + relaunch
6. CI: tag push → build → sign → DMG → GitHub Release → update appcast → update Homebrew tap
