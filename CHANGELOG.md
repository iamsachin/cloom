# Changelog

All notable changes to Cloom will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-04-02

### First Stable Release

Cloom graduates to v1.0 — a full-featured, open-source screen recorder for macOS.

**Highlights:**
- **Screen, window, and app recording** with webcam overlay, system audio, and microphone capture
- **Non-destructive editor** with trim, cut, stitch, speed control, and timeline thumbnails
- **AI-powered features** — transcription, titles, summaries, chapters, filler/silence detection, and multi-language caption translation (14 languages)
- **Annotations & presenter tools** — drawing, text, zoom/magnifier, keystroke visualization, click emphasis, spotlight, and teleprompter overlay
- **Punch-in re-record** — rewind and re-record from any point without restarting
- **Social media export presets** — 16:9, 9:16, 1:1, 4:5 with reframing and background options
- **PII redaction** — blur, pixelate, or black-box sensitive regions in video
- **Library management** — folders, tags, search, filters, hover preview, drag-and-drop, and comments
- **Google Drive integration** for cloud uploads
- **Sparkle auto-updates** with Developer ID signed and Apple-notarized builds
- **Smart editing** — undo/redo, auto-cut silence/fillers, keyboard-driven workflow (J/K/L, I/O, arrows)

## [0.7.2] - 2026-03-30

### Added
- **Teleprompter speed controls** — Slower/Faster buttons on the overlay control bar with live speed indicator (±10 pt/s, range 10–200). Speed changes persist across sessions.
- **Click-and-drag teleprompter scrolling** — grab and drag the script text up/down for manual positioning, in addition to scroll wheel support.

### Fixed
- **Toolbar toggle state desync** — zoom, annotations, keystroke, teleprompter, click emphasis, and spotlight buttons now correctly reflect their on/off state after pause/resume (previously reset to "off" when the toolbar was recreated).
- **Teleprompter script persisting across recordings** — new recordings now start with an empty script panel instead of showing the previous recording's text.

## [0.7.1] - 2026-03-30

### Added
- **In-app features directory** — browsable grid of all 42 app features organized by category (Recording, Editing, Export, AI, Library) with SF Symbol icons and keyboard shortcut badges. Accessible from the "Features" menu item in the menu bar.

## [0.7.0] - 2026-03-29

### Added
- **Multi-language caption translation** — translate subtitles and transcript exports to 14 languages (Spanish, French, German, Japanese, Korean, Chinese, Hindi, Arabic, Italian, Dutch, Russian, Turkish, Portuguese) via gpt-4.1-mini at export time.
- **Language picker** in export view (when subtitles enabled) and transcript export menu (Markdown/PDF).
- **Transcript punctuation restoration** — LLM now restores missing periods, commas, and capitalization in transcripts.

### Changed
- All LLM calls upgraded from gpt-4o-mini to gpt-4.1-mini (better quality, lower cost).
- `BlurRegionCompositor` and `ReframeCompositor` migrated from deprecated `AVMutableVideoComposition` to `AVVideoComposition.Configuration`.

## [0.6.0] - 2026-03-29

### Added
- **Teleprompter overlay** — floating transparent script display visible to the presenter but invisible in recordings (`sharingType = .none`). Paste text or import `.txt`/`.md` files.
- **Auto-scroll** with configurable speed, play/pause button, and manual scroll wheel support. Global hotkey: `Cmd+Shift+T`.
- **Teleprompter settings** — font size, scroll speed, background opacity, position (top/bottom), and mirror mode for physical beamsplitter teleprompters.
- **Resizable teleprompter window** — drag edges/corners to resize (min 300x150).
- **Liquid Glass UI** — adopted macOS 26 Liquid Glass styling across toolbars, buttons, and panels.

## [0.5.0] - 2026-03-28

### Added
- **Punch-in re-record** — pause a recording, rewind to any point (preset buttons: 5s/10s/30s/60s or slider), and re-record from there. Eliminates restarts and complex post-production stitching.
- **Rewind button** in recording toolbar and webcam bubble pill (visible when paused).
- **Amber timeline markers** in the editor showing where punch-in replacements occurred.

### Changed
- Segment stitcher rewritten with 3-step pipeline (normalize → compose → export) for robust multi-segment handling.
- Recording segments now track duration and effective duration for precise rewind calculations.

### Fixed
- Multi-segment stitching crash caused by `AVMutableComposition` format incompatibility when audio formats differ between segments.
- Composition passthrough export crash when video format hint was nil for composition tracks.

## [0.4.0] - 2026-03-28

