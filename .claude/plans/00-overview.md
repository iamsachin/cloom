# Cloom - Loom Clone for macOS: Overview

## What Is Cloom?
A free, local, standalone macOS screen recording app that replicates Loom's UI/UX.

## Scope Boundary
- In scope: Loom-like recording, camera bubble, editing, transcript/player UX on local files.
- Out of scope: Loom cloud collaboration features (hosted links, team workspaces, cloud comments, remote analytics).

## Key Decisions
- **Tech Stack:** SwiftUI + Rust FFI (hybrid)
- **Build System:** Xcode project is primary (SPM can be used for internal modularization)
- **macOS Target:** macOS 26+ (Tahoe), Apple Silicon only
- **Storage:** Local-only
- **AI:** API-based (OpenAI only in v1; default transcription model `gpt-4o-mini-transcribe`; provider/model abstraction retained for future expansion) — Rust owns API clients
- **Build Style:** Feature-complete planning, TDD
- **Features:** All categories A-K (see 01-features.md)
- **Distribution:** Direct DMG sharing (outside App Store) with Developer ID signing + Apple notarization + stapling

## Design Principle
Swift owns all Apple framework interactions **and** all video processing:
- UI (SwiftUI, AppKit)
- Capture (ScreenCaptureKit)
- Camera (AVFoundation, Vision)
- Encoding & Compositing (AVAssetWriter, VideoToolbox, CoreImage, Metal)
- Export (AVMutableComposition for MP4, annotations via CoreImage/CoreGraphics)
- Data persistence (SwiftData)
- Settings (UserDefaults)

Rust owns compute-heavy processing and external API calls:
- AI API clients (OpenAI via reqwest + tokio; provider abstraction retained for future providers)
- Audio analysis (silence detection, filler word identification via symphonia)
- GIF export (gif crate)

## Prerequisites
- Xcode (latest, for macOS 26 SDK)
- Rust toolchain (`rustup` + `cargo`)
- UniFFI CLI (`cargo install uniffi_bindgen`)
- Apple Developer Program membership (required for Developer ID signing + notarization)
