# Feature Categories (A-L)

Feature codes are referenced throughout the implementation phases (08-implementation-phases.md).
Status indicators: **Done** = implemented, **Deferred** = planned for later phase, **Planned** = not yet started.

---

## A: Screen Recording — Done

| Code | Feature | Description | Status |
|------|---------|-------------|--------|
| A1 | Screen + Webcam recording | Record screen with webcam composited in real-time into single MP4 via CIContext + Metal | Done |
| A2 | Full-screen capture | Capture entire display via SCStreamOutput per-frame pipeline | Done |
| A3 | Screen-only recording | Record screen without webcam | Done |
| A4 | Per-frame pipeline | SCStreamOutput delivers CMSampleBuffers; VideoWriter (AVAssetWriter actor) encodes HEVC | Done |
| A5 | Window capture | Capture a specific application window via SCContentSharingPicker | Done |
| A6 | Region capture | Capture a user-selected rectangular area via RegionSelectionWindow | Done |
| A7 | Multi-monitor support | SCContentSharingPicker handles display enumeration | Done |
| A8 | System audio capture | Record system/app audio via SCStreamConfiguration.capturesAudio | Done |
| A9 | Microphone capture | Record microphone via SCStreamConfiguration.captureMicrophone on separate audioQueue | Done |
| A10 | Recording countdown | 3-2-1 visual countdown via CountdownOverlayWindow | Done |
| A11 | Pause/Resume | Segment-based: stop VideoWriter on pause, new segment on resume, SegmentStitcher concatenates | Done |
| A12 | Recording state machine | RecordingCoordinator: idle → selectingContent → countdown → recording → paused → stopping | Done |

---

## B: Webcam — Done (B6 deferred)

| Code | Feature | Description | Status |
|------|---------|-------------|--------|
| B1 | Webcam bubble overlay | Circular/rounded/pill NSPanel showing camera preview with CIContext Metal rendering | Done |
| B2 | Draggable bubble | Drag webcam bubble to any screen position | Done |
| B3 | Resizable bubble | Click-to-cycle: small (120pt), medium (180pt), large (280pt) | Done |
| B4 | Background blur | Person segmentation via VNGeneratePersonSegmentationRequest + CIFilter blur | Done |
| B5 | Webcam shapes | Circle, roundedRect, pill — shape-aware masking via CGContext cache | Done |
| B6 | Virtual backgrounds | Replace background using segmentation mask | Deferred |
| B7 | Bubble frames | Emoji frame decorations: none, geometric (💎✨💠), tropical (🌴🌺☀️), celebration (🎉🎊🥳) | Done |
| B8 | Image adjustments | Brightness, contrast, saturation, highlights, shadows via CIColorControls + CIHighlightShadowAdjust | Done |
| B9 | Color temperature | CITemperatureAndTint filter, 2000–10000K range | Done |
| B10 | Webcam unmirroring | Horizontal flip with correct CIImage extent handling | Done |

---

## C: Controls & UI — Done

| Code | Feature | Description | Status |
|------|---------|-------------|--------|
| C1 | Floating control pill | BubbleControlPill NSPanel attached to webcam bubble (stop, timer, pause, discard) | Done |
| C2 | Menu bar integration | MenuBarExtra for quick access to recording and library | Done |
| C3 | Global keyboard shortcuts | CGEvent tap with customizable hotkeys (Cmd+Shift+R toggle, Cmd+Shift+P pause), ShortcutRecorderButton in Settings | Done |
| C4 | Mic mute/unmute | Toggle microphone during recording without stopping | Done |
| C5 | Recording timer | Elapsed time display in control pill and toolbar | Done |
| C6 | Recording toolbar | RecordingToolbarPanel with mode selection, mic/camera/blur toggles, draw/click/spotlight toggles | Done |
| C7 | Discard recording | DiscardConfirmationWindow alert, performDiscard cleanup, trash button in toolbar + menu bar | Done |

---

## D: Drawing & Annotations — Done

