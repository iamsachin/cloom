# Implementation Phases

## Phase 1A: Project Skeleton — Complete

**Goal:** Build compiles, Rust↔Swift FFI works, basic app launches.

| # | Task | Module | Features |
|---|------|--------|----------|
| 1 | Xcode project (xcodegen) + Cargo scaffold + build.sh + UniFFI hello-world | All | Project setup |
| 2 | SwiftData models (VideoRecord, FolderRecord, TagRecord, etc.) + ModelContainer setup | Data/ | Types |
| 3 | Basic Rust lib.rs with exported functions + UniFFI proc macros | Rust lib.rs | FFI smoke test |
| 4 | MenuBarExtra shell + empty library window | App/ | C2 |

**Milestone:** App launches in menu bar. Rust FFI round-trip works. SwiftData container initialized.

---

## Phase 1B: Walking Skeleton (Record → Library → Play) — Complete

**Goal:** Record full screen to MP4, save to library, play back.

| # | Task | Module | Features |
|---|------|--------|----------|
| 5 | Full-screen recording via SCStreamOutput per-frame pipeline | Capture/ | A2, A4 |
| 6 | Recording state machine (idle→countdown→recording→stopped) + countdown overlay + toolbar panel | Recording/ | A10, A12 |
| 7 | Save recording metadata to SwiftData (duration, dimensions, file size, thumbnail) | Data/, Recording/ | Storage |
| 8 | Library grid with click-to-play + real thumbnail loading | Library/ | C2, I5 |
| 9 | AVKit VideoPlayer in WindowGroup scene with @Query lookup | Player/ | G1 |

**Milestone:** Menu bar → Start Recording → 3-2-1 countdown → screen captured to MP4 → Stop → metadata + thumbnail saved → library shows recording → click opens player.

---

## Phase 2: All Recording Modes + Webcam — Complete

**Goal:** Screen+cam, window, region, audio, webcam bubble.

| # | Task | Module | Features |
|---|------|--------|----------|
| 10 | Window/region capture + multi-monitor (CaptureMode enum, SCContentFilter, SCContentSharingPicker) | Capture/ | A5-A7 |
| 11 | Region selection overlay window (RegionSelectionWindow with rubber-band NSPanel) | Capture/ | A6 |
| 12 | Camera service (AVCaptureSession wrapper with 720p, frame callback) | Capture/ | Webcam |
| 13 | Webcam bubble (circular, draggable, resizable NSPanel with sharingType=.none) | Capture/ | B1-B3 |
| 14 | Background blur via Vision segmentation (VNGeneratePersonSegmentationRequest + CIFilter) | Capture/ | B5 |
| 15 | Virtual backgrounds | Capture/ | B6 — **Deferred** |
| 16 | Mic + system audio capture (captureMicrophone on SCStreamConfiguration, live toggle) | Capture/ | A8, A9 |
| 17 | Dual-stream recording (WebcamRecorder AVAssetWriter, separate MP4, webcamFilePath) | Recording/ | A1 |
| 18 | Recording controls polish (mic/camera toggles in toolbar, 320px width, stop button) | Recording/ | C4 |

**Post-completion fix:** Replaced custom ContentPickerView (broken TCC) with Apple's SCContentSharingPicker.

---

## Phase 3: Compositing & Export Pipeline — Complete

**Goal:** Real-time composited video with webcam baked in, pause/resume, MP4 export.

| # | Task | Module | Features |
|---|------|--------|----------|
| 19 | RecordingSettings + VideoQuality enum (FPS, bitrate, device selection via @AppStorage) | Settings/ | J1-J2 |
| 20 | VideoWriter actor (AVAssetWriter, HEVC encoding, PTS normalization, dual audio inputs) | Compositing/ | Core |
| 21 | WebcamCompositor (real-time circular overlay via Metal-backed CIContext, dynamic position tracking) | Compositing/ | Composite |
| 22 | ScreenCaptureService refactor (SCRecordingOutput → SCStreamOutput per-frame pipeline) | Capture/ | A4 |
| 23 | RecordingCoordinator refactor (single-file composited output, no separate webcam file) | Recording/ | A1 |
| 24 | Pause/resume with segment-based recording + SegmentStitcher (AVMutableComposition) | Compositing/ | A11 |
| 25 | Export progress UI (ExportProgressWindow + PlayerView export dialog with quality picker) | Compositing/ | H2 |
| 26 | Settings UI (SettingsView with FPS, quality, mic/camera device pickers) | Settings/ | J1-J3 |

