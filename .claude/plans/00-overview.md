# Cloom - Loom Clone for macOS: Overview

## What Is Cloom?
A free, local, standalone macOS screen recording app that replicates Loom's UI/UX.

## Scope Boundary
- In scope: Loom-like recording, camera bubble, editing, transcript/player UX on local files.
- Out of scope: Loom cloud collaboration features (hosted links, team workspaces, cloud comments, remote analytics).

## Key Decisions
- **Tech Stack:** SwiftUI + Rust FFI (hybrid)
- **Build System:** xcodegen generates `Cloom.xcodeproj` from `project.yml`; `build.sh` orchestrates Rust build + UniFFI codegen
- **macOS Target:** macOS 26+ (Tahoe), Apple Silicon only
- **Swift:** 6.2, **Xcode:** 26.2
- **Rust:** Stable edition 2021, UniFFI 0.31
- **Storage:** Local-only (SwiftData)
- **AI:** API-based (OpenAI only in v1; transcription via `whisper-1`; LLM via `gpt-4o-mini`; provider abstraction retained for future expansion) — Rust owns API clients
- **GIF Export:** gifski via Rust FFI (Swift extracts PNG frames, Rust encodes GIF)
- **Features:** All categories A-L (see 01-features.md); some deferred (B6 virtual backgrounds, K1 analytics, K2 comments, K4 beauty filter)
- **Distribution:** Direct DMG sharing (outside App Store) with Developer ID signing + Apple notarization + stapling (not yet implemented)

## Design Principle
Swift owns all Apple framework interactions **and** all video processing:
- UI (SwiftUI, AppKit)
- Capture (ScreenCaptureKit — SCStreamOutput per-frame pipeline)
- Camera (AVFoundation, Vision)
- Encoding & Real-Time Compositing (AVAssetWriter, CoreImage, Metal — webcam + annotations composited into frames during recording)
- Export (AVMutableComposition for MP4 with EDL, AVAssetExportSession)
- Data persistence (SwiftData)
- Settings (UserDefaults / @AppStorage)
- API key storage (file-based at `~/Library/Application Support/Cloom/api_key`)
- Global hotkeys (CGEvent tap)

Rust owns compute-heavy processing and external API calls:
- AI API clients (OpenAI via reqwest + tokio; provider abstraction retained for future providers)
- Audio analysis (silence detection via symphonia, filler word identification)
- GIF export (gifski encoder with PNG manifest input)

## Implementation Status
- **Phases 1A–17:** Complete (project skeleton through performance & code quality audit)
  - 1A–3: Foundation (skeleton → recording modes → compositing)
  - 4–7: Features (annotations → editor → AI → player)
  - 8–11: Polish & tests (library → settings → cleanup → 43 Rust + 32 Swift tests)
  - 12: Code quality & file splitting (no file over ~280 lines)
  - 13: Bookmarks + performance audit (5 optimizations)
  - 14: App icon & branding
  - 15: Audio export fixes & subtitle embedding (hard-burn + SRT)
  - 16: Mic sensitivity setting
  - 17: Performance & code quality audit (SharedCIContext, PersonSegmenter throttling, shared Tokio runtime, etc.)
- **Phase 18 (Pre-Release):** Not started — Developer ID signing, notarization, DMG packaging

## Prerequisites
- Xcode 26.2+ (for macOS 26 SDK)
- Rust toolchain (`rustup` + `cargo`)
- UniFFI CLI is local to the Rust crate (`cd cloom-core && cargo run --bin uniffi-bindgen`), NOT a global install
- Apple Developer Program membership (required for Developer ID signing + notarization — Phase 18)