| Code | Feature | Description | Status |
|------|---------|-------------|--------|
| D1 | Pen tool | Freehand drawing on transparent AnnotationCanvasWindow NSPanel | Done |
| D2 | Highlighter | Semi-transparent (0.3 opacity) freehand strokes | Done |
| D3 | Arrow tool | Draw arrows pointing to areas of interest | Done |
| D4 | Line tool | Draw straight lines | Done |
| D5 | Rectangle tool | Draw rectangles on screen | Done |
| D6 | Ellipse tool | Draw ellipses/circles on screen | Done |
| D7 | Color picker & stroke width | 6-color palette (red/blue/green/orange/white/black) + width slider in AnnotationToolbarPanel | Done |
| D8 | Eraser & undo | Erase strokes, undo stack (no redo). Clear all. Escape exits draw mode | Done |
| D9 | Mouse click emphasis | Expanding ripple effect via ClickEmphasisMonitor + CIRadialGradient | Done |
| D10 | Cursor spotlight | Radial gradient dim overlay via CursorSpotlightMonitor | Done |
| D11 | Real-time burn-in | AnnotationRenderer composites strokes/ripples/spotlight as CIImage into recorded frames | Done |

---

## E: Editor — Done

| Code | Feature | Description | Status |
|------|---------|-------------|--------|
| E1 | Trim start/end | TrimHandlesView with yellow drag handles + grayed-out overlay | Done |
| E2 | Cut sections | CutRegionOverlay with red hatched regions + context menu to remove | Done |
| E3 | Stitch clips | StitchPanelView with drag-to-reorder, EditorCompositionBuilder concatenation | Done |
| E4 | Timeline scrubber | EditorTimelineView with Canvas-based waveform peaks + thumbnail strip + red playhead | Done |
| E5 | Speed adjustment | SpeedControlView popover with 0.25x–4x presets | Done |
| E6 | Thumbnail selection | ThumbnailPickerView with slider + "Use Current Frame" + PNG save | Done |
| E7 | Export adjustments | Brightness/contrast sliders in EditorExportView, AVMutableVideoComposition with CIColorControls | Done |

---

## F: AI Features — Done

| Code | Feature | Description | Status |
|------|---------|-------------|--------|
| F1 | Transcription | Word-level transcription via OpenAI `whisper-1` (Rust client, multipart upload) | Done |
| F2 | Auto-generate title | LLM generates concise title via `gpt-4o-mini` (Rust client) | Done |
| F3 | Auto-generate summary | LLM generates 2-3 sentence summary via `gpt-4o-mini` (Rust client) | Done |
| F4 | Auto-generate chapters | LLM divides transcript into chapters with timestamps via `gpt-4o-mini` (Rust client) | Done |
| F5 | Filler word detection | Identify "um", "uh", "like", "you know", etc. (Rust, single + multi-word sliding window) | Done |
| F6 | Silence detection | Detect silent regions via symphonia + RMS threshold (Rust, configurable threshold/duration) | Done |

---

## G: Player — Done

| Code | Feature | Description | Status |
|------|---------|-------------|--------|
| G1 | Basic video playback | AVPlayer wrapper in EditorView with play/pause/seek | Done |
| G2 | Caption overlay | Karaoke-style word-by-word highlight with phrase grouping + binary search lookup | Done |
| G3 | Speed control | 0.25x–4x playback speed via AVPlayer.rate | Done |
| G4 | Fullscreen | NSWindow.toggleFullScreen | Done |
| G5 | Picture-in-Picture | AVPictureInPictureController via VideoPreviewView Coordinator | Done |
| G6 | Transcript panel | TranscriptPanelView: FlowLayout, auto-scroll, click-to-seek, filler word styling | Done |
| G7 | Chapter navigation | ChapterNavigationView popover list + accent color timeline markers | Done |

---

## H: Export & Sharing — Done

| Code | Feature | Description | Status |
|------|---------|-------------|--------|
| H1 | Auto-copy file path | Copy exported file path to clipboard + Show in Finder (context menus) | Done |
| H2 | MP4 export with EDL | Apply EditDecisionList via EditorCompositionBuilder + AVAssetExportSession | Done |
| H3 | GIF export | ~~Removed (Phase 24) — gifski was AGPL-licensed~~ | Removed |

---

## I: Library & Organization — Done