**Milestone:** Webcam overlay composited in real-time into single MP4. Pause/resume stitches segments. Export with quality selection. Settings persist via @AppStorage.

---

## Phase 4: Drawing & Annotations — Complete

**Goal:** Full annotation toolkit during recording with real-time burn-in.

| # | Task | Module | Features |
|---|------|--------|----------|
| 27 | Drawing canvas (pen, highlighter, arrow, line, rect, ellipse) + AnnotationCanvasWindow/View | Annotations/ | D1-D6 |
| 28 | Eraser, undo, color picker, stroke width + AnnotationToolbarPanel | Annotations/ | D7-D8 |
| 29 | Mouse click emphasis (ripple) via ClickEmphasisMonitor + CIRadialGradient | Annotations/ | D9 |
| 30 | Cursor spotlight via CursorSpotlightMonitor + CIRadialGradient dim overlay | Annotations/ | D10 |
| 31 | AnnotationRenderer: burn annotations into video frames via CoreImage (after webcam composite) | Annotations/ | D11 |

**Milestone:** Draw on screen during recording. Annotations burned into MP4 in real-time. Click emphasis and cursor spotlight. Undo/clear. Escape exits draw mode.

---

## Phase 5: Editor — Complete

**Goal:** Full post-recording non-destructive editing.

| # | Task | Module | Features |
|---|------|--------|----------|
| 32 | Timeline UI with scrubber + waveform (EditorTimelineView with Canvas-based waveform + thumbnails + playhead) | Editor/ | E4 |
| 33 | Trim from start/end (TrimHandlesView with yellow handles + grayed overlay) | Editor/ | E1 |
| 34 | Cut out sections (CutRegionOverlay with red hatched regions + context menu) | Editor/ | E2 |
| 35 | Stitch multiple clips (StitchPanelView with drag-to-reorder, EditorCompositionBuilder) | Editor/ | E3 |
| 36 | Speed adjustment (SpeedControlView popover, 0.25x–4x presets) | Editor/ | E5 |
| 37 | Thumbnail selection (ThumbnailPickerView with slider + "Use Current Frame" + PNG save) | Editor/ | E6 |
| 38 | GIF export via Rust gifski (gif_export.rs with PNG manifest + gifski encoder, GifExportService actor) | Rust export/, Editor/ | H3 |

**Milestone:** Non-destructive editor with EDL model. Trim, cut, stitch, speed, thumbnail. Export as MP4 or GIF. Editor window (1000x700) replaces simple player.

---

## Phase 6: AI Features — Complete

**Goal:** Auto transcription, titles, summaries, chapters, filler/silence detection.

| # | Task | Module | Features |
|---|------|--------|----------|
| 39 | Transcription client in Rust (OpenAI whisper-1 via reqwest multipart, verbose_json with word timestamps) | Rust ai/ | F1 |
| 40 | Provider-aware LLM client in Rust (gpt-4o-mini for title/summary/chapters) | Rust ai/ | F2-F4 |
| 41 | AI FFI bridge + Swift AIOrchestrator (actor pipeline: transcribe → fillers → title → summary → chapters → silence → persist) | Bridge/, AI/ | Wire up |
| 42 | Filler word detection from transcript (Rust, single + multi-word sliding window) | Rust audio/ | F5 |
| 43 | Silence detection (Rust + symphonia, RMS per 10ms window, configurable threshold/duration) | Rust audio/ | F6 |
| 44 | API key settings UI + file-based storage (SecureField, auto-transcribe toggle) | Settings/, AI/ | Config |

**Milestone:** Auto-transcription via whisper-1. LLM-generated title, summary, chapters. Filler word + silence detection. API key in file-based storage. Processing spinner on library cards.

---

## Phase 7: Player & Transcript — Complete

**Goal:** Rich playback experience integrated into editor.

| # | Task | Module | Features |
|---|------|--------|----------|
| 45 | Caption overlay (karaoke-style word-by-word highlight, phrase grouping, binary search lookup) | Editor/ | G2 |
| 46 | Transcript panel (right sidebar with FlowLayout, auto-scroll, click-to-seek, filler word styling) | Editor/ | G6 |
| 47 | Chapter navigation (popover list + timeline markers with accent color lines/triangles) | Editor/ | G7 |
| 48 | PiP + fullscreen (AVPictureInPictureController via VideoPreviewView Coordinator, NSWindow toggleFullScreen) | Editor/ | G4, G5 |

**Milestone:** Enhanced EditorView with captions, transcript sidebar, chapter navigation, PiP, and fullscreen. Karaoke-style word highlighting. Conditional button visibility.

---

