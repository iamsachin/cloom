# Architecture

## High-Level Diagram

```
┌──────────────────────────────────────────────────┐
│               Swift / SwiftUI                    │
│  ┌──────┐ ┌───────────┐ ┌─────────────────┐     │
│  │ App  │ │ Capture   │ │  Annotations    │     │
│  │      │ │ (SCKit,   │ │  (Drawing,      │     │
│  │Menu  │ │  Camera,  │ │   Click/Cursor  │     │
│  │Bar   │ │  Webcam)  │ │   effects)      │     │
│  └──────┘ └───────────┘ └─────────────────┘     │
│  ┌──────────┐ ┌─────────┐ ┌───────────────┐     │
│  │Recording │ │Editor   │ │  Library      │     │
│  │(Coord,   │ │(Timeline│ │  (Grid, Side- │     │
│  │ Toolbar, │ │ Trim,   │ │   bar, Search │     │
│  │ Pill)    │ │ Export) │ │   Folders/Tags)│     │
│  └──────────┘ └─────────┘ └───────────────┘     │
│  ┌───────────────┐ ┌─────────┐ ┌────────────┐   │
│  │ Compositing   │ │Settings │ │  Data      │   │
│  │ (VideoWriter, │ │(Tabs,   │ │(SwiftData) │   │
│  │  Webcam Comp, │ │ Hotkeys)│ │            │   │
│  │  Stitcher)    │ │         │ │            │   │
│  └───────────────┘ └─────────┘ └────────────┘   │
│  ┌─────────┐ ┌──────────────────────────────┐    │
│  │ AI      │ │  Player (AVPlayer, Captions, │    │
│  │ (Orch.) │ │   Transcript, Chapters, PiP) │    │
│  └─────────┘ └──────────────────────────────┘    │
├──────────── UniFFI Bridge ───────────────────────┤
│               Rust (cloom-core)                  │
│  ┌──────────┐ ┌──────────┐                       │
│  │  audio   │ │   ai     │                       │
│  │(symphonia│ │(whisper-1│                       │
│  │ + filler)│ │ gpt-4o-  │                       │
│  │          │ │  mini)   │                       │
│  └──────────┘ └──────────┘                       │
└──────────────────────────────────────────────────┘
```

## Recording Pipeline (Real-Time Compositing)

The actual implementation uses a **single recording path** with real-time compositing:

1. **SCStreamOutput** delivers per-frame `CMSampleBuffer` on a dedicated `outputQueue`
2. **WebcamCompositor** composites webcam frame onto screen frame as circular/rounded/pill overlay using Metal-backed CIContext (real-time, not post-process)
3. **AnnotationRenderer** burns annotations (strokes, click ripples, cursor spotlight) into the same frame as CIImage overlays
4. **VideoWriter** (actor) encodes the composited frame via AVAssetWriter with HEVC (H.264 fallback)
5. Audio streams (system + microphone) are delivered on a separate `audioQueue` to prevent stutter from GPU rendering on the video queue

This produces a **single composited MP4** — no separate webcam file, no post-process compositing step.

### Pause/Resume
Pause stops the VideoWriter and creates a segment file. Resume starts a new segment. `SegmentStitcher` uses AVMutableComposition to concatenate all segments into a single video after recording stops.

## Key Architectural Decisions

1. **Real-time compositing, not post-process:** Webcam bubble and annotations are composited into frames during recording via CIContext + Metal GPU pipeline. The recorded MP4 already contains the composited output. This simplifies the export path and ensures what you see is what you get.

2. **Non-destructive editing:** All edits stored as EditDecisionList (@Model in SwiftData). Original recording never modified. Edits applied via EditorCompositionBuilder → AVMutableComposition only during export.

3. **Swift handles UI + macOS APIs + video processing + data persistence.** Rust handles AI API calls and audio analysis. Clean FFI boundary with minimal surface area.

4. **UniFFI for FFI:** Generates idiomatic Swift from Rust. Uses `#[uniffi::export]` proc macros exclusively (no UDL files). Supports async, callbacks, complex types, error handling. Local binary (`cargo run --bin uniffi-bindgen`), not global CLI.

5. **Concrete services, not protocol-oriented:** Services like ScreenCaptureService, CameraService, WebcamCompositor are concrete classes (not protocol-based). Testing uses in-memory SwiftData containers and wiremock for Rust HTTP.

6. **SwiftData for persistence:** Video library managed by SwiftData with `@Model` classes. Tight SwiftUI integration with `@Query` for reactive UI. Search uses SwiftData predicates (no external FTS library).

7. **Annotation data as real-time overlay:** Strokes stored in AnnotationStore during recording, rendered in real-time by AnnotationRenderer into video frames. Not stored with timestamps for later replay — burned directly into the recording.

8. **Swift owns all config:** Settings stored via `@AppStorage` (UserDefaults). API keys stored in file at `~/Library/Application Support/Cloom/api_key` (not Keychain — avoids repeated prompts on debug rebuilds). Values passed to Rust as function parameters when needed.

9. **Local-first schema:** v1 data model is optimized for local-only operation. No sync/collaboration fields in the models.

10. **Separate audio queue:** Audio (system + microphone) streams are processed on a dedicated `audioQueue` dispatch queue, separate from the video `outputQueue`. This prevents GPU-heavy annotation rendering from blocking audio sample delivery and causing stutter.
