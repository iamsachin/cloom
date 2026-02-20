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
**Status:** Not started

- [ ] Task 45 — Caption overlay (SRT/VTT rendering)
- [ ] Task 46 — Transcript panel (scroll, click-to-seek)
- [ ] Task 47 — Chapter navigation
- [ ] Task 48 — Speed control + PiP + fullscreen

**Milestone:** Full-featured player with captions, transcript, chapters.

---

## Phase 8: Library & Organization
**Status:** Not started

- [ ] Task 49 — Folder management (create, rename, move, nest)
- [ ] Task 50 — Tags/labels (create, assign, color)
- [ ] Task 51 — Full-text search (SwiftData + GRDB FTS)
- [ ] Task 52 — Sort/filter + thumbnail previews
- [ ] Task 53 — Auto-copy file path

**Milestone:** Organized library with search, folders, tags.

---

## Phase 9: Polish & Settings
**Status:** Not started

- [ ] Task 54 — Global keyboard shortcuts (Carbon HotKey API)
- [ ] Task 55 — Launch at startup (SMAppService)
- [ ] Task 56 — Notifications
- [ ] Task 57 — Noise cancellation
- [ ] Task 58 — Dark mode polish + onboarding
- [ ] Task 59 — Crash recovery + temp file cleanup
- [ ] Task 60 — Disk space monitoring + storage management
- [ ] Task 61 — Developer ID signing + notarization + DMG packaging

---

## Phase 10: Advanced
**Status:** Not started

- [ ] Task 62 — Local view analytics (track views, watch time)
- [ ] Task 63 — Timestamped comments
- [ ] Task 64 — Performance optimization + profiling
