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
**Status:** Not started

### Webcam Bubble Controls (Loom-style)
- [ ] Task 84 — Floating control pill on webcam bubble (stop, timer, pause/resume, discard buttons — capsule-shaped overlay anchored to bottom of bubble)
- [ ] Task 85 — Webcam bubble background themes (solid colors, gradients, patterns behind the circular webcam — like Loom's colored/patterned backdrops)
- [ ] Task 86 — Webcam shape options (circle, rounded rectangle, pill) with smooth transition animations

### Video Enhancement Controls
- [ ] Task 87 — Webcam image adjustments (brightness, contrast, saturation, highlights, shadows — CIFilter pipeline on camera frames)
- [ ] Task 88 — Beauty / soft-focus filter for webcam (skin smoothing via CIGaussianBlur + person segmentation mask)
- [ ] Task 89 — Color temperature / white balance adjustment for webcam feed
- [ ] Task 90 — Screen recording adjustments (brightness, contrast in post-export via editor)

### Recording UX
- [ ] Task 91 — Discard recording button (cancel mid-recording, delete temp files, return to idle)
- [ ] Task 92 — Webcam-only recording mode (no screen, just camera + audio — for intros/outros)

**Milestone:** Loom-style floating controls on webcam bubble. Webcam image adjustments (contrast, highlights, saturation). Background themes. Discard recording. Webcam-only mode.

---

## Phase 11: Cleanup & Tests

**Status:** Not started

### Cleanup
- [ ] Task 62 — Dead code removal + TODO/FIXME audit across Swift and Rust sources
- [ ] Task 63 — Consistent error handling (replace force-unwraps, add user-facing error messages)
- [ ] Task 64 — Code organization (split large files, group related types, consistent naming conventions)
- [ ] Task 65 — Memory leak audit (Instruments Leaks + Allocations, capture session lifecycle)
- [ ] Task 66 — Accessibility pass (VoiceOver labels, keyboard navigation, Dynamic Type support)

### Rust Tests
- [ ] Task 67 — Unit tests for transcription client (mock HTTP, parse responses, error paths)
- [ ] Task 68 — Unit tests for LLM client (prompt construction, response parsing, provider routing)
- [ ] Task 69 — Unit tests for filler word detection (edge cases, multi-language, overlapping windows)
- [ ] Task 70 — Unit tests for silence detection (threshold boundaries, short/long audio, empty input)
- [ ] Task 71 — Unit tests for GIF export (manifest generation, encoder config, file output)

### Swift Tests
- [ ] Task 72 — Unit tests for SwiftData models (VideoRecord, EditDecisionList, FolderRecord CRUD)
- [ ] Task 73 — Unit tests for EditorState (trim, cut, stitch, speed operations, undo/redo)
- [ ] Task 74 — Unit tests for AIOrchestrator (pipeline sequencing, error propagation, cancellation)
- [ ] Task 75 — Unit tests for RecordingSettings (defaults, persistence, quality presets)
- [ ] Task 76 — UI tests for recording flow (start → countdown → stop → library appears)
- [ ] Task 77 — UI tests for editor (open editor, trim handles, export dialog)

**Milestone:** All dead code removed, TODOs resolved. Rust crate at >80% test coverage. Swift unit tests for core logic. UI tests for critical user flows.

---

## Phase 12: Advanced
**Status:** Not started

- [ ] Task 78 — Local view analytics (track views, watch time)
- [ ] Task 79 — Timestamped comments
- [ ] Task 80 — Performance optimization + profiling

---

## Phase 13: Pre-Release
**Status:** Not started

- [ ] Task 81 — Developer ID signing + notarization + DMG packaging
- [ ] Task 82 — App icon + branding assets
- [ ] Task 83 — Release notes + changelog
