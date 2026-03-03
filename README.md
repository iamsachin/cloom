# Cloom

A free, local, standalone screen recording app for macOS — inspired by [Loom](https://www.loom.com/).

Record your screen with webcam overlay, annotate in real time, edit with a non-destructive timeline editor, and get AI-powered transcription and summaries — all running locally on your Mac.

## Features

- **Screen Recording** — Full screen, window, region, or webcam-only capture with system + mic audio
- **Webcam Overlay** — Draggable, resizable bubble with circle/rounded/pill shapes, background blur, emoji frames, and image adjustments
- **Real-Time Annotations** — Pen, highlighter, arrow, line, rectangle, ellipse tools with color/width options, mouse click emphasis, and cursor spotlight
- **Non-Destructive Editor** — Trim, cut, stitch clips, adjust speed (0.25x–4x), brightness/contrast, and thumbnail selection
- **AI Transcription** — Word-level transcription via OpenAI Whisper, auto-generated titles/summaries/chapters, filler word and silence detection
- **Player** — Karaoke-style captions, transcript sidebar with click-to-seek, chapter navigation, Picture-in-Picture, fullscreen
- **Subtitle Export** — Hard-burn subtitles into video or export SRT sidecar files
- **Library** — Folders, color-coded tags, full-text search, sort/filter, grid and list views
- **Google Drive** — Upload recordings directly to Google Drive with shareable links
- **Settings** — Global hotkeys, launch at startup, video quality/FPS, mic sensitivity, dark mode, webcam customization

## Install

### Homebrew (recommended)

```bash
brew tap iamsachin/cloom
brew install --cask cloom
```

### Manual download

Download the latest DMG from [GitHub Releases](https://github.com/iamsachin/cloom/releases), open it, and drag Cloom to your Applications folder.

### First launch

Cloom is ad-hoc signed (not notarized by Apple), so macOS will block it on first launch. This is a **one-time** step — after you allow it once, it won't ask again.

**Option A** — System Settings:
1. Open **System Settings → Privacy & Security**
2. Scroll down and click **Open Anyway** next to the Cloom message

**Option B** — Terminal:
```bash
xattr -cr /Applications/Cloom.app
open /Applications/Cloom.app
```

## Requirements (for building from source)

- macOS 26+ (Tahoe)
- Apple Silicon (arm64)
- Xcode 26.2+
- Rust toolchain ([rustup](https://rustup.rs/))
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Build from Source

```bash
# 1. Clone the repo
git clone https://github.com/iamsachin/cloom.git
cd cloom

# 2. Install Rust (if not already installed)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup target add aarch64-apple-darwin

# 3. Build Rust library + generate UniFFI bindings
./build.sh

# 4. Generate Xcode project
xcodegen generate

# 5. Open in Xcode
open Cloom.xcodeproj
```

Press Cmd+R in Xcode to build and run.

> **Note:** After each rebuild, macOS resets TCC permissions. Run these before testing:
> ```bash
> tccutil reset Camera com.cloom.app
> tccutil reset Microphone com.cloom.app
> tccutil reset ScreenCapture com.cloom.app
> ```

## Secrets Setup

Cloom requires Google OAuth credentials for Drive upload and an OpenAI API key for AI features. Both are optional — the app works without them.

### Google OAuth (for Drive upload)

1. Copy the example files:
   ```bash
   cp CloomApp/Sources/Cloud/Secrets.example.swift CloomApp/Sources/Cloud/Secrets.swift
   cp CloomApp/Resources/Secrets.xcconfig.example CloomApp/Resources/Secrets.xcconfig
   ```

2. Get a Google OAuth Client ID from [Google Cloud Console](https://console.cloud.google.com):
   - Create a project → Enable Google Drive API
   - Credentials → Create OAuth Client ID → macOS → Bundle ID: `com.cloom.app`

3. Fill in your Client ID in both `Secrets.swift` and `Secrets.xcconfig`

4. Regenerate the Xcode project: `xcodegen generate`

### OpenAI API Key (for AI features)

Enter your API key in the app: Settings > AI > API Key.

## Architecture

Cloom uses a **Swift + Rust hybrid** architecture:

**Swift** (SwiftUI + AppKit) handles all Apple framework interactions:
- UI, capture (ScreenCaptureKit), camera (AVFoundation), encoding (AVAssetWriter + CoreImage + Metal), export, data persistence (SwiftData), settings, and global hotkeys

**Rust** (via [UniFFI](https://github.com/mozilla/uniffi-rs) FFI) handles compute-heavy processing:
- AI API clients (OpenAI via reqwest + tokio), audio analysis (silence detection via symphonia, filler word identification)

```
CloomApp/Sources/
├── AI/           # AI orchestration, audio extraction, API key storage
├── Annotations/  # Drawing tools, canvas, renderer, click/cursor effects
├── App/          # App entry, state, navigation, hotkeys, permissions
├── Bridge/       # UniFFI generated bindings (gitignored)
├── Capture/      # Screen capture, camera, webcam overlay, shapes
├── Cloud/        # Google Drive upload, OAuth
├── Compositing/  # VideoWriter, webcam compositor, segment stitcher
├── Data/         # SwiftData models
├── Editor/       # Timeline editor, export, subtitles, captions
├── Library/      # Video library, folders, tags, search
├── Recording/    # Recording coordinator, toolbar, controls
├── Settings/     # Settings tabs
└── Shared/       # Shared utilities

cloom-core/src/
├── ai/           # OpenAI transcription + LLM clients
├── audio/        # Filler word + silence detection
├── lib.rs        # UniFFI scaffolding, FFI entry points
└── runtime.rs    # Shared Tokio runtime
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for a detailed breakdown.

## Running Tests

```bash
# Rust tests
cd cloom-core && cargo test

# Swift tests (requires Xcode project generated)
xcodebuild test -scheme Cloom -destination 'platform=macOS'
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, code style guidelines, and PR workflow.

## License

[MIT](LICENSE) — Copyright (c) 2025 Sachin Rajput