## Phase 8: Library & Organization — Complete

**Goal:** Complete library management.

| # | Task | Module | Features |
|---|------|--------|----------|
| 49 | Folder management (create, rename, move, nest) — LibrarySidebarView with flat folder tree, context menus | Library/, Data/ | I2 |
| 50 | Tags/labels (create, assign, color) — TagEditorView with 8-preset color picker, bulk tagging | Library/, Data/ | I3 |
| 51 | Full-text search (.searchable modifier, title/summary/transcript SwiftData predicate filtering) | Library/ | I1 |
| 52 | Sort/filter (LibrarySortOrder enum with 7 options, TranscriptFilter, hover preview on cards) | Library/ | I4-I5 |
| 53 | Auto-copy file path + Show in Finder (context menus on video cards, Copy Path in editor toolbar) | Library/ | H1 |

**Additional work in this phase:** Fixed AVAssetExportSession deprecations, editor info sidebar panel, webcam unmirroring fix, accessibility permission prompt cleanup, waveform amplitude boost, audio queue separation, .help() tooltips.

**Milestone:** Organized library with folders, tags, search, sort/filter, context menus, bulk operations.

---

## Phase 9: Polish & Settings — Complete

**Goal:** Production-quality UX.

| # | Task | Module | Features |
|---|------|--------|----------|
| 54 | Global keyboard shortcuts (CGEvent tap, Cmd+Shift+R/P, ShortcutRecorderButton, UCKeyTranslate display) | App/ | C3, J5 |
| 55 | Launch at startup (SMAppService.mainApp register/unregister) | App/ | J4 |
| 56 | Notifications (UNUserNotificationCenter, recording-complete with "Open Library" action) | App/ | J7 |
| 57 | Noise cancellation (NoiseCancellationProcessor noise gate, RMS threshold -40dB on mic samples) | Capture/ | J8 |
| 58 | Welcome/onboarding screen (PermissionChecker + OnboardingView with live status polling) | App/ | J9 |
| 59 | Dark mode polish (Theme.swift semantic colors, 9 adaptive colors, System/Light/Dark picker) | App/ | J6 |
| 60 | Crash recovery + temp file cleanup (cleanupOrphanedTempFiles, scans /tmp) | App/ | J10 |
| 61 | Disk space monitoring (checkDiskSpace <1GB guard, storage summary in toolbar) | App/ | J11 |

**Milestone:** Global hotkeys, launch at startup, notifications, noise cancellation, onboarding, dark mode, crash recovery, disk monitoring.

---

## Phase 10: Recording Controls & Video Enhancements — Complete

**Goal:** Loom-style webcam controls and video enhancement features.

| # | Task | Module | Features |
|---|------|--------|----------|
| 84 | Floating control pill on webcam bubble (BubbleControlPill: stop/timer/pause/discard) | Recording/ | C1 |
| 85 | Webcam bubble background themes (8 solid/gradient themes, CAGradientLayer + CIContext ring) | Capture/ | B7 |
| 86 | Webcam shape options (circle, roundedRect, pill — shape-aware masking, right-click cycle) | Capture/ | B5 |
| 87 | Webcam image adjustments (brightness/contrast/saturation/highlights/shadows, CIColorControls) | Capture/ | B8 |
| 88 | Beauty / soft-focus filter | — | **Deferred to Phase 12** |
| 89 | Color temperature / white balance (CITemperatureAndTint, 2000–10000K) | Capture/ | B9 |
| 90 | Screen recording adjustments (brightness/contrast in EditorExportView, CIColorControls) | Editor/ | E7 |
| 91 | Discard recording (DiscardConfirmation alert, performDiscard cleanup) | Recording/ | C7 |
| 92 | Webcam-only recording mode (WebcamRecordingService, HEVC 720p, camera+mic) | Capture/ | A3 variant |

**Milestone:** Webcam shapes, themes, image adjustments, temperature/tint. Floating control pill. Discard recording. Webcam-only mode. Export adjustments.

---

## Phase 11: Cleanup & Tests — Complete

**Goal:** Code quality, test coverage, CI pipeline.

### Stage 1: Cleanup
| # | Task | Description |
|---|------|-------------|
| 62 | Dead code / TODO audit | No dead code, TODOs, or FIXMEs found |
| 63 | Force-unwrap cleanup | ~22 instances replaced with guard-let / nil-coalescing |
| 64 | Code organization | RecordingCoordinator split (1057→350 + 4 extensions), SettingsView split (604→24 + 5 tabs), LibraryView extracted 2 sheets |
| 65 | Memory leak audit | All [weak self] verified, CameraService.onFrame=nil on stop(), singletons confirmed safe |
| 66 | Accessibility pass | 30+ labels added across 8 files |

