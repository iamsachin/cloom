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
- [x] Task 107 — Fix export dropping audio: EditorCompositionBuilder now inserts ALL source audio tracks (not just Track 0), builds AVMutableAudioMix for multi-track mixdown
- [x] Task 108 — Fix raw recordings for web players: SegmentStitcher handles multiple audio tracks per segment, new `mixdownAudio()` re-exports multi-track files into single mixed stereo output
- [x] Task 109 — RecordingCoordinator uses mixdownAudio for single-segment path (with fallback to plain moveItem)

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

Code audit and fixes to ensure Cloom survives 30-minute recordings without crashes, memory growth, audio drift, or export failures. 9 issues fixed across 4 waves, plus runtime instrumentation added.

### Wave 1: Recording Pipeline Fixes (6 issues)
- [x] Fix 3 — Reuse compositor/renderer on pause/resume (no more new instances per cycle)
- [x] Fix 4 — Segment cleanup on stitch failure (defer block) + crash recovery for `cloom-gif-` and `cloom_audio_chunk_` prefixes
- [x] Fix 5 — FrameImageCache bounded eviction (max 8 entries, insertion-order tracking)
- [x] Fix 6 — Audio buffering before first video frame (up to 50 early samples, flushed on first video PTS)
- [x] Fix 7 — Frame drop logging milestones (1, 5, 10, 25, 50, 100, then every 100 with drop rate %)
- [x] Fix 9 — ShapeMaskCache LRU eviction (keep 4 entries, evict oldest instead of nuke-all)
- [x] CacheTests.swift — 5 tests for FrameImageCache and ShapeMaskCache eviction behavior

### Wave 2: Waveform Generator Rewrite (1 issue)
- [x] Fix 2 — Single-pass streaming waveform: estimate total samples from track duration, process each buffer immediately with zero-copy CMBlockBufferGetDataPointer (fallback to CMBlockBufferCopyDataBytes). O(peakCount) memory instead of O(total_samples).

### Wave 3: Whisper Audio Chunking (1 issue)
- [x] Fix 1 — Transcribe recordings >25MB: Swift `splitAudioForTranscription()` splits audio into <20MB chunks via AVAssetExportSession; Rust `transcribe_audio_chunked()` transcribes each chunk and merges with offset-adjusted timestamps; AIOrchestrator uses chunked path when >1 chunk
- [x] Removed hard 25MB size check from `transcribe_openai`
- [x] 3 new Rust tests (chunked offset adjustment, text merging, empty paths)

### Wave 4: Recording Instrumentation
- [x] RecordingMetrics class — tracks frame/drop counts, segments, elapsed time, peak memory via `task_info`; periodic 60s summary + final summary; thread-safe via OSAllocatedUnfairLock
- [x] Integration: RecordingCoordinator creates/starts/stops metrics; VideoWriter reports frames/drops; ScreenCaptureService wires metrics to writer

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

## Phase 22: Pre-Release
**Status:** Not started

- [ ] Task 81 — Developer ID signing + notarization + DMG packaging
- [ ] Task 83 — Release notes + changelog
- [ ] Task 143 — Check for updates (query GitHub Releases API for latest version, compare with bundled CFBundleShortVersionString, show update-available banner in library with download link to GitHub release page; also add "Check for Updates..." item in the menu bar dropdown)
- [ ] Task 144 — About section (new Settings tab or window showing app icon, current version from CFBundleShortVersionString + build number, credits/acknowledgements, link to GitHub repo, "Check for Updates" button reusing Task 143 logic)
