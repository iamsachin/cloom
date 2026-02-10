# Implementation Phases

## Phase 1A: Project Skeleton

**Goal:** Build compiles, Rust↔Swift FFI works, basic app launches.

| # | Task | Module | Features |
|---|------|--------|----------|
| 1 | Xcode project + Cargo scaffold + build.sh + UniFFI hello-world | All | Project setup |
| 2 | SwiftData models (VideoRecord, FolderRecord, TagRecord, etc.) + ModelContainer setup | Data/ | Types |
| 3 | Basic Rust lib.rs with one exported function + UniFFI proc macros | Rust lib.rs | FFI smoke test |
| 4 | MenuBarExtra shell + empty library window | App/ | C2 |

**Milestone:** App launches in menu bar. Rust FFI round-trip works. SwiftData container initialized.

---

## Phase 1B: Walking Skeleton (Record → Library → Play)

**Goal:** Record full screen to MP4, save to library, play back.

| # | Task | Module | Features |
|---|------|--------|----------|
| 5 | Full-screen recording via SCRecordingOutput | Capture/ | A2, A4 |
| 6 | Recording state machine (idle→countdown→recording→stopped) | Recording/ | A10, A12 |
| 7 | Save recording metadata to SwiftData after recording stops | Data/, Recording/ | Storage |
| 8 | Library grid view with @Query + video cards | Library/ | C2, I5 |
| 9 | Basic AVPlayer playback | Player/ | G1 |

**Milestone:** Click menu bar → record screen → stop → see in library → play back.

---

## Phase 2: All Recording Modes + Webcam

**Goal:** Screen+cam, window, region, audio, webcam bubble.

| # | Task | Module | Features |
|---|------|--------|----------|
| 10 | Window/region capture + multi-monitor | Capture/ | A5-A7 |
| 11 | Region selection overlay window | Capture/ | A6 |
| 12 | Camera service (AVCaptureSession) | Camera/ | Webcam |
| 13 | Webcam bubble (circular, draggable, resize) | Overlay/ | B1-B4 |
| 14 | Background blur via Vision segmentation | Camera/ | B5 |
| 15 | Virtual backgrounds | Camera/ | B6 |
| 16 | Mic + system audio capture | Capture/ | A8, A9 |
| 17 | Dual-stream recording (screen + webcam separate files) | Recording/ | A1 |
| 18 | Recording controls polish (control bar, mute, timer) | Overlay/ | C1, C3-C5 |

**Milestone:** All recording modes work. Webcam bubble with blur/virtual bg.

---

## Phase 3: Compositing & Export Pipeline (Swift)

**Goal:** Final composited video with webcam baked in, pause/resume, MP4 export.

| # | Task | Module | Features |
|---|------|--------|----------|
| 19 | CompositingService: AVMutableComposition + AVMutableVideoComposition | Compositing/ | Core |
| 20 | WebcamCompositor (AVVideoCompositing): circular webcam overlay on screen frames | Compositing/ | Composite |
| 21 | Audio mixing via AVMutableAudioMix (system audio + mic) | Compositing/ | A8+A9 |
| 22 | Post-recording composite flow: screen + webcam → single MP4 | Compositing/, Recording/ | A1 final |
| 23 | Pause/resume: segment stitching via AVMutableComposition | Recording/, Compositing/ | A11 |
| 24 | MP4ExportService: apply EditDecisionList via AVMutableComposition | Export/ | H2 |
| 25 | Export progress reporting | Export/ | UX |
| 26 | Settings UI (quality, FPS, codec, devices) | Settings/ | J1-J3, J6 |

**Milestone:** Composited output with webcam. Pause/resume works. MP4 export with EDL. Quality configurable.

---

## Phase 4: Drawing & Annotations

**Goal:** Full annotation toolkit during recording.

| # | Task | Module | Features |
|---|------|--------|----------|
| 27 | Drawing canvas (pen, highlighter, arrow, shapes) | Overlay/ | D1-D5 |
| 28 | Eraser, undo, color picker, stroke width | Overlay/ | D6, D7 |
| 29 | Mouse click emphasis (ripple) | Overlay/ | D8 |
| 30 | Cursor spotlight | Overlay/ | D9 |
| 31 | AnnotationRenderer: burn annotations into export via CoreImage | Compositing/ | Export |

