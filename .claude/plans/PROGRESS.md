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

- [x] Task 10 — Window/region capture + multi-monitor (CaptureMode enum, SCContentFilter per mode, ContentPicker)
- [x] Task 11 — Region selection overlay window (RegionSelectionWindow with rubber-band NSPanel)
- [x] Task 12 — Camera service (AVCaptureSession wrapper with 720p, frame callback)
- [x] Task 13 — Webcam bubble (circular, draggable, resizable NSPanel with sharingType=.none)
- [x] Task 14 — Background blur via Vision segmentation (VNGeneratePersonSegmentationRequest + CIFilter compositing)
- [ ] Task 15 — Virtual backgrounds (deferred to later phase)
- [x] Task 16 — Mic + system audio capture (captureMicrophone on SCStreamConfiguration, live toggle)
- [x] Task 17 — Dual-stream recording (WebcamRecorder AVAssetWriter, separate MP4, webcamFilePath on VideoRecord)
- [x] Task 18 — Recording controls polish (mic/camera toggles in toolbar, 320px width, stop button)

**Milestone:** All recording modes (full screen, window, region) work. Webcam bubble with background blur. Dual-stream recording. Mic toggle. Polished toolbar with mic/camera controls.

---

## Phase 3: Compositing & Export Pipeline
**Status:** Not started

- [ ] Task 19 — CompositingService: AVMutableComposition + AVMutableVideoComposition
- [ ] Task 20 — WebcamCompositor: circular webcam overlay on screen frames
- [ ] Task 21 — Audio mixing via AVMutableAudioMix (system audio + mic)
- [ ] Task 22 — Post-recording composite flow: screen + webcam → single MP4
- [ ] Task 23 — Pause/resume: segment stitching
- [ ] Task 24 — MP4ExportService: apply EditDecisionList
- [ ] Task 25 — Export progress reporting
- [ ] Task 26 — Settings UI (quality, FPS, codec, devices)

**Milestone:** Composited output with webcam. Pause/resume works. MP4 export with EDL.

---

## Phase 4: Drawing & Annotations
**Status:** Not started

- [ ] Task 27 — Drawing canvas (pen, highlighter, arrow, shapes)
- [ ] Task 28 — Eraser, undo, color picker, stroke width
- [ ] Task 29 — Mouse click emphasis (ripple)
- [ ] Task 30 — Cursor spotlight
- [ ] Task 31 — AnnotationRenderer: burn annotations into export via CoreImage

**Milestone:** Draw during recording. Annotations burned into exported video.

---

## Phase 5: Editor
**Status:** Not started

- [ ] Task 32 — Timeline UI with scrubber + waveform
- [ ] Task 33 — Trim from start/end (drag handles)
- [ ] Task 34 — Cut out sections (split + delete)
- [ ] Task 35 — Stitch multiple clips
- [ ] Task 36 — Speed adjustment
- [ ] Task 37 — Thumbnail selection
- [ ] Task 38 — GIF export via Rust encoder

**Milestone:** Non-destructive editor. Export MP4/GIF.

---

## Phase 6: AI Features
**Status:** Not started

- [ ] Task 39 — Transcription client in Rust (OpenAI gpt-4o-mini-transcribe)
- [ ] Task 40 — Provider-aware LLM client in Rust
- [ ] Task 41 — AI FFI bridge + Swift AIOrchestrator
- [ ] Task 42 — Filler word detection from transcript (Rust)
- [ ] Task 43 — Silence detection (Rust + symphonia)
- [ ] Task 44 — API key settings UI + Keychain storage

**Milestone:** Auto-transcription, title, summary, chapters. Silence/filler detection.

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
