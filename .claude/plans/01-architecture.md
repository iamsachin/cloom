# Architecture

## High-Level Diagram

```
┌──────────────────────────────────────────────┐
│              Swift / SwiftUI                 │
│  ┌─────┐ ┌──────────┐ ┌───────────────┐     │
│  │ App │ │ Capture   │ │  Overlay      │     │
│  │     │ │ (SCKit)   │ │  (Bubble,     │     │
│  │Menu │ ├──────────┤ │  Drawing,     │     │
│  │Bar  │ │ Camera    │ │  Controls)    │     │
│  └─────┘ │(AVFound)  │ └───────────────┘     │
│           └──────────┘                       │
│  ┌───────┐ ┌─────────┐ ┌───────────────┐    │
│  │Player │ │Editor   │ │  Library      │    │
│  └───────┘ └─────────┘ └───────────────┘    │
│  ┌───────┐ ┌─────────┐ ┌───────────────┐    │
│  │ AI    │ │Settings │ │  Data         │    │
│  │(orch) │ │(UDflts) │ │  (SwiftData)  │    │
│  └───────┘ └─────────┘ └───────────────┘    │
│  ┌─────────────────┐ ┌───────────────────┐   │
│  │ Compositing     │ │  Export           │   │
│  │ (AVAssetWriter, │ │  (AVMutableComp,  │   │
│  │  VideoToolbox,  │ │   CoreImage)      │   │
│  │  CoreImage)     │ │                   │   │
│  └─────────────────┘ └───────────────────┘   │
├──────────── UniFFI Bridge ───────────────────┤
│              Rust (cloom-core)               │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐     │
│  │  audio   │ │   ai     │ │  export  │     │
│  │(symphonia│ │(Transcribe│ │  (GIF)   │     │
│  │ + DSP)   │ │ LLM)     │ │          │     │
│  └──────────┘ └──────────┘ └──────────┘     │
└──────────────────────────────────────────────┘
```

## Two Recording Paths

1. **Simple path (SCRecordingOutput):** Direct-to-file, zero-copy, hardware-accelerated. Used when no webcam overlay or annotations need baking in. Produces final MP4 directly.
2. **Dual-stream path (SCRecordingOutput + AVCaptureSession):** Screen and webcam recorded as separate files. Composited during **export** in Swift via `AVMutableComposition` + `AVMutableVideoComposition` with a custom compositor. Annotations burned in via `CoreImage`/`CoreGraphics`.

Both paths use Swift/Apple frameworks for all encoding. Rust is never in the encoding path.

## Key Architectural Decisions

1. **Post-process compositing, not real-time:** Webcam bubble and annotations are rendered as floating windows during recording but composited into the final video during export using Swift `AVMutableComposition`.
2. **Non-destructive editing:** All edits stored as EditDecisionList. Original recording never modified. Edits applied only during export.
3. **Swift handles UI + macOS APIs + video processing + data persistence.** Rust handles AI API calls, audio analysis, and GIF export. Clean FFI boundary with minimal surface area.
4. **UniFFI for FFI:** Generates idiomatic Swift from Rust. Uses `#[uniffi::export]` proc macros exclusively (no UDL files). Supports async, callbacks, complex types, error handling.
5. **Protocol-oriented Swift:** Every service is a protocol → dependency injection + testability.
6. **SwiftData for persistence:** Video library managed by SwiftData with `@Model` classes. Tight SwiftUI integration with `@Query` for reactive UI.
7. **Drawing annotations are timestamped stroke data:** Stored as data during recording, re-rendered during playback, burned into frames via CoreImage during export.
8. **Swift owns all config:** Settings stored in `UserDefaults`. Values passed to Rust as function parameters when needed (e.g., API keys to AI calls).
9. **Local-first schema:** v1 data model is optimized for local-only operation. Cloud sync/collaboration fields are deferred until explicitly needed.
