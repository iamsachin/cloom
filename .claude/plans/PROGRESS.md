# Cloom — Implementation Progress

## Phase 1A: Project Skeleton
**Status:** Complete
**Commit:** `f34013e`
**Date:** 2026-02-11

- [x] Task 1 — Xcode project (xcodegen) + Cargo scaffold + build.sh + UniFFI hello-world
- [x] Task 2 — SwiftData models (VideoRecord, FolderRecord, TagRecord, etc.) + ModelContainer setup
- [x] Task 3 — Basic Rust lib.rs with exported functions + UniFFI proc macros
- [x] Task 4 — MenuBarExtra shell + empty library window

**Milestone verified:** App launches in menu bar. Rust FFI round-trip works. SwiftData container initialized.

---

## Phase 1B: Walking Skeleton (Record → Library → Play)
**Status:** Complete
**Commit:** `d3d1058`
**Date:** 2026-02-11

- [x] Task 5 — Full-screen recording via SCRecordingOutput (ScreenCaptureService + SCStreamOutput)
- [x] Task 6 — Recording state machine (idle → countdown → recording → stopping) + countdown overlay + toolbar panel
- [x] Task 7 — Save recording metadata to SwiftData (duration, dimensions, file size, thumbnail)
- [x] Task 8 — Library grid with click-to-play + real thumbnail loading
- [x] Task 9 — AVKit VideoPlayer in WindowGroup scene with @Query lookup

**Milestone verified:** Menu bar → Start Recording → 3-2-1 countdown → screen captured to ~/Desktop MP4 → Stop → metadata + thumbnail saved → library shows recording → click opens player.

---

## Phase 2: All Recording Modes + Webcam
**Status:** Complete
**Date:** 2026-02-11

- [x] Task 10 — Window/region capture + multi-monitor (CaptureMode enum, SCContentFilter per mode, SCContentSharingPicker)
- [x] Task 11 — Region selection overlay window (RegionSelectionWindow with rubber-band NSPanel)
- [x] Task 12 — Camera service (AVCaptureSession wrapper with 720p, frame callback)
- [x] Task 13 — Webcam bubble (circular, draggable, resizable NSPanel with sharingType=.none)
- [x] Task 14 — Background blur via Vision segmentation (VNGeneratePersonSegmentationRequest + CIFilter compositing)
- [ ] Task 15 — Virtual backgrounds (deferred to later phase)
- [x] Task 16 — Mic + system audio capture (captureMicrophone on SCStreamConfiguration, live toggle)
- [x] Task 17 — Dual-stream recording (WebcamRecorder AVAssetWriter, separate MP4, webcamFilePath on VideoRecord)
- [x] Task 18 — Recording controls polish (mic/camera toggles in toolbar, 320px width, stop button)

**Milestone:** All recording modes (full screen, window, region) work. Webcam bubble with background blur. Dual-stream recording. Mic toggle. Polished toolbar with mic/camera controls.

**Post-completion fix:** Replaced custom ContentPickerView (broken TCC permission flow) with Apple's SCContentSharingPicker — handles permissions automatically, no TCC pre-grant needed. Added `/build` CLI skill for catching compile errors without Xcode.

---