### Added
- **System share sheet** — share videos via AirDrop, Messages, Mail, and more from the editor export sheet and library context menu (NSSharingServicePicker).
- **Batch export** — multi-select videos in the library and export them all to a chosen folder at once.
- **Transcript export as Markdown** — export transcript with chapters and summary as a `.md` file from the editor toolbar.
- **Transcript export as PDF** — professionally styled A4 PDF with title, summary, chapters, transcript, and page footers.
- **Background upload resume** — Google Drive uploads now persist resumable session URIs so interrupted uploads resume automatically on app relaunch.
- **System audio toggle** — mute/unmute system audio capture from the ready toolbar, recording toolbar, and Settings > Recording.
- **Configurable countdown** — choose 0 (skip), 1, 3, 5, or 10 seconds countdown before recording starts.
- **Custom save location** — choose a default folder for recordings in Settings > Recording (defaults to Desktop).
- **Silence detection thresholds** — adjust threshold dB and minimum duration in Settings > Recording for fine-tuned auto-cut.
- **Webcam mirroring toggle** — enable/disable horizontal flip in Settings > Webcam.
- **Video card metadata chips** — library cards now show resolution, file size, quality, and recording type directly on the card.

### Changed
- Library grid cards use smaller minimum width (220px) for better density.
- Removed hover zoom effect on library cards to prevent overlap.
- Hover preview images are now properly clipped within card bounds.

### Fixed
- Deprecated `AVAsset(url:)` replaced with `AVURLAsset(url:)`.

## [0.3.0] - 2026-03-28

### Added
- **Hover video preview** — hovering over a video card in the library shows an animated filmstrip preview cycling through 8 frames, with progress dots at the bottom.
- **Drag-and-drop into folders** — drag video cards from the grid or list view directly onto sidebar folders to organize. Drop on "All Videos" to remove from a folder. Drop target highlights blue.
- **Date range filter** — filter library by Today, This Week, This Month, or Last 3 Months. Filter icon fills when any filter is active.
- **Duration range filter** — filter library by Under 30s, 30s-2m, 2m-10m, or Over 10m. Combines with date and transcript filters.
- **Timestamped comments** — add comments to videos in the editor sidebar. Optionally stamp the current playback time. Click a timestamp to seek. Comments near the playhead highlight blue.

## [0.2.0] - 2026-03-28

### Added
- **Text annotation tool** — click anywhere on screen during recording to place text labels/callouts. Press Enter to commit, Escape to cancel. Text renders in both the live canvas preview and the exported video.
- **Custom color picker** — rainbow button next to the 6 palette swatches opens a full color picker with hex input. Custom colors work with all annotation tools.
- **Zoom/magnifier presenter tool** — click to zoom into a screen region at 2.5x with smooth ease-in/out animation. A full-screen overlay shows the crop region with a blue border and "ZOOM" badge. Close button (X) dismisses zoom. Clicks pass through to apps while zoomed. Annotations zoom with content.

### Fixed
- **Welcome window focus** — the onboarding window no longer falls behind other windows after dismissing Camera or Microphone permission dialogs.

## [0.1.5] - 2026-03-28

### Added
- **Undo/redo for all editor operations** — Cmd+Z / Shift+Cmd+Z for trim, cut, speed, stitch, and thumbnail changes (in-memory stack, max 50 history)
- **Auto-cut silence removal** — "Silences" button highlights detected silent regions on timeline; preview before applying cuts
- **Auto-cut filler word removal** — "Fillers" button highlights filler words (um, uh, like, etc.) on timeline; preview before applying
- **Editor keyboard shortcuts** — J/K/L shuttle playback (-8x to 8x), left/right arrow frame-step (~33ms), I/O mark-in/mark-out, Home/End jump to trim boundaries, B for bookmarks
- **Mark-in timeline indicator** — orange line with flag and shaded region when marking a cut
- **Silence detection persistence** — silence ranges from AI pipeline are now saved to the database for reuse in the editor

### Fixed
- **Sparkle auto-update version comparison** — CFBundleVersion now matches semantic version (was using integer build number, causing Sparkle to think installed version was newer)
- **GitHub Release notes** — now include changelog content instead of only install instructions

## [0.1.4] - 2026-03-27

### Fixed
- **Export quality picker now works** — previously had no effect on unmodified recordings (passthrough copy ignored quality selection). Now re-encodes when export quality differs from recording quality.

### Added
- Recording details in editor info panel — codec, bitrate, FPS, audio tracks, quality setting, recording type
- Hover tooltip on video cards — shows resolution, duration, file size, quality, type, and date
- Resolution and file size columns in library list view
- `recordingQuality` field on VideoRecord — tracks quality used at recording time; export picker defaults to it

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

[0.1.5]: https://github.com/iamsachin/cloom/releases/tag/v0.1.5
[0.1.4]: https://github.com/iamsachin/cloom/releases/tag/v0.1.4
[0.1.3]: https://github.com/iamsachin/cloom/releases/tag/v0.1.3
[0.1.2]: https://github.com/iamsachin/cloom/releases/tag/v0.1.2
[0.1.0]: https://github.com/iamsachin/cloom/releases/tag/v0.1.0
