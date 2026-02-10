# Dependencies & Setup

## Prerequisites

| Tool | Required For | Install |
|------|-------------|---------|
| Xcode (latest) | macOS 26 SDK, SwiftUI, AppKit | Mac App Store |
| Rust toolchain | cloom-core | `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \| sh` |
| UniFFI CLI | Generate Swift bindings | `cargo install uniffi_bindgen` |
| Apple Developer Program membership | Developer ID signing + notarization for DMG distribution | developer.apple.com |

## Rust Crate Dependencies (Cargo.toml)

| Crate | Version | Purpose |
|-------|---------|---------|
| `uniffi` | 0.30 | FFI bindings generation (proc macros) |
| `serde` + `serde_json` | 1.x | Serialization (API responses) |
| `tokio` | 1.x (full) | Async runtime (AI API calls) |
| `reqwest` | 0.12 (json, multipart) | HTTP client for AI APIs |
| `symphonia` | 0.5 (aac, mp3, wav, isomp4) | Audio decoding (AAC/M4A/WAV/MP3) |
| `gif` | 0.13 | GIF encoding |
| `image` | 0.25 | Image processing (frame resize for GIF) |
| `thiserror` | 2.x | Error types |
| `log` + `env_logger` | 0.4 / 0.11 | Logging |

### Dev Dependencies

| Crate | Purpose |
|-------|---------|
| `rstest` | Parameterized tests |
| `tempfile` | Temporary files in tests |
| `mockall` | Mock trait implementations |
| `tokio-test` | Async test utilities |

### Removed from Original Plan

| Crate | Reason |
|-------|--------|
| `rusqlite` | Replaced by SwiftData (Swift owns persistence) |
| `hound` | Replaced by `symphonia` (handles AAC, not just WAV) |
| `mp4` + `bytes` | Encoding moved to Swift (AVFoundation + VideoToolbox) |
| `imageproc` | Processing/compositing moved to Swift (CoreImage) |
| `uuid` | UUIDs now generated in Swift |
| `chrono` | Date handling done in Swift |

## Swift Frameworks (System — no external deps)

| Framework | Purpose |
|-----------|---------|
| `SwiftUI` | UI |
| `AppKit` | NSPanel, NSWindow, NSStatusItem |
| `ScreenCaptureKit` | Screen recording |
| `AVFoundation` | Camera, audio, video playback, compositing, export |
| `VideoToolbox` | Hardware video encoding (H.264/H.265) |
| `Vision` | Person segmentation |
| `CoreImage` | GPU-accelerated image processing, annotation rendering |
| `Metal` | GPU compositing (via CoreImage) |
| `SwiftData` | Data persistence (replaces Rust SQLite) |
| `UniformTypeIdentifiers` | File type handling |
| `ServiceManagement` | Launch at startup (SMAppService) |
| `UserNotifications` | Notifications |
| `Security` | Keychain (API key storage) |
| `Carbon` | Global keyboard shortcuts via `RegisterEventHotKey` |

## Swift Package Dependencies (Third-Party)

| Package | Purpose | Cost |
|---------|---------|------|
| `GRDB` | Local SQLite + FTS5 transcript search indexing/querying | Free, open-source |

## macOS Info.plist Keys

```xml
NSScreenCaptureUsageDescription — "Cloom needs screen recording access to capture your screen."
NSCameraUsageDescription — "Cloom needs camera access for webcam recording."
NSMicrophoneUsageDescription — "Cloom needs microphone access to record audio."
```

## Build System

`build.sh` at project root orchestrates:
1. `cargo build --release --manifest-path cloom-core/Cargo.toml --target aarch64-apple-darwin`
2. `uniffi-bindgen generate --library target/aarch64-apple-darwin/release/libcloom_core.dylib --language swift --out-dir CloomApp/Sources/Bridge/Generated/`
3. Copies `target/aarch64-apple-darwin/release/libcloom_core.a` to link location
4. Xcode Build Phase references the static lib + generated Swift (Xcode project is the primary build/distribution path)

**Note:** Apple Silicon only target for v1 (`aarch64-apple-darwin`).

## Distribution (Outside App Store)

1. Archive/export the app from Xcode for Developer ID distribution.
2. Sign with `Developer ID Application`.
3. Submit for notarization (`xcrun notarytool submit ... --wait`).
4. Staple the notarization ticket to app/DMG (`xcrun stapler staple ...`).
5. Share the stapled DMG with colleagues.