## Phase 3: Compositing & Export Pipeline
**Status:** Complete
**PR:** [#3](https://github.com/iamsachin/cloom/pull/3)
**Branch:** `feature/phase3-compositing-export`
**Date:** 2026-02-11

- [x] Task 19 — RecordingSettings + VideoQuality enum (FPS, bitrate, device selection via @AppStorage)
- [x] Task 20 — VideoWriter actor (AVAssetWriter, HEVC encoding, PTS normalization, dual audio inputs)
- [x] Task 21 — WebcamCompositor (real-time circular overlay via Metal-backed CIContext, dynamic position tracking)
- [x] Task 22 — ScreenCaptureService refactor (SCRecordingOutput → SCStreamOutput per-frame pipeline)
- [x] Task 23 — RecordingCoordinator refactor (single-file composited output, no separate webcam file)
- [x] Task 24 — Pause/resume with segment-based recording + SegmentStitcher (AVMutableComposition)
- [x] Task 25 — Export progress UI (ExportProgressWindow + PlayerView export dialog with quality picker)
- [x] Task 26 — Settings UI (SettingsView with FPS, quality, mic/camera device pickers)

**Milestone verified:** Webcam overlay composited in real-time into single MP4. Pause/resume stitches segments. Export with quality selection. Settings persist via @AppStorage. Permissions requested on app startup.

**Post-completion fixes:** Click-to-cycle bubble size (replaced jittery scroll resize), Loom-style shadow on webcam bubble, drag vs click detection via screen coordinates, TCC reset in build skill.

---

## Phase 4: Drawing & Annotations
**Status:** Complete
**Branch:** `feature/phase3-compositing-export`
**Date:** 2026-02-12

- [x] Task 27 — Drawing canvas (pen, highlighter, arrow, shapes) + AnnotationCanvasWindow/View with transparent NSPanel overlay
- [x] Task 28 — Eraser, undo, color picker, stroke width + AnnotationToolbarPanel with SwiftUI tool/color/width controls
- [x] Task 29 — Mouse click emphasis (ripple) via ClickEmphasisMonitor + CIRadialGradient expanding ring
- [x] Task 30 — Cursor spotlight via CursorSpotlightMonitor + CIRadialGradient dim overlay
- [x] Task 31 — AnnotationRenderer: burn annotations into export via CoreImage (composited in handleScreenFrame after webcam)

**Milestone verified:** Draw on screen during recording with pen/highlighter/arrow/line/rect/ellipse/eraser. Annotations burned into recorded MP4 in real-time. Click emphasis ripples and cursor spotlight toggle from toolbar. Undo/clear all. Escape key exits draw mode.

**Post-completion fixes:** Fixed toolbar z-order (recording + annotation toolbars above canvas via CGShieldingWindowLevel). Added Escape key to exit draw mode. Fixed real-time stroke rendering in video (active stroke pushed to store during drag, not just on mouse-up).

---

## Phase 5: Editor
**Status:** Complete
**Date:** 2026-02-12

- [x] Task 32 — Timeline UI with scrubber + waveform (EditorTimelineView with Canvas-based waveform peaks + thumbnail strip + red playhead)
- [x] Task 33 — Trim from start/end (TrimHandlesView with yellow drag handles + grayed-out overlay)
- [x] Task 34 — Cut out sections (CutRegionOverlay with red hatched regions + context menu to remove, EditorState skip logic)
- [x] Task 35 — Stitch multiple clips (StitchPanelView with drag-to-reorder, EditorCompositionBuilder concatenation)
- [x] Task 36 — Speed adjustment (SpeedControlView popover with 0.25x–4x presets, AVPlayer rate + composition scaleTimeRange)
- [x] Task 37 — Thumbnail selection (ThumbnailPickerView with slider + "Use Current Frame" + PNG save)
- [x] Task 38 — GIF export via Rust gifski (gif_export.rs with PNG manifest + gifski encoder, GifExportService Swift actor)

**Milestone verified:** Non-destructive editor with EDL model (EditDecisionList SwiftData). Trim, cut, stitch, speed, thumbnail. Export as MP4 (AVAssetExportSession on AVMutableComposition) or GIF (gifski via Rust FFI). Player replaced with editor window (1000x700).

---

## Phase 6: AI Features
**Status:** Complete
**Date:** 2026-02-21

- [x] Task 39 — Transcription client in Rust (OpenAI whisper-1 via reqwest multipart, verbose_json with word timestamps)
- [x] Task 40 — Provider-aware LLM client in Rust (gpt-4o-mini for title/summary/chapters via chat completions)
- [x] Task 41 — AI FFI bridge + Swift AIOrchestrator (actor pipeline: transcribe → fillers → title → summary → chapters → silence → persist)
- [x] Task 42 — Filler word detection from transcript (Rust, single + multi-word sliding window, unit tests)
- [x] Task 43 — Silence detection (Rust + symphonia, RMS per 10ms window, configurable threshold/duration)
- [x] Task 44 — API key settings UI + Keychain storage (SecureField, key prefix display, auto-transcribe toggle, remove button)

**Milestone verified:** Auto-transcription via OpenAI whisper-1 with word-level timestamps. LLM-generated title, summary, chapters (skipped if transcript too short). Filler word detection. Silence detection via symphonia. API key stored in Keychain. Processing spinner on library cards. Error alerts for pipeline failures. Background pipeline via Task.detached after recording.

---

## Phase 7: Player & Transcript
**Status:** Complete
**Date:** 2026-02-21

- [x] Task 45 — Caption overlay (karaoke-style word-by-word highlight, phrase grouping, binary search lookup)
- [x] Task 46 — Transcript panel (right sidebar with FlowLayout, auto-scroll, click-to-seek, filler word styling)
- [x] Task 47 — Chapter navigation (popover list + timeline markers with accent color lines/triangles)
- [x] Task 48 — PiP + fullscreen (AVPictureInPictureController via VideoPreviewView Coordinator, NSWindow toggleFullScreen)

**Milestone verified:** Enhanced EditorView with captions, transcript sidebar, chapter navigation, PiP, and fullscreen. Captions show karaoke-style word-by-word highlighting synced to playback. Transcript sidebar with click-to-seek and auto-scroll. Chapter markers on timeline + popover navigation. PiP via AVKit. Fullscreen toggle. All buttons conditionally shown (hidden when no transcript/chapters). Build succeeds.

---

## Phase 8: Library & Organization
**Status:** Complete
**Date:** 2026-02-21

- [x] Task 49 — Folder management (create, rename, move, nest) — LibrarySidebarView with flat folder tree, context menus, move videos
- [x] Task 50 — Tags/labels (create, assign, color) — TagEditorView with 8-preset color picker, sidebar tag section, tag pills on VideoCardView
- [x] Task 51 — Full-text search (.searchable modifier, title/summary/transcript filtering)
- [x] Task 52 — Sort/filter (LibrarySortOrder enum with 7 options, TranscriptFilter, hover preview on cards)
- [x] Task 53 — Auto-copy file path + Show in Finder (context menus on video cards, Copy Path in editor toolbar)

**Additional fixes in this session:**
- Fixed 5 warnings in AIOrchestrator (removed unnecessary `await`, replaced deprecated `AVAssetExportSession` APIs with `export(to:as:) async throws`)
- Summary tooltip on hover in VideoCardView + summary improved to `.secondary` color and 2-line limit
- Editor info sidebar panel (title, full summary, metadata) toggled via `(i)` button in right sidebar
- Webcam unmirrored in both live preview bubble and recorded video (horizontal flip with correct CIImage extent)
- Accessibility permission prompt moved to app startup (`CloomApp.init`); monitors check silently
- API key storage switched from Keychain to `~/Library/Application Support/Cloom/api_key` (file-based, `chmod 600`) — eliminates repeated Keychain prompts on debug rebuilds
- Waveform amplitude boost: peaks normalized relative to loudest peak + `sqrt` curve for quiet speech visibility
- Audio recording fix: separated audio onto dedicated `audioQueue` so annotation rendering on video queue doesn't stutter/block audio
- Added `.help()` tooltips to all editor toolbar buttons (Play, Stitch, Export) and recording toolbar (Stop)

**Milestone verified:** Organized library with interactive sidebar (folders + tags), full-text search, 7 sort options, transcript filter, video context menus (copy path, show in Finder, move to folder, tags, delete), bulk operations (move, tag, delete), hover preview effect on cards. Build succeeds with 0 code warnings.

---

## Phase 9: Polish & Settings
**Status:** Complete
**Date:** 2026-02-22

- [x] Task 54 — Global keyboard shortcuts (CGEvent tap, Cmd+Shift+R toggle recording, Cmd+Shift+P toggle pause, ShortcutRecorderButton in Settings, UCKeyTranslate display strings, UserDefaults persistence)
- [x] Task 55 — Launch at startup (SMAppService.mainApp register/unregister, toggle in Settings > General, state synced on appear)
- [x] Task 56 — Notifications (UNUserNotificationCenter, recording-complete with "Open Library" action, AppDelegate as notification center delegate, notificationsEnabled toggle, guards on AI orchestrator notifications)
- [x] Task 57 — Noise cancellation (NoiseCancellationProcessor noise gate, RMS threshold -40dB, processes mic CMSampleBuffers, toggle in Settings > Microphone, noiseCancellationEnabled in RecordingSettings)
- [x] Task 58 — Welcome/onboarding screen (PermissionChecker + OnboardingView with live status polling for Screen Recording, Camera, Microphone, Accessibility; auto-opens on launch if any missing; "Complete Setup..." in menu bar; removed old scattered permission requests from AppState/CloomApp.init)
- [x] Task 59 — Dark mode polish (Theme.swift semantic Color extensions with NSColor dynamic provider, 9 adaptive colors, updated 6 view files, appearance picker System/Light/Dark in Settings, applied on launch via AppDelegate)
- [x] Task 60 — Crash recovery + temp file cleanup (cleanupOrphanedTempFiles in AppState.init, scans /tmp for cloom_segment_* and cloom_audio_*)
- [x] Task 61 — Disk space monitoring (checkDiskSpace <1GB guard in beginCapture, storage summary "{count} videos · {size}" in LibraryView toolbar)

---

## Phase 10: Recording Controls & Video Enhancements
**Status:** Complete
**Date:** 2026-02-22

### Webcam Bubble Controls (Loom-style)
- [x] Task 84 — Floating control pill on webcam bubble (BubbleControlPill NSPanel, stop/timer/pause/discard, child window attached to bubble)
- [x] Task 85 — Webcam bubble emoji frames (3 decorative emoji frames: geometric/tropical/celebration — rendered as CATextLayer in live bubble + cached CGImage in compositor; replaced old solid/gradient color themes)
- [x] Task 86 — Webcam shape options (circle, roundedRect, pill — WebcamShape enum, shape-aware masking with CGContext cache, right-click to cycle)

### Video Enhancement Controls
- [x] Task 87 — Webcam image adjustments (brightness, contrast, saturation, highlights, shadows — WebcamImageAdjuster with CIColorControls + CIHighlightShadowAdjust, thread-safe via OSAllocatedUnfairLock)
- [ ] Task 88 — Beauty / soft-focus filter — **Deferred to Phase 12** (removed in polish pass)
- [x] Task 89 — Color temperature / white balance (CITemperatureAndTint filter, 2000–10000K range, integrated into WebcamImageAdjuster pipeline)
- [x] Task 90 — Screen recording adjustments (brightness/contrast sliders in EditorExportView, AVMutableVideoComposition with CIColorControls filter)

### Recording UX
- [x] Task 91 — Discard recording (DiscardConfirmation alert, performDiscard cleanup, trash button in toolbar + menu bar)
- [x] Task 92 — Webcam-only recording mode (WebcamRecordingService with AVAssetWriter, HEVC 720p, camera+mic, image adjustments + beauty + blur applied)

### New Files
- `CloomApp/Sources/Recording/DiscardConfirmationWindow.swift`
- `CloomApp/Sources/Capture/WebcamImageAdjustments.swift`
- `CloomApp/Sources/Capture/WebcamShape.swift`
- `CloomApp/Sources/Capture/WebcamFrame.swift`
- `CloomApp/Sources/Capture/EmojiFrameRenderer.swift`
- `CloomApp/Sources/Recording/BubbleControlPill.swift`
- `CloomApp/Sources/Capture/WebcamRecordingService.swift`

### New @AppStorage Keys
- `webcamBrightness`, `webcamContrast`, `webcamSaturation`, `webcamHighlights`, `webcamShadows` (image adjustments)
- `webcamTemperature`, `webcamTint` (color temperature)
- `webcamShape` (circle/roundedRect/pill)
- `webcamFrame` (none/geometric/tropical/celebration)
**Milestone verified:** Build succeeds (0 errors, 2 warnings). Discard button in toolbar + menu bar. Webcam settings section in Settings (shape, adjustments, temperature, tint, theme swatches). Shape-aware masking in compositor. Floating control pill on webcam bubble. Webcam-only recording mode. Export brightness/contrast adjustments.

### Post-completion polish
- Fixed pill shape not reflected in Settings preview (now shape-aware dimensions with aspect ratio)
- Added click-to-reset on individual slider values (accent-colored when non-default, click to restore)
- Added emoji frame preview to Settings webcam tab (positioned emoji stickers around camera preview)
- Removed beauty filter (BeautyFilter.swift deleted, all references cleaned up) — deferred to Phase 12
- Improved onboarding: longer permission descriptions, Accessibility made optional with warning

---

## Phase 11: Cleanup & Tests
**Status:** Complete
**Date:** 2026-02-22

### Stage 1: Cleanup
- [x] Task 62 — Dead code / TODO audit — no dead code, TODOs, or FIXMEs found
- [x] Task 63 — Force-unwrap cleanup (~22 instances replaced with guard-let / nil-coalescing)
- [x] Task 64 — Code organization — RecordingCoordinator split (1057→350 lines + 4 extensions), SettingsView split (604→24 lines + 5 tabs), LibraryView extracted 2 sheets
- [x] Task 65 — Memory leak audit — all [weak self] verified, CameraService.onFrame=nil on stop(), singleton patterns confirmed safe
- [x] Task 66 — Accessibility pass — 30+ labels added across 8 files (toolbar, annotations, library, editor, settings)

### Stage 2: Test Infrastructure
- [x] project.yml — CloomTests (unit-test) target with GENERATE_INFOPLIST_FILE
- [x] Cargo.toml — wiremock + tokio dev-dependencies
- [x] Test directories — CloomTests/, cloom-core/tests/fixtures/

### Stage 3: Rust Tests (43 tests, all passing)
- [x] Task 67 — Transcription client tests (6 tests: file not found, file too large, response parsing, no words, empty words, MIME detection, wiremock fixture)
- [x] Task 68 — LLM client tests (11 tests: parse_chapters valid/code-fenced/bare-fence/invalid/empty/unique-ids, truncate_transcript short/long/boundary, validate_provider OpenAI/Claude)
- [x] Task 69 — Filler word tests (12 tests: extended from 4 — punctuation, all singles, all multis, clean speech, consecutive, single word, sorting, count)
- [x] Task 70 — Silence detection tests (5 tests: file not found, all silent, sine wave, silence between tones, below min duration — programmatic WAV generation)
- [x] Task 71 — GIF export tests (7 tests: empty manifest, manifest not found, single/multi frame, progress callback, PNG RGBA/RGB loading)

### Stage 4: Swift Tests (27 tests in 8 suites, all passing)
- [x] Task 72 — SwiftData model tests (DataModelTests.swift: VideoRecord CRUD/defaults/unique ID, FolderRecord hierarchy/videoCount, TagRecord relationship/color, EDL defaults/cuts/stitch/hasEdits, TranscriptRecord words/defaults, ChapterRecord properties)
- [x] Task 75 — RecordingSettings tests (RecordingSettingsTests.swift: VideoQuality bitrates/labels/identifiable/allCases, RecordingSettings defaults/custom/invalid raw value)
- ~~Task 76 — UI tests for recording flow~~ (removed — MenuBarExtra not hittable + TCC blocks all core functionality)
- ~~Task 77 — UI tests for settings~~ (removed — same TCC limitations)

**Milestone verified:** 43 Rust tests pass (cargo test). 27 Swift tests in 8 suites pass (xcodebuild test). Build succeeds (0 errors, 2 warnings).

---

## Phase 12: Code Quality & File Splitting
**Status:** Complete
**Date:** 2026-02-25

Split large files into focused, single-responsibility modules following best practices. Target: no file over ~300 lines, no file with more than ~10 functions.

### Group 1: Swift — High Priority (400+ lines) — COMPLETE
**Commit:** `c7ec67b`

- [x] Task 93 — Split `LibraryView.swift` (454→~230 lines) — extracted `LibraryFilterModels.swift` (enums), `LibraryVideoGrid.swift` (grid item, context menu, selection badge)
- [x] Task 93b — Split `RecordingCoordinator.swift` (383→~210 lines) — extracted `RecordingCoordinator+Toggles.swift` (6 toggle methods), `RecordingCoordinator+PauseResume.swift` (pause/resume/segment management)
- [x] Task 93c — Split `AIOrchestrator.swift` (344→~275 lines) — extracted `AudioExtractor.swift` (audio extraction from MP4)
- [x] Task 94 — Split `WebcamBubbleWindow.swift` (420→~160 lines) — extracted `BubbleContentView.swift` (NSView click/drag), `BubbleLayerBuilder.swift` (panel creation, emoji frame, rebuild)
- [x] Task 95 — Split `AnnotationCanvasView.swift` (417→~95 lines) — extracted `AnnotationCanvasRenderer.swift` (all drawing), `AnnotationInputHandler.swift` (mouse events, eraser)

### Group 2: Swift — Medium Priority (300–400 lines) — COMPLETE
- [x] Task 96 — Split `EditorView.swift` (354→~120 lines) — extracted `EditorToolbarView.swift` (playback/cut/chapter/export controls), `EditorInfoPanel.swift` (info sidebar)
- [x] Task 97 — Split `ScreenCaptureService.swift` (337→~115 lines) — extracted `ScreenCaptureService+Configuration.swift` (filter builder, stream config, CaptureError), `ScreenCaptureService+StreamOutput.swift` (SCStreamOutput/Delegate)
- [x] Task 98 — Split `WebcamSettingsTab.swift` (312→~280 lines) — extracted `LabeledSlider.swift` to `Shared/` as reusable component
- [x] Task 99 — Split `WebcamCompositor.swift` (305→~155 lines) — extracted `WebcamCompositor+ShapeMask.swift` (shape mask generation + cache), `WebcamCompositor+EmojiFrame.swift` (emoji frame rendering + cache)
- [x] Task 100 — Split `RecordingCoordinator+UI.swift` (302→~105 lines) — extracted `RecordingCoordinator+Annotations.swift` (canvas/toolbar management), `RecordingCoordinator+Webcam.swift` (webcam start/stop/preview/adjustments)

### Group 3: Rust — Test Extraction — COMPLETE
- [x] Task 101 — Extract tests from `gif_export.rs` (371→~175 lines) to `gif_export_tests.rs` via `#[path]` attribute
- [x] Task 102 — Extract tests from `silence.rs` (335→~175 lines) to `audio/silence_tests.rs` via `#[path]` attribute
- [x] Task 103 — Extract tests from `llm.rs` (302→~210 lines) to `ai/llm_tests.rs` via `#[path]` attribute

### Group 4: General Cleanup — COMPLETE
- [x] Task 104 — Removed dead `shapeObserver` property and cleanup code from `WebcamBubbleWindow.swift` (never assigned, always nil)
- [x] Task 105 — Reviewed error handling patterns; inconsistencies noted but left as-is (functional behavior, not code quality issue)

**Milestone verified:** Build succeeds (0 errors, 1 pre-existing deprecation warning). 43 Rust tests pass. 12 new files created, 8 existing files slimmed. No file over ~280 lines.

---

## Phase 13: Bookmarks + Performance Audit
**Status:** Complete
**Date:** 2026-02-25

### Bookmarks Feature
- [x] Task 79 — BookmarkRecord SwiftData model + VideoRecord relationship (cascade delete)
- [x] Task 79b — EditorState bookmark logic (BookmarkSnapshot value type, CRUD methods in extension)
- [x] Task 79c — Timeline bookmark markers (green diamonds + vertical lines in EditorTimelineView)
- [x] Task 79d — BookmarksPanelView (add/edit/delete, seek on click, highlight near-current-time rows)
- [x] Task 79e — Editor integration (toolbar bookmark toggle, "B" key shortcut, panel in HStack)

### Performance Fixes
- [x] Task 80a — Async thumbnail loading (NSCache + Task.detached in VideoCardView, eliminates sync disk I/O per card)
- [x] Task 80b — Frame dropout detection (isProcessingFrame guard in ScreenCaptureService, prevents queue backup)
- [x] Task 80c — Waveform maxPeak optimization (moved peaks.max() outside Canvas closure, eliminates O(n) per playhead tick)
- [x] Task 80d — Cache caption phrases & transcript sentences in EditorState (computed once at init, not every ~33ms)
- [x] Task 80e — Cache storage summary in LibraryView (computed on appear + video count change, not every toolbar render)

### Tests
- [x] BookmarkRecord unit tests (5 tests: properties, note, relationship, cascade delete, CRUD)

### Skipped
- Task 78 — Local view analytics — skipped (no value without shared links)

**Milestone verified:** 32 Swift tests pass (including 5 new BookmarkRecord tests). 43 Rust tests pass. Build succeeds (0 errors, 2 pre-existing warnings). Bookmarks work end-to-end. Performance fixes applied for 5 high-impact issues.

---

## Phase 14: App Icon & Branding
**Status:** Complete
**Date:** 2026-02-25

- [x] Task 82 — App icon (1024x1024 master + all required sizes for Assets.xcassets/AppIcon.appiconset)
- [x] Task 82b — Menu bar icon (18x18 + 36x36 template images for MenuBarExtra, play triangle + record dot)
- [ ] Task 82c — DMG background / installer branding assets — **Deferred to Phase 15** (requires DMG packaging workflow)

### Details
- Source icon: user-provided 1024x1024 PNG (play button with gradient border + record dot)
- Trimmed white background, centered on transparent canvas with slight padding
- Generated 7 icon PNGs (16, 32, 64, 128, 256, 512, 1024px) via ImageMagick resize
- Updated `AppIcon.appiconset/Contents.json` with all 10 macOS icon slots mapped
- Created `MenuBarIcon.imageset` with template rendering intent (black-on-transparent play+dot)
- Switched `MenuBarExtra` from `systemImage: "record.circle"` to custom `image: "MenuBarIcon"`

**Milestone verified:** Build succeeds (0 errors, 2 pre-existing warnings). App icon set complete with all macOS sizes. Custom menu bar icon with template rendering.

---

## Phase 15: Audio Export Fixes & Subtitle Embedding
**Status:** Complete
**PR:** [#19](https://github.com/iamsachin/cloom/pull/19)
**Branch:** `feature/audio-export-fix-subtitles`
**Date:** 2026-02-25

### Bug Fixes
- [x] Task 107–109 — Fix audio export (silent output, missing tracks, web player compat) — see [BUGS.md #19](BUGS.md#19--audio-export-bugs-silent-output-missing-tracks)

### Subtitle Embedding Feature
- [x] Task 110 — SubtitleExportService actor: SubtitleMode enum (none/hardBurn/srtSidecar/both), EDL-aware phrase timing (trim/cuts/speed), SRT generation, pre-rendered image cache for hard-burn
- [x] Task 111 — Export UI: subtitle mode picker (shown when transcript exists), hard-burn integration into CIFilter pipeline, SRT sidecar generation after export
- [x] Task 112 — Sendable conformance: TranscriptWordSnapshot, CaptionPhrase, CutRange
- [x] Task 113 — Performance: pre-render all subtitle images once before export + CGBitmapContext direct rendering (replaces slow NSImage→TIFF→CGImage per-frame pipeline)

### New Files
- `CloomApp/Sources/Editor/SubtitleExportService.swift`

**Milestone verified:** Build succeeds (0 errors, 3 warnings). Multi-track audio exported correctly. Raw recordings play in web players (Slack). Hard-burn subtitles render at correct times. SRT sidecar generated alongside MP4. Export speed comparable to non-subtitle export.

---

## Phase 16: Mic Sensitivity Setting
**Status:** Complete
**Date:** 2026-02-26

- [x] Task 106 — Mic sensitivity slider in Settings > Microphone (configurable waveform noise floor threshold, @AppStorage persistence, applies to WaveformGenerator adaptive noise floor)

---

## Phase 17: Performance & Code Quality Audit
**Status:** Complete
**Date:** 2026-02-26

### Phase 1: Recording Hot Path — Critical Fixes
- [x] Task 114 — SharedCIContext singleton (consolidated 6 CIContext instances into 1 shared Metal-backed context)
- [x] Task 115 — PersonSegmenter throttling (Vision runs every 5th frame with cached mask reuse)
- [x] Task 116 — MicLevelMonitor Task flood fix (replaced ~94 Task{@MainActor}/sec with 30Hz timer)
- [x] Task 117 — ScreenCaptureService data race fix (OSAllocatedUnfairLock<CaptureState> for 6 shared properties)
- [x] Task 118 — VideoWriter force unwrap removal (guard let instead of firstVideoPTS!)

### Phase 2: Async Annotation Rendering
- [x] Task 119 — Cached stroke overlay in AnnotationRenderer (skip CGContext when stroke count unchanged)

### Phase 3: Export Speed Fixes
- [x] Task 120 — GIF export: direct CGImage→PNG via ImageIO + 100ms frame tolerance
- [x] Task 121 — Streaming waveform peaks: O(peakCount) memory instead of O(total_samples)
- [x] Task 122 — Subtitle render to capsule-sized CGContext (~400x40px vs full 1920x1080)

### Phase 4: Rust Performance Fixes
- [x] Task 123 — Shared Tokio runtime via LazyLock (no more per-call thread pool)
- [x] Task 124 — Pre-computed lowercase in filler detection (eliminates ~90k redundant allocations)
- [x] Task 125 — Vec pre-allocation in silence detection

### Phase 5: Crash Prevention
- [x] Task 126 — Thumbnail NSCache limits (100 items / 100MB)

### Phase 6: AI Pipeline & Code Quality
- [x] Task 127 — Parallel AI tasks via async let (title/summary/chapters ~2/3 wall-clock reduction)
- [x] Task 128 — Library search 300ms debounce

**Milestone verified:** Build succeeds (0 errors, 1 warning). 43 Rust tests pass. 23 files changed across Swift and Rust.

---

## Phase 18: Single-Window Layout + Visual Redesign
**Status:** Complete
**Date:** 2026-02-27

### Phase 1: Navigation Foundation
- [x] Created NavigationState (@Observable, library/editor mode, grid/list view style, UserDefaults persistence)
- [x] Created MainWindowView (NavigationSplitView root, sidebar + detail mode switch, Escape key back)
- [x] Created LibraryContentView (extracted from LibraryView — filtering, sorting, search, grid/list rendering)
- [x] Created EditorContentView (wraps editor with back button, auto-navigate on video deletion)
- [x] Updated CloomApp.swift (removed Editor WindowGroup, single Window with MainWindowView)
- [x] Updated LibraryVideoGrid.swift (re-targeted to LibraryContentView, replaced openWindow with navigationState)
- [x] Deleted LibraryView.swift + EditorView.swift (replaced by new files)

### Phase 2: List View + View Toggle
- [x] Created LibraryListRowView (compact row: thumbnail, title, duration, date, tags)
- [x] Added grid/list segmented picker to toolbar
- [x] List view with hover highlight, context menus, selection mode support

### Phase 3: Visual Redesign
- [x] Redesigned VideoCardView (duration badge overlay, cleaner typography, subtle hover brightness)
- [x] Added Theme colors (durationBadge, listRowHover, cardBackgroundSubtle)
- [x] Updated ProcessingCardView to match new card style
- [x] Tag pills: max 2 shown, thinner capsules

### Phase 4: Polish + Cleanup
- [x] Deleted legacy PlayerView.swift + Player/ directory
- [x] Added opacity transitions between Library ↔ Editor
- [x] Edge case: video deleted while in editor → auto-navigate back to library
- [x] Escape key returns to library from editor
- [x] ViewStyle persisted to UserDefaults
- [x] Ran xcodegen generate for new files
- [x] Updated plan docs (02-project-structure.md, 05-swift-modules.md)

### New Files
- `CloomApp/Sources/App/NavigationState.swift`
- `CloomApp/Sources/App/MainWindowView.swift`
- `CloomApp/Sources/Library/LibraryContentView.swift`
- `CloomApp/Sources/Library/LibraryListRowView.swift`
- `CloomApp/Sources/Editor/EditorContentView.swift`

### Deleted Files
- `CloomApp/Sources/Library/LibraryView.swift`
- `CloomApp/Sources/Editor/EditorView.swift`
- `CloomApp/Sources/Player/PlayerView.swift`

**Milestone verified:** Build succeeds (0 errors, 1 warning). Single-window navigation with library ↔ editor mode switching. Grid/list toggle. Visual redesign with duration badges, clean typography, subtle hover effects. Back navigation via chevron button, Cmd+[, or Escape. Sidebar visible in both modes.

---

## Phase 19: Pre-Recording Setup Flow
**Status:** Complete
**Date:** 2026-02-27

- [x] Task 129 — Add "ready" state to RecordingState (new `.ready` case + `isReady` computed property)
- [x] Task 130 — Update RecordingCoordinator to enter ready state on "Start Recording" (`beginPreRecordingFlow()` → `.ready` state, `showReadyToolbar()`, webcam preview if camera enabled; skips screen capture permission check for webcam-only mode)
- [x] Task 131 — Add record button to recording toolbar (ReadyToolbarContentView with green "Ready" indicator, mic/camera/annotations/click-emphasis/spotlight toggles, red circle record button, cancel X button; `showReady()` method on RecordingToolbarPanel)
- [x] Task 132 — Camera preview in ready state (`startWebcam()` called in ready state; `toggleCamera()` updated to work in `.ready` state without touching capture service)
- [x] Task 133 — Cancel from ready state (`cancelReadyState()` stops webcam, dismisses toolbar, cleans up annotations, returns to `.idle`)
- [x] Task 134 — Update menu bar and global hotkeys (Cmd+Shift+R: idle → ready → recording → stop; menu bar shows "Start Recording" + "Cancel Setup" in ready state; `menuStatusText` shows "Ready to record...")

### Additional Changes
- [x] Removed BubbleControlPill from webcam bubble (no longer needed — controls are on the toolbar)
- [x] Fixed onboarding window not auto-presenting after TCC reset (`.defaultLaunchBehavior` now checks `permissionChecker.requiredGranted` in addition to `hasCompletedOnboarding`)

### Files Modified
- `RecordingState.swift` — added `.ready` case + `isReady`
- `RecordingCoordinator.swift` — added `confirmRecording()`, `cancelReadyState()`; removed `bubbleControlPill` property + dismiss calls
- `RecordingCoordinator+Capture.swift` — `beginPreRecordingFlow()` → `.ready` state; extracted `enterReadyState()` helper; removed pill creation from `beginWebcamOnlyCapture()`
- `RecordingCoordinator+UI.swift` — added `showReadyToolbar()`; removed pill dismiss from `performDiscard()`
- `RecordingCoordinator+Toggles.swift` — toggles work in `.ready` state (preview only)
- `RecordingCoordinator+Webcam.swift` — removed pill dismiss from `stopWebcam()`
- `RecordingCoordinator+CaptureDelegate.swift` — removed pill creation from `captureDidStart()` + dismiss from `captureDidFail()`
- `RecordingToolbarPanel.swift` — added `showReady()` + `ReadyToolbarContentView`
- `CloomApp.swift` — ready state menu bar branch; fixed onboarding `.defaultLaunchBehavior`
- `AppState.swift` — `confirmRecording()` / `cancelReadyState()` passthroughs; hotkey update

**Milestone verified:** Build succeeds (0 errors, 1 pre-existing warning). Start Recording → Ready toolbar → toggle controls → click record → countdown → capture. Cancel returns to idle. Hotkeys cycle correctly. Onboarding auto-presents when permissions missing.

---

## Phase 20: Long Recording Stress Test
**Status:** Complete
**Date:** 2026-02-27

9 fixes across 4 waves to ensure Cloom survives 30-minute recordings. See [BUGS.md #28](BUGS.md#28--long-recording-stress-test-failures) for details.

### Wave 1: Recording Pipeline Fixes (6 issues)
- [x] Reuse compositor/renderer on pause/resume, bounded cache eviction, audio buffering, frame drop logging, segment cleanup
- [x] CacheTests.swift — 5 tests for FrameImageCache and ShapeMaskCache eviction

### Wave 2: Waveform Generator Rewrite
- [x] Single-pass streaming waveform with O(peakCount) memory

### Wave 3: Whisper Audio Chunking
- [x] Split audio into <20MB chunks for transcription of long recordings
- [x] 3 new Rust tests

### Wave 4: Recording Instrumentation
- [x] RecordingMetrics class — frame/drop counts, segments, peak memory, periodic summaries

### Files Changed
| Wave | Modified | Created |
|------|----------|---------|
| 1 | RecordingCoordinator+PauseResume.swift, SegmentStitcher.swift, AppState.swift, WebcamCompositor+EmojiFrame.swift, WebcamCompositor+ShapeMask.swift, VideoWriter.swift | CloomTests/CacheTests.swift |
| 2 | WaveformGenerator.swift | — |
| 3 | transcribe.rs, AudioExtractor.swift, AIOrchestrator.swift | — |
| 4 | RecordingCoordinator+CaptureDelegate.swift, RecordingCoordinator.swift, RecordingCoordinator+Capture.swift, RecordingCoordinator+PauseResume.swift, VideoWriter.swift, ScreenCaptureService.swift | RecordingMetrics.swift |

**Milestone verified:** Build succeeds (0 errors, 1 warning). 45 Rust tests pass (3 new). 37 Swift tests pass (5 new cache tests). All 4 waves implemented.

---

## Phase 21: Google Drive Integration
**Status:** Complete
**Date:** 2026-02-27

Manual upload-to-Google-Drive with shareable links. Google Sign-In SDK for OAuth, Swift actor for resumable uploads, file-based token backup via SDK Keychain.

- [x] Task 150 — Data model: 4 optional cloud fields on VideoRecord (driveFileId, shareUrl, uploadStatus, uploadedAt) + UploadStatus enum
- [x] Task 145 — Google OAuth: GoogleSignIn-iOS SPM package, GoogleAuthConfig, GoogleAuthService (@Observable @MainActor singleton), onOpenURL handler, session restore in AppDelegate
- [x] Task 149 — Settings > Cloud tab: OAuth Client ID TextField, Google account connect/disconnect, status display
- [x] Task 146 — DriveUploadService actor: resumable upload with 5MB chunks, retry with exponential backoff, share link creation, file deletion; DriveUploadManager (@Observable @MainActor singleton) coordinates uploads with progress tracking
- [x] Task 147 — Upload integrated into Export sheet: "Upload to Drive" button in EditorExportView (exports with settings then uploads), library context menu retains raw upload
- [x] Task 148 — Cloud status indicators: VideoCardView (green link icon / progress / red error), LibraryListRowView (same), EditorInfoPanel (Cloud section with share link + copy button + upload date)

### New Files (7)
- `CloomApp/Sources/Data/UploadStatus.swift`
- `CloomApp/Sources/Cloud/GoogleAuthConfig.swift`
- `CloomApp/Sources/Cloud/GoogleAuthService.swift`
- `CloomApp/Sources/Cloud/DriveUploadService.swift`
- `CloomApp/Sources/Cloud/DriveUploadManager.swift`
- `CloomApp/Sources/Settings/CloudSettingsTab.swift`
- `CloomTests/CloudTests.swift`

### Deleted Files (1)
- `CloomApp/Sources/Cloud/ShareUploadButton.swift` — merged into EditorExportView

### Modified Files (12)
- `VideoModel.swift` (+4 optional fields)
- `project.yml` (+GoogleSignIn SPM package)
- `Info.plist` (+CFBundleURLTypes for OAuth)
- `CloomApp.swift` (+onOpenURL, +restoreSession)
- `SettingsView.swift` (+Cloud tab)
- `EditorToolbarView.swift` (-ShareUploadButton, upload moved to export sheet)
- `EditorExportView.swift` (+Upload to Drive button, progress, success state)
- `DriveUploadManager.swift` (+uploadExportedFile, refactored shared performUpload)
- `LibraryVideoGrid.swift` (+context menu items)
- `VideoCardView.swift` (+cloud status icon)
- `LibraryListRowView.swift` (+cloud icon)
- `EditorInfoPanel.swift` (+cloud section)
- `DataModelTests.swift` (+cloud field tests)

**Milestone verified:** Build succeeds (0 errors, 1 warning). Data model extended. OAuth flow configured. Upload service with resumable chunks. Upload merged into Export sheet (exports with settings then uploads to Drive). Library context menu retains raw upload. Status indicators on cards/list/info panel. 6 new unit tests.

---

## Phase 22: Export Speed Optimization
**Status:** Complete
**Date:** 2026-02-28

### Quick Fixes
- [x] Task 151 — Use SharedCIContext in export (replaced throwaway CIContext with SharedCIContext.instance singleton)

### Passthrough Export
- [x] Task 152 — Passthrough detection for unmodified exports (isExportUnmodified() checks trim/cuts/speed/brightness/contrast; unmodified + no subs → FileManager.copyItem; unmodified + subs → ExportWriter.remuxWithSubtitles)

### Subtitle Overhaul
- [x] Task 153 — Replace hard-burn + SRT with embedded tx3g subtitle track (ExportWriter enum with static methods for remux + edited export; tx3g binary format with CMSampleBuffer; simplified UI to "Include Subtitles" toggle)
- [x] Task 156 — Clean up SubtitleExportService (removed SubtitleMode enum, hard-burn rendering, SRT generation, CIImage compositing; kept SubtitlePhrase, buildPhrases, mapToCompositionTime; ~241 lines → ~80 lines)

### Parallelization
- [x] Task 154 — Parallel GIF frame extraction (sliding window of 8 concurrent tasks via withThrowingTaskGroup; SendableGenerator wrapper for thread-safe AVAssetImageGenerator access)
- [x] Task 155 — Parallel segment metadata loading in SegmentStitcher (withThrowingTaskGroup loads all segment durations + tracks concurrently, sorted by index for sequential insertion)

### New Files
- `CloomApp/Sources/Editor/ExportWriter.swift`

### Modified Files
- `CloomApp/Sources/Editor/EditorExportView.swift` — subtitle toggle, passthrough detection, ExportWriter integration, removed hard-burn/SRT code
- `CloomApp/Sources/Editor/SubtitleExportService.swift` — removed SubtitleMode, hard-burn, SRT, rendering code (~241→80 lines)
- `CloomApp/Sources/Editor/GifExportService.swift` — parallel frame extraction with sliding window
- `CloomApp/Sources/Compositing/SegmentStitcher.swift` — parallel segment metadata loading

**Milestone verified:** Build succeeds (0 errors, 53 pre-existing warnings). Passthrough for unmodified exports (instant file copy). Embedded tx3g subtitles (no re-encode for unmodified). Parallel GIF and segment loading.

---

## Phase 23: Open Source Readiness & Code Quality Overhaul
**Status:** Complete
**Date:** 2026-02-28

### Task 1: Remove GIF Export (AGPL blocker)
- [x] Deleted `gif_export.rs`, `gif_export_tests.rs`, `GifExportService.swift`
- [x] Removed `gifski`, `imgref`, `rgb`, `png` from Cargo.toml dependencies
- [x] Removed `mod gif_export` and `pub use gif_export::*` from lib.rs
- [x] Removed ExportFormat enum, GIF state vars, format picker, and exportGIF from EditorExportView.swift
- [x] Removed `cloom-gif-` temp file cleanup from AppState.swift
- [x] Fixed version test: `assert_eq!(version, env!("CARGO_PKG_VERSION"))`

### Task 2: Open Source Boilerplate (partial)
- [x] Created LICENSE (MIT, copyright 2025 Sachin Rajput)
- [x] Created README.md (description, features, requirements, build instructions, architecture)
- [ ] CONTRIBUTING.md, CODE_OF_CONDUCT.md, CHANGELOG.md, ARCHITECTURE.md, GitHub templates — skipped (user will write)

### Task 3: OAuth Client ID Build-Time Injection
- [x] Created `Secrets.xcconfig.example` template for Google OAuth build-time variables
- [x] Added `Secrets.xcconfig` to `.gitignore`
- [x] Replaced hardcoded OAuth Client ID in Info.plist with `$(GOOGLE_REVERSED_CLIENT_ID)`
- [x] Added `configFiles` to project.yml (Debug/Release) + fallback empty build settings
- [x] Renamed `Secrets.example` → `Secrets.swift.example` (non-compilable extension) with xcconfig instructions
- [x] Added build.sh logic: auto-derives `GOOGLE_REVERSED_CLIENT_ID` from `GOOGLE_CLIENT_ID`; warns if xcconfig missing

### Task 4: CI Fixes
- [x] Changed swift-tests `runs-on: macos-26` → `macos-15` (latest stable)
- [x] Removed redundant second xcodebuild run

### Task 5: Code Quality — File Splits
- [x] Created `ExportService.swift` (132 lines) — extracted exportMP4, presetForQuality, isExportUnmodified from EditorExportView
- [x] Rewrote `EditorExportView.swift` (332 lines) — calls ExportService, body split into computed properties
- [x] Created `ExportWriter+Subtitles.swift` (177 lines) — extracted subtitle methods + shared makeTx3gFormatDescription
- [x] Rewrote `ExportWriter.swift` (260 lines) — removed subtitle methods, made track copying static
- [x] Created `RecordingToolbarContentView.swift` (137 lines) — recording-state toolbar view
- [x] Created `ReadyToolbarContentView.swift` (95 lines) — ready-state toolbar view
- [x] Created `ToolbarToggleButton.swift` (22 lines) — reusable toggle button
- [x] Rewrote `RecordingToolbarPanel.swift` (123 lines) — NSPanel management only

### Task 6: Bug Fixes & Cleanup
- [x] Fixed presetForQuality bug, removed debug UI, dead code, and 17 silent `try?` sites
- [x] Extracted recordingTimestamp() helper, moved NSAlert out of AIOrchestrator

### Task 7: Test Coverage Improvements
- [x] Fixed RecordingSettingsTests: `fromDefaultsReturnsValidSettings` calls `RecordingSettings.fromDefaults()`
- [x] Migrated CacheTests from XCTest to Swift Testing
- [x] Created FFIBridgeTests.swift (helloFromRust + cloomCoreVersion semver)
- [x] Created LibraryFilterTests.swift (7 LibrarySortOrder comparators + TranscriptFilter)
- [x] Fixed silence_tests.rs: eprintln → panic for decoder failures
- [x] Fixed ExportService to take value types (filePath, EDLSnapshot) instead of @Model types (Swift 6 sending errors)
- [x] Added missing CoreGraphics, CoreImage, Foundation imports in test files (needed after XCTest → Swift Testing migration)

### Task 8: Plan Docs & Memory Update
- [x] Updated all 11 plan docs to remove GIF references, add new files, fix test counts

**Milestone verified:** 38 Rust tests pass. 56 Swift tests pass. Build succeeds. GIF export fully removed. MIT license added. OAuth Client ID injected at build time with auto-derived reversed ID. CI simplified. Files split for SRP compliance. Bug fixes applied. Test coverage improved.

---

## Phase 24: Test Coverage
**Status:** Complete
**Date:** 2026-03-01

**Goal:** Close critical test coverage gaps. Focus on pure algorithmic logic that can be unit-tested without hardware, AV frameworks, or network mocking.

### Refactoring for Testability
- [x] Added memberwise `EDLSnapshot` initializer (for test construction without SwiftData models)
- [x] Extracted `EditorCompositionBuilder.buildTimeRanges` to static function
- [x] Changed `SubtitleExportService.mapToCompositionTime` from private to static
- [x] Extracted `WaveformGenerator.applyNoiseFloor` to static function
- [x] Extracted `calculateChunkCount` and `calculateChunkDuration` from `AudioExtractor`

### Bug Fix Discovered by Tests
- [x] Fixed `EditorCompositionBuilder.buildTimeRanges` — see [BUGS.md #34](BUGS.md#34--cuts-at-timeline-start-silently-skipped-in-buildtimeranges) for details

### Priority 1 — CRITICAL (pure logic, zero tests)
- [x] Task 157 — Export pipeline tests (14 tests): `ExportService.isExportUnmodified` (11 condition tests), `presetForQuality` (3 mapping tests)
- [x] Task 158 — Subtitle timing tests (11 tests): `SubtitleExportService.mapToCompositionTime` (offset, cuts, trim, speed, clamping, edge cases)
- [x] Task 159 — Caption/transcript grouping tests (19 tests): `CaptionOverlayView.buildPhrases` (9 tests: empty, word count, time threshold, timing), `TranscriptPanelView.groupIntoSentences` (10 tests: punctuation, overflow, paragraphs)
- [x] Task 160 — AI orchestrator tests (15 tests): `buildTimestampedTranscript` (8 tests: formatting, timestamps, edge cases), `findParagraphStartIndices` (7 tests: nil, single/multi paragraphs, bounds)
- [x] Task 161 — Recording state tests (27 tests): all 7 computed properties tested across all 7 enum cases + Equatable
- [x] Task 162 — Editor composition tests (11 tests): `buildTimeRanges` (no cuts, trim, single/multiple cuts, cut at start/end, unsorted, clamped)

### Priority 2 — HIGH (pure math, easy wins)
- [x] Task 163 — Capture math tests (17 tests): `MicGainProcessor` (7 tests: sensitivity→isUnity, clamping), `WebcamShape` (10 tests: aspectRatio, cornerRadius, next cycling, displayNames, allCases)
- [x] Task 164 — Missing sort order tests: added `oldestFirst` to `LibraryFilterTests` (1 test)
- [x] Task 165 — AI processing tracker tests (7 tests): start/stop/isProcessing, multiple IDs, idempotency, stop-without-start

### Priority 3 — MEDIUM (extractable logic)
- [x] Task 166 — Waveform noise floor tests (8 tests): empty, all-zero, sensitivity multiplier, mixed speech/noise, clamping
- [x] Task 167 — Audio chunking tests (12 tests): `calculateChunkCount` (7 tests: small/equal/double/over/triple/zero), `calculateChunkDuration` (5 tests: single/multi/zero/uneven)
- [x] Task 168 — Rust LLM tests (7 new tests): parse_chapters edge cases (whitespace, negative start_ms, large values, single, many, trailing text), truncate_transcript (empty, single char)

### New Test Files (10)
- `CloomTests/ExportServiceTests.swift`
- `CloomTests/SubtitleTimingTests.swift`
- `CloomTests/CaptionGroupingTests.swift`
- `CloomTests/AITextProcessingTests.swift`
- `CloomTests/RecordingStateTests.swift`
- `CloomTests/EditorCompositionTests.swift`
- `CloomTests/CaptureMathTests.swift`
- `CloomTests/AIProcessingTrackerTests.swift`
- `CloomTests/WaveformNoiseFloorTests.swift`
- `CloomTests/AudioChunkingTests.swift`

**Milestone verified:** 149 new tests (141 Swift + 7 Rust + 1 updated). Total: 198 Swift tests in 30 suites + 50 Rust tests. All pass. Build succeeds. Bug fix: cuts at start of timeline now handled correctly in EditorCompositionBuilder.

---

## Phase 25B: Fix Subtitle Export
**Status:** Complete
**Date:** 2026-03-03
**PR:** [#37](https://github.com/iamsachin/cloom/pull/37)

- [x] Fixed subtitle export failure — see [BUGS.md #37](BUGS.md#37--subtitle-export-fails-with-the-operation-could-not-be-completed) for details
- [x] Simplified `ExportWriter.swift` and `ExportService.swift` (4 clear export paths)
- [x] Removed `[DEBUG]` log lines from export pipeline

**Milestone verified:** Export with subtitles succeeds. Export without subtitles (passthrough) still works. Build succeeds.

---

## Phase 25: Design Principles & Code Quality
**Status:** DONE

**Goal:** Fix SOLID, KISS, DRY violations and improve encapsulation, separation of concerns, and code organization identified in the design principles audit. Build succeeds + all existing tests pass + no regressions.

### Task 1 — Rust Safety Fixes (High Priority)
- [x] Fix UTF-8 byte-slice truncation panic in `cloom-core/src/ai/llm.rs` — use `char_indices()` instead of `&text[..MAX_CHARS]`
- [x] Fix TOCTOU file check in `cloom-core/src/ai/transcribe.rs` — replace `Path::exists()` with `File::open()` and real error propagation
- [x] Log decode errors in `cloom-core/src/audio/silence.rs` — added `log::warn!` instead of silent `Err(_) => continue`
- [x] Remove dead `ExportError` variant from `cloom-core/src/lib.rs`
- [x] Added test `test_truncate_multibyte_utf8_no_panic`

### Task 2 — DRY: Shared UI Components
- [x] Extract `AsyncThumbnailImage` component (`Shared/AsyncThumbnailImage.swift`) — moved `thumbnailCache` and async loading from `VideoCardView` and `LibraryListRowView`
- [x] Extract `CloudStatusBadgeView` (`Shared/CloudStatusBadgeView.swift`) — unified cloud status icon
- [x] Extract `Int64.formattedDuration` extension (`Shared/DurationFormatting.swift`)

### Task 3 — DRY: Service & Helper Extraction
- [x] Add `resetSegmentState()` to `RecordingCoordinator` — replaced 3 duplicated reset blocks
- [x] Create `NotificationService` (`Shared/NotificationService.swift`) — unified notification logic, fixed guard-condition inversion bug
- [x] Extract `AVMutableAudioMix.stereoMix(from:)` (`Shared/AudioMixBuilder.swift`) — deduplicated across `SegmentStitcher` (2x) and `EditorCompositionBuilder`
- [x] Extract `NSScreen.screen(for:)` (`Shared/NSScreen+DisplayID.swift`) — deduplicated in `ScreenCaptureService+Configuration` and `RecordingCoordinator+Webcam`
- [x] Extract `startCaptureWithCurrentConfig()` helper — deduplicated filter/mode capture start in `+Capture` and `+PauseResume`
- [x] Deduplicate OpenAI client construction in Rust — shared `make_openai_client()` in `ai/mod.rs`

### Task 4 — Separation of Concerns
- [x] Move `buildCaptionPhrases` and `groupTranscriptIntoSentences` off view types into `Shared/TranscriptGrouping.swift` — kept forwarding stubs on views for test compatibility
- [x] Extract `TranscriptPersistenceService` (`AI/TranscriptPersistenceService.swift`) — 85-line `persistResults` out of `AIOrchestrator`
- [x] Extract `VideoLibraryService` (`Library/VideoLibraryService.swift`) — file deletion/folder move out of `LibraryContentView`
- [x] `MenuBarView` already in separate `CloomApp.swift` (appropriate size) — no action needed

### Task 5 — Encapsulation & Architecture
- [x] Create `UserDefaultsKeys` enum (`Shared/UserDefaultsKeys.swift`) — 18 centralized keys, replaced raw strings across 13 files
- [x] Fix `AppState` facade bypass in `CloomApp.swift:88-89` — use wrapper methods instead of reaching through `.recordingCoordinator`
- [x] Make `AnnotationRenderer.ciContext` private — exposed `renderToBuffer(_:to:bounds:)` method, updated caller in `ScreenCaptureService+StreamOutput`
- [x] `thumbnailCache` moved to `AsyncThumbnailImage` in Task 2
- RecordingCoordinator private properties — skipped (Swift extensions in separate files cannot access `private`; would need file consolidation)
- Singleton access removal — skipped (significant architectural change requiring Environment/DI refactor)

### Task 6 — Rust Code Quality
- [x] Replace glob re-exports with explicit symbol exports in `lib.rs` — 12 symbols across 4 modules
- [x] Deduplicate provider `match` — extracted `dispatch_transcription()` in `transcribe.rs`
- [x] Extract `llm_from_transcript()` shared helper — deduplicates validate → truncate → format → complete preamble across 4 LLM functions

**New files added:**
- `CloomApp/Sources/Shared/AsyncThumbnailImage.swift`
- `CloomApp/Sources/Shared/CloudStatusBadgeView.swift`
- `CloomApp/Sources/Shared/DurationFormatting.swift`
- `CloomApp/Sources/Shared/NotificationService.swift`
- `CloomApp/Sources/Shared/AudioMixBuilder.swift`
- `CloomApp/Sources/Shared/NSScreen+DisplayID.swift`
- `CloomApp/Sources/Shared/TranscriptGrouping.swift`
- `CloomApp/Sources/Shared/UserDefaultsKeys.swift`
- `CloomApp/Sources/Library/VideoLibraryService.swift`
- `CloomApp/Sources/AI/TranscriptPersistenceService.swift`

**Milestone verified:** Build succeeds (1 warning). 198 Swift tests in 30 suites + 44 Rust tests — all pass. No regressions.

---

## Phase 26: UI Polish — Welcome, Library, Editor + Smooth Waveform
**Status:** Complete
**Date:** 2026-03-03

Visual polish pass across all three main screens plus continuous waveform rendering.

### Changes
- [x] 3 new color tokens in Theme.swift + new HoverButtonStyle.swift
- [x] OnboardingView: permission row animations, CTA prominence, column separation
- [x] VideoCardView: entrance fade+slide, hover scale 1.015x
- [x] LibraryListRowView: smooth hover animation
- [x] LibraryContentView: better empty state text, grid/list crossfade
- [x] LibrarySidebarView: storage disk icon, secondary color
- [x] EditorToolbarView: 4 group dividers, time hierarchy, play button prominence, hover style on 8 buttons
- [x] EditorContentView: sidebar slide-in/out transitions
- [x] TimelineView: smooth waveform (quadratic bezier curves instead of bars)

**Milestone verified:** Build succeeds. 196 Swift tests pass.

---

## Phase 27: Pre-Release
**Status:** Complete
**Date:** 2026-03-03

### Key Decisions
- **No Apple Developer Program** — ad-hoc signing only (free)
- **No notarization** — users right-click → Open on first launch
- **Custom Homebrew tap** — `iamsachin/homebrew-cloom` (not official homebrew-cask)
- **GitHub Releases** for DMG hosting
- **Upgrade path**: add Developer ID + notarization later if needed

### Tasks
- [x] Task 81a — Ad-hoc code signing + DMG packaging (`scripts/release.sh`: archive → `codesign --sign -` → `create-dmg`)
- [x] Task 81b — GitHub Actions release workflow (`.github/workflows/release.yml`: build Rust + Xcode → ad-hoc sign → DMG → GitHub Release → update Homebrew tap on `v*` tag)
- [x] Task 81c — Homebrew custom tap (created `iamsachin/homebrew-cloom` repo with `Casks/cloom.rb`, auto-updated by CI)
- [x] Task 81d — ExportOptions.plist for Xcode archive export (ad-hoc `mac-application` method)
- [x] Task 83 — `CHANGELOG.md` with full v0.1.0 feature list
- [x] Task 143 — `UpdateChecker` (@Observable): queries GitHub Releases API, semantic version compare, menu bar "Update Available" item, auto-checks on launch
- [x] Task 144 — `AboutSettingsTab`: 7th Settings tab with app icon, version, GitHub/Issues/License links, "Check for Updates" button

**New files:** `scripts/release.sh`, `ExportOptions.plist`, `CHANGELOG.md`, `.github/workflows/release.yml`, `CloomApp/Sources/App/UpdateChecker.swift`, `CloomApp/Sources/Settings/AboutSettingsTab.swift`, `CloomTests/UpdateCheckerTests.swift`

**Milestone verified:** Build succeeds (0 errors). 10 UpdateChecker tests pass. Homebrew tap live at github.com/iamsachin/homebrew-cloom.

---

## Phase 28: Sparkle Auto-Update
**Status:** Complete
**Date:** 2026-03-05

### Tasks
- [x] Task 170 — Added Sparkle 2.6+ SPM dependency to `project.yml`
- [x] Task 171 — Created `SparkleUpdater.swift`: `@MainActor ObservableObject` wrapping `SPUStandardUpdaterController`
- [x] Task 172 — Replaced `UpdateChecker` with Sparkle in `CloomApp.swift`, `MenuBarView`, and `AboutSettingsTab`
- [x] Task 173 — Added `SUFeedURL` and `SUPublicEDKey` to `Info.plist`
- [x] Task 174 — Generated EdDSA keypair (public key in Info.plist, private key in Keychain + `SPARKLE_ED_PRIVATE_KEY` GitHub secret)
- [x] Task 175 — Created `scripts/generate-appcast.sh` for appcast.xml generation
- [x] Task 176 — Updated CI release workflow: EdDSA DMG signing → appcast generation → gh-pages deployment
- [x] Task 177 — Created `gh-pages` branch with initial appcast.xml, GitHub Pages enabled at `https://iamsachin.github.io/cloom/appcast.xml`

**Deleted files:** `UpdateChecker.swift`
**New files:** `SparkleUpdater.swift`, `scripts/generate-appcast.sh`

**Milestone verified:** Build succeeds (1 warning). Sparkle auto-checks appcast every 24h on launch. "Check for Updates" in menu bar + About tab. CI signs DMGs and publishes appcast to GitHub Pages.

---

## Phase 29: Recording Details Display + Export Quality Fix
**Status:** In Progress
**Date:** 2026-03-27

### Bug Fix: Export Quality Picker
- [x] Task 178 — Added `recordingQuality` field to `VideoRecord`
- [x] Task 179 — Fixed `ExportService` to re-encode via `AVAssetExportSession` when export quality differs from recording quality
- [x] Task 180 — `EditorExportView` defaults quality picker to recording's actual quality

### Recording Details Display
- [x] Task 181 — Created `VideoMetadataLoader` helper (reads bitrate, codec, FPS, audio tracks from AVAsset)
- [x] Task 182 — Updated `EditorInfoPanel` with Details + Encoding sections (quality, recording type, codec, bitrate, FPS, audio tracks)
- [x] Task 183 — Added hover tooltip to `VideoCardView` (resolution, duration, file size, quality, type, date)
- [x] Task 184 — Added resolution and file size columns to `LibraryListRowView`
- [ ] Task 185 — Build verification

### New Files
- `CloomApp/Sources/Shared/VideoMetadataLoader.swift`

### Modified Files
- `CloomApp/Sources/Data/VideoModel.swift` (+recordingQuality field)
- `CloomApp/Sources/Recording/RecordingCoordinator+PostRecording.swift` (store quality on save)
- `CloomApp/Sources/Editor/ExportService.swift` (+recordingQuality param, re-encode when quality differs)
- `CloomApp/Sources/Editor/EditorExportView.swift` (default picker to recording quality, pass recordingQuality)
- `CloomApp/Sources/Editor/EditorInfoPanel.swift` (Details + Encoding sections with async metadata loading)
- `CloomApp/Sources/Library/VideoCardView.swift` (hover tooltip with recording details)
- `CloomApp/Sources/Library/LibraryListRowView.swift` (resolution + file size columns)
