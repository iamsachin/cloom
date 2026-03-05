# Changelog

All notable changes to Cloom will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.3] - 2026-03-05

### Added
- **Automatic updates via Sparkle** — the app now checks for updates on launch and every 24 hours. When a new version is available, a dialog shows release notes with an "Install Update" button that downloads, installs, and relaunches the app automatically.
- "Check for Updates..." button in the menu bar and About settings tab

### Changed
- Replaced manual "Download Update" link with Sparkle's in-app update flow
- Release CI now signs DMGs with EdDSA and publishes an appcast to GitHub Pages

### Removed
- Old `UpdateChecker` class (replaced by Sparkle framework)

## [0.1.2] - 2026-03-05

### Added
- Multi-display selection for full-screen recording — when multiple monitors are connected, "Full Screen" shows a submenu listing each display by name and resolution

### Fixed
- Crash when opening video with invalid or missing file duration (NaN guard)

## [0.1.0] - 2026-03-03

### Added

**Screen Recording**
- Full-screen, window, and region capture via ScreenCaptureKit
- System audio + microphone recording with separate audio queues
- Pause/resume with segment-based recording and automatic stitching
- 3-2-1 countdown overlay before recording starts
- Global keyboard shortcuts (Cmd+Shift+R to toggle, Cmd+Shift+P to pause)

**Webcam**
- Real-time webcam bubble composited into recorded video
- Circle, rounded rectangle, and pill shapes
- Draggable and resizable bubble (small/medium/large)
- Background blur via Vision person segmentation
- Image adjustments (brightness, contrast, saturation, temperature)
- Decorative emoji frames (geometric, tropical, celebration)

**Drawing & Annotations**
- Pen, highlighter, arrow, line, rectangle, and ellipse tools
- Color picker (6 colors) and adjustable stroke width
- Mouse click emphasis (ripple effect)
- Cursor spotlight with dim overlay
- Real-time burn-in to recorded video

**Editor**
- Non-destructive editing with EDL (Edit Decision List) model
- Trim from start/end with draggable handles
- Cut out sections with visual markers
- Stitch multiple clips with drag-to-reorder
- Speed adjustment (0.25x to 4x)
- Custom thumbnail selection
- Timeline with waveform visualization and thumbnail strip
- Bookmarks with "B" key shortcut and timeline markers

**AI Features**
- Auto-transcription via OpenAI Whisper
- AI-generated titles, summaries, and chapters
- Filler word detection (um, uh, like, you know, etc.)
- Silence detection with configurable thresholds

**Player**
- Karaoke-style caption overlay with word-by-word highlighting
- Transcript sidebar with click-to-seek
- Chapter navigation with popover and timeline markers
- Picture-in-Picture and fullscreen support

**Library**
- Grid view with thumbnail previews
- Folder management (create, rename, move, nest)
- Tags with color-coded labels and bulk tagging
- Full-text search across titles, summaries, and transcripts
- Sort by newest, oldest, longest, shortest, largest, smallest, or alphabetical

**Export**
- MP4 export with quality selection (low/medium/high)
- Passthrough for unmodified exports (instant file copy)
- Embedded subtitle track (tx3g)
- Multi-track audio with web-player-compatible mixdown
- Brightness and contrast adjustments on export

**Settings & Polish**
- Launch at login via SMAppService
- Noise cancellation (noise gate on microphone)
- Mic sensitivity slider with live level meter
- Onboarding with permission status checks
- Dark mode with System/Light/Dark picker
- Crash recovery and temp file cleanup
- Disk space monitoring
- Notifications on recording completion

**Google Drive**
- Upload recordings directly to Google Drive
- OAuth sign-in via Google Sign-In SDK

**Distribution**
- Ad-hoc code signing for Gatekeeper bypass
- DMG packaging with drag-to-Applications
- Homebrew tap (`brew tap iamsachin/cloom && brew install --cask cloom`)
- GitHub Actions CI/CD release pipeline
- In-app update checker via GitHub Releases API

[0.1.3]: https://github.com/iamsachin/cloom/releases/tag/v0.1.3
[0.1.2]: https://github.com/iamsachin/cloom/releases/tag/v0.1.2
[0.1.0]: https://github.com/iamsachin/cloom/releases/tag/v0.1.0