| Code | Feature | Description | Status |
|------|---------|-------------|--------|
| I1 | Full-text search | .searchable modifier, title/summary/transcript SwiftData predicate filtering | Done |
| I2 | Folder management | LibrarySidebarView: create, rename, move, nest folders with context menus | Done |
| I3 | Tags & labels | TagEditorView: 8-preset color picker, tag pills on VideoCardView, bulk tagging | Done |
| I4 | Sort & filter | LibrarySortOrder enum with 7 options, TranscriptFilter, hover preview on cards | Done |
| I5 | Thumbnail previews | Video thumbnails in grid view with hover scale effect | Done |
| I6 | Info sidebar | Editor info panel (title, full summary, metadata) toggled via (i) button | Done |

---

## J: Settings & Polish — Done

| Code | Feature | Description | Status |
|------|---------|-------------|--------|
| J1 | Video quality settings | VideoQuality enum: low (4Mbps), medium (10Mbps), high (20Mbps) | Done |
| J2 | Frame rate settings | 24/30/60 FPS via @AppStorage | Done |
| J3 | Codec | HEVC primary with H.264 fallback (no user-facing codec selection) | Done |
| J4 | Launch at startup | SMAppService.mainApp register/unregister, toggle in Settings > General | Done |
| J5 | Keyboard shortcut customization | ShortcutRecorderButton with UCKeyTranslate display strings, UserDefaults persistence | Done |
| J6 | Dark mode | Theme.swift semantic Color extensions, appearance picker System/Light/Dark in Settings | Done |
| J7 | Notifications | UNUserNotificationCenter, recording-complete with "Open Library" action | Done |
| J8 | Mic gain / sensitivity | MicGainProcessor applies configurable gain to mic samples; sensitivity slider in Settings | Done |
| J9 | Onboarding | PermissionChecker + OnboardingView with live status polling for Screen Recording/Camera/Mic/Accessibility | Done |
| J10 | Crash recovery | cleanupOrphanedTempFiles in AppState.init, scans /tmp for cloom_segment_* and cloom_audio_* | Done |
| J11 | Disk space monitoring | checkDiskSpace <1GB guard, storage summary in LibraryView toolbar | Done |
| J12 | Webcam settings | WebcamSettingsTab: shape picker, adjustment sliders, theme swatches, temperature/tint | Done |

---

## K: Analytics & Advanced — Partial

| Code | Feature | Description | Status |
|------|---------|-------------|--------|
| K1 | Local view analytics | Track view count, watch time, completion rate (models exist, UI not built) | Deferred |
| K2 | Timestamped comments | Add comments at specific video timestamps (model exists, UI not built) | Deferred |
| K3 | Performance optimization | SharedCIContext singleton, PersonSegmenter throttling, shared Tokio runtime, cached rendering, etc. (Phase 17) | Done |
| K4 | Beauty / soft-focus filter | Person segmentation + CIGaussianBlur skin smoothing | Deferred |
| K5 | Bookmarks | Timestamped bookmarks in editor with timeline markers, panel UI, "B" key shortcut (Phase 13) | Done |
| K6 | Subtitle embedding | Hard-burn + SRT sidecar export, EDL-aware timing, pre-rendered image cache (Phase 15) | Done |
| K7 | Multi-track audio export | All source audio tracks exported, AVMutableAudioMix mixdown for web player compat (Phase 15) | Done |

---

## L: Pre-Release — Done

| Code | Feature | Description | Status |
|------|---------|-------------|--------|
| L1 | Ad-hoc code signing | Ad-hoc `codesign --sign -` via `scripts/release.sh` (no Developer ID; users right-click → Open on first launch) | Done |
| L2 | DMG packaging + Homebrew tap | `create-dmg` drag-to-Applications DMG, GitHub Releases hosting, custom Homebrew tap (`iamsachin/homebrew-cloom`) | Done |
| L3 | App icon + branding | 1024x1024 master icon + all macOS sizes + custom menu bar icon (Phase 14) | Done |
| L4 | Release notes | `CHANGELOG.md` with full v0.1.0 feature list | Done |
| L5 | CI release workflow | `.github/workflows/release.yml`: build → ad-hoc sign → DMG → GitHub Release → update Homebrew tap on `v*` tag | Done |
| L6 | Auto-update via Sparkle | Sparkle framework checks appcast on GitHub Pages, downloads DMG, replaces app, relaunches | Done |
| L7 | About section | `AboutSettingsTab`: 7th Settings tab with app icon, version, links, "Check for Updates" button (Sparkle) | Done |