**Milestone:** Draw during recording. Annotations visible in playback overlay and burned into exported video.

---

## Phase 5: Editor

**Goal:** Full post-recording non-destructive editing.

| # | Task | Module | Features |
|---|------|--------|----------|
| 32 | Timeline UI with scrubber + waveform | Editor/ | E4 |
| 33 | Trim from start/end (drag handles) | Editor/ | E1 |
| 34 | Cut out sections (split + delete) | Editor/ | E2 |
| 35 | Stitch multiple clips | Editor/ | E3 |
| 36 | Speed adjustment | Editor/ | E5 |
| 37 | Thumbnail selection | Editor/ | E6 |
| 38 | GIF export via Rust encoder (Swift pre-extracts frames) | Rust export/, Bridge/, Export/ | H3 |

**Milestone:** Non-destructive editor. Export MP4/GIF.

---

## Phase 6: AI Features

**Goal:** Auto transcription, titles, summaries, chapters.

| # | Task | Module | Features |
|---|------|--------|----------|
| 39 | Transcription client in Rust (default `gpt-4o-mini-transcribe`, swappable provider/model) | Rust ai/ | F1 |
| 40 | Provider-aware LLM client in Rust (OpenAI enabled in v1) | Rust ai/ | F2-F4 |
| 41 | AI FFI bridge + Swift AIOrchestrator | Bridge/, AI/ | Wire up |
| 42 | Filler word detection from transcript (Rust) | Rust audio/ | F5 |
| 43 | Silence detection (Rust + symphonia) | Rust audio/ | F6 |
| 44 | API key settings UI + Keychain storage | Settings/ | Config |

**Milestone:** Post-recording auto-transcription, title, summary, chapters. Silence/filler detection.

---

## Phase 7: Player & Transcript

**Goal:** Rich playback experience.

| # | Task | Module | Features |
|---|------|--------|----------|
| 45 | Caption overlay (SRT/VTT rendering) | Player/ | G2 |
| 46 | Transcript panel (scroll, click-to-seek) | Player/ | G6 |
| 47 | Chapter navigation | Player/ | G7 |
| 48 | Speed control + PiP + fullscreen | Player/ | G3-G5 |

**Milestone:** Full-featured player with captions, transcript, chapters.

---

## Phase 8: Library & Organization

**Goal:** Complete library management.

| # | Task | Module | Features |
|---|------|--------|----------|
| 49 | Folder management (create, rename, move, nest) | Library/, Data/ | I2 |
| 50 | Tags/labels (create, assign, color) | Library/, Data/ | I3 |
| 51 | Full-text search (SwiftData metadata + GRDB SQLite FTS for transcript) | Library/, Data/ | I1 |
| 52 | Sort/filter + thumbnail previews | Library/ | I4-I5 |
| 53 | Auto-copy file path | Library/ | H1 |

**Milestone:** Organized library with search, folders, tags.

---

## Phase 9: Polish & Settings

**Goal:** Production-quality UX.

| # | Task | Module | Features |
|---|------|--------|----------|
| 54 | Global keyboard shortcuts via Carbon HotKey API (customizable) | App/ | C3, J5 |
| 55 | Launch at startup (SMAppService) | App/ | J4 |
| 56 | Notifications | App/ | J7 |
| 57 | Noise cancellation | Recording/ | J8 |
| 58 | Dark mode polish + onboarding | App/ | J6 |
| 59 | Crash recovery + temp file cleanup on launch | App/ | Robustness |
| 60 | Disk space monitoring + storage management | Settings/ | Robustness |
| 61 | Developer ID signing + notarization + DMG packaging pipeline (outside App Store) | App/, Build/Release | Distribution |

---

## Phase 10: Advanced

| # | Task | Module | Features |
|---|------|--------|----------|
| 62 | Local view analytics (track views, watch time) | Data/, Library/ | K1 |
| 63 | Timestamped comments | Player/, Data/ | K2 |
| 64 | Performance optimization + profiling | All | Profile |