### Stage 2: Test Infrastructure
- project.yml: CloomTests (unit-test) + CloomUITests (ui-testing) targets
- Cargo.toml: wiremock + tokio dev-dependencies
- Test directories: CloomTests/, CloomUITests/, cloom-core/tests/fixtures/

### Stage 3: Rust Tests (43 tests, all passing)
| # | Task | Tests |
|---|------|-------|
| 67 | Transcription client tests | 6 tests (wiremock fixtures) |
| 68 | LLM client tests | 11 tests (parsing, truncation, validation) |
| 69 | Filler word tests | 12 tests (patterns, edge cases) |
| 70 | Silence detection tests | 5 tests (programmatic WAV generation) |
| 71 | GIF export tests | 7 tests (manifest, frames, progress) |

### Stage 4: Swift Tests (27 tests in 8 suites, all passing)
| # | Task | Tests |
|---|------|-------|
| 72 | SwiftData model tests | DataModelTests: VideoRecord, FolderRecord, TagRecord, EDL, Transcript, Chapter |
| 75 | RecordingSettings tests | RecordingSettingsTests: VideoQuality, defaults, invalid values |
| 76 | UI tests for recording flow | RecordingFlowUITests: menu bar, library, settings, recording |
| 77 | UI tests for settings | SettingsUITests: settings window |

**Milestone:** 43 Rust tests + 27 Swift tests pass. GitHub Actions CI pipeline. Build succeeds with 0 errors, 2 warnings.

---

## Phase 12: Code Quality & File Splitting — Not Started

**Goal:** Split large files into focused, single-responsibility modules. Target: no file over ~300 lines, no file with more than ~10 functions.

### Swift — High Priority (400+ lines)
| # | Task | File | Lines/Funcs |
|---|------|------|-------------|
| 93 | Split LibraryView — extract toolbar/filter, video grid, context menus | Library/ | 454 lines, 8 funcs |
| 94 | Split WebcamBubbleWindow — extract shape rendering, drag, size cycling | Capture/ | 420 lines, 17 funcs |
| 95 | Split AnnotationCanvasView — extract per-tool drawing, gesture handling | Annotations/ | 417 lines, 16 funcs |

### Swift — Medium Priority (300–400 lines)
| # | Task | File | Lines/Funcs |
|---|------|------|-------------|
| 96 | Split EditorView — extract toolbar, sidebar toggle, sub-view sections | Editor/ | 354 lines, 6 funcs |
| 97 | Split ScreenCaptureService — extract stream config, filter, delegate | Capture/ | 337 lines, 16 funcs |
| 98 | Split WebcamSettingsTab — extract preview and setting groups | Settings/ | 312 lines, 4 funcs |
| 99 | Split WebcamCompositor — extract shape masking, theme border rendering | Compositing/ | 305 lines, 9 funcs |
| 100 | Split RecordingCoordinator+UI — further decompose window management | Recording/ | 302 lines, 13 funcs |

### Rust — Medium Priority
| # | Task | File | Lines/Funcs |
|---|------|------|-------------|
| 101 | Split gif_export.rs — separate manifest, frame decoding, encoding | export/ | 371 lines, 11 fns |
| 102 | Split silence.rs — separate detection from WAV parsing, merging | audio/ | 335 lines, 8 fns |
| 103 | Split llm.rs — separate prompts, API client, response parsers | ai/ | 302 lines, 18 fns |

### General Cleanup
| # | Task | Description |
|---|------|-------------|
| 104 | Review unused imports, dead helpers, overly broad responsibilities | All modules |
| 105 | Ensure consistent error handling patterns across services | All modules |

---

## Phase 13: Advanced — Not Started

| # | Task | Module | Features |
|---|------|--------|----------|
| 78 | Local view analytics (track views, watch time) | Data/, Library/ | K1 |
| 79 | Timestamped comments | Editor/, Data/ | K2 |
| 80 | Performance optimization + profiling | All | K3 |
| 88 | Beauty / soft-focus filter (person segmentation + CIGaussianBlur skin smoothing) | Capture/ | K4 |

---

## Phase 14: Pre-Release — Not Started

| # | Task | Module | Features |
|---|------|--------|----------|
| 81 | Developer ID signing + notarization + DMG packaging | Build/Release | L1-L2 |
| 82 | App icon + branding assets | Resources/ | L3 |
| 83 | Release notes + changelog | Docs | L4 |
