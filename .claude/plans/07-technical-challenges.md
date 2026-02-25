# Key Technical Challenges & Solutions

## 1. Screen Recording Permission (TCC)

**Problem:** ScreenCaptureKit requires user permission. macOS resets permissions for debug builds after each Cmd+R rebuild.

**Solution:**
- `PermissionChecker` polls TCC status on launch for Screen Recording, Camera, Microphone, Accessibility
- `OnboardingView` shows step-by-step permission setup with live status indicators
- Accessibility made optional with warning (only needed for click emphasis/cursor spotlight)
- `Info.plist` has `NSScreenCaptureUsageDescription`, `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`
- During development: `tccutil reset Camera/Microphone/ScreenCapture com.cloom.app` after each rebuild

---

## 2. Webcam Compositing (Real-Time)

**Problem:** Compositing webcam onto screen capture must produce high-quality output.

**Solution:** Real-time compositing during recording (NOT post-process as originally planned):
- `WebcamCompositor` uses Metal-backed `CIContext` to composite webcam CIImage onto screen frame
- Shape-aware masking (circle, roundedRect, pill) via CGContext cache
- Emoji frame rendering (positioned stickers around bubble perimeter) via CoreText + CGContext cache
- Image adjustments (brightness, contrast, saturation, highlights, shadows, temperature, tint) applied via CIFilter pipeline
- Webcam unmirroring via CIImage scale with correct extent handling
- Composited into each frame by ScreenCaptureService on the outputQueue
- Single MP4 output — no separate webcam file

**Key lesson:** `CIImage scaleX: -1` shifts extent to negative coordinates. Must use `scaleX: -scaleFactor` + `translationX: width * scaleFactor` to keep extent at origin.

---

## 3. Drawing Annotations (Real-Time Burn-In)

**Problem:** Annotations must appear on screen during recording AND in the final video.

**Solution:**
- Drawing canvas is a transparent `NSPanel` overlay (at `CGShieldingWindowLevel` to stay above recording toolbar)
- `AnnotationStore` holds strokes in real-time during drawing
- `AnnotationRenderer` renders all strokes (Bezier curves), click ripples (radial gradient), and cursor spotlight (dimming vignette) as a single `CIImage`
- This CIImage is composited into each frame by ScreenCaptureService (after webcam overlay)
- Strokes are burned directly into the recording — not stored with timestamps for later replay

**Key lesson:** Active stroke must be pushed to AnnotationStore during drag (not just on mouse-up) for real-time visibility in the video.

---

## 4. Pause/Resume (Segment-Based)

**Problem:** Pausing creates timestamp gaps. Output video must not have frozen frames or jumps.

**Solution:**
- Pause stops the `VideoWriter` and finalizes the current segment file
- Resume creates a new `VideoWriter` segment
- `SegmentStitcher` uses `AVMutableComposition` to concatenate all segments after recording stops
- Each segment is added as a time range in the composition
- `ExportProgressWindow` shows stitching progress

---

## 5. Region Selection UI

**Problem:** User must draw a rectangle on screen to select capture region.

**Solution:**
- `RegionSelectionWindow`: borderless, transparent `NSPanel` covering all screens
- `backgroundColor = NSColor.black.withAlphaComponent(0.3)` for dimming
- Rubber-band drag selection via mouseDown/mouseDragged/mouseUp
- `RegionHighlightOverlay` shows the selected region during recording
- Convert selected rect to screen coordinates for `SCContentFilter`
- `SCContentSharingPicker` handles window/display selection (Apple's system picker handles permissions automatically)

**Key lesson:** Custom `ContentPickerView` using `SCShareableContent` broke due to TCC — other apps' windows can't be listed without Screen Recording permission. `SCContentSharingPicker` handles this automatically.

---

## 6. Person Segmentation (Background Blur)

**Problem:** Running Vision `VNGeneratePersonSegmentationRequest` on every frame at 30 FPS is GPU-intensive.

**Solution:**
- `PersonSegmenter` uses `.balanced` quality (not `.accurate`) for real-time
- `CIFilter` for GPU-accelerated blur compositing
- Cache most recent mask and reuse if processing falls behind
- Applied in the webcam frame pipeline before compositing

---

## 7. System Audio + Microphone (Separate Queue)

**Problem:** System audio and microphone must be recorded without stutter, even when GPU-heavy rendering (annotations, webcam compositing) is happening on the video queue.

**Solution:**
- System audio captured via `SCStreamConfiguration.capturesAudio` in SCStreamOutput
- Microphone captured via `SCStreamConfiguration.captureMicrophone`
- **Critical:** Audio streams (`.audio` and `.microphone` types) are delivered on a separate `audioQueue` dispatch queue, not the video `outputQueue`
- `VideoWriter` (actor) has separate audio inputs for system and mic
- This prevents `CIContext.render()` blocking from causing audio stutter

**Key lesson:** When screen + audio shared the same `outputQueue`, heavy GPU rendering in `handleScreenFrame` blocked audio sample delivery, causing audible stutter.

---

## 8. Build System (Swift + Rust)

**Problem:** Xcode doesn't natively support Rust.

**Solution:** `build.sh` orchestrates:
1. Source `~/.cargo/env` (for Xcode compatibility)
2. `cargo build --release --target aarch64-apple-darwin` → `libcloom_core.a`
3. `cd cloom-core && cargo run --bin uniffi-bindgen generate` → generates Swift bindings + C header + modulemap into `CloomApp/Sources/Bridge/Generated/`
4. Copy static library to `libs/libcloom_core.a`
5. Runs as Xcode pre-build script phase

**Additional workarounds:**
- `Cloom-Bridging-Header.h` required because Xcode 26's explicit module builds can't find the UniFFI modulemap
- `SWIFT_ENABLE_EXPLICIT_MODULES: NO` in project.yml
- xcodegen must be re-run after adding new source files/directories

---

## 9. UniFFI Async and Callbacks

**Problem:** AI API calls are async/long-running. GIF export needs progress callbacks.

**Solution:**
- UniFFI async support: Rust `async fn` → Swift `async` function
- Rust side uses `tokio` runtime (rt-multi-thread)
- Progress callbacks: UniFFI callback interfaces (`GifProgressCallback` Rust trait → Swift protocol)
- AI calls dispatched via `Task.detached` in `AIOrchestrator` (actor) after recording

---

## 10. GIF Export (gifski)

**Problem:** GIF files can be enormous without optimization.

**Solution (Rust gifski):**
- Swift extracts PNG frames from MP4 via `AVAssetImageGenerator` at reduced rate
- Swift writes frames + manifest JSON to temp directory
- Rust `GifExporter` reads PNG manifest, loads frames
- gifski handles color quantization and frame differencing internally
- Configurable width, FPS, and quality
- Progress reporting via callback interface

---

## 11. Crash Recovery & Temp File Cleanup

**Problem:** If the app crashes during recording, temp files may be left on disk.

**Solution:**
- `AppState.init` calls `cleanupOrphanedTempFiles()`
- Scans `/tmp` for `cloom_segment_*` and `cloom_audio_*` files
- Deletes orphaned temp files on launch
- Simplified approach (no salvage attempt for partial recordings)

---

## 12. Disk Space Monitoring

**Problem:** Video files can be very large. Users may run low on disk space.

**Solution:**
- `checkDiskSpace()` guard: refuses to start recording if < 1GB available
- Storage summary in LibraryView toolbar: `"{count} videos · {size}"`
- Per-video file sizes displayed on VideoCardView

---

## 13. Swift 6.2 Concurrency Challenges

**Problem:** Swift 6.2 strict concurrency checking creates conflicts with macOS delegate patterns.

**Solutions encountered:**
- `@MainActor` classes with nonisolated delegate methods: use `@unchecked Sendable` + manual `@MainActor` dispatch
- `@Observable` macro + `nonisolated` properties: use `@ObservationIgnored nonisolated(unsafe)` for cross-isolation access
- `NSObject` protocol conformance conflicts: make class `NSObject` + `@unchecked Sendable` instead of `@MainActor`
- Non-Sendable types (AVComposition, etc.) crossing actor boundaries: create value-type snapshots or mark `@unchecked Sendable`
- `kAXTrustedCheckOptionPrompt` concurrency safety: use string literal `"AXTrustedCheckOptionPrompt"` instead

---

## 14. API Key Storage

**Problem:** Keychain access prompts on every debug rebuild (code signature changes invalidate access).

**Solution:**
- Migrated from Keychain to file-based storage at `~/Library/Application Support/Cloom/api_key`
- File created with `chmod 600` (owner-only read/write)
- No Keychain prompts during development
- API key passed to Rust functions as parameter (never stored in Rust)

---

## 15. SwiftUI Name Collisions

**Problem:** Custom view names can conflict with SwiftUI built-in types.

**Solution:** Renamed `TimelineView` to `EditorTimelineView` to avoid conflict with SwiftUI's built-in `TimelineView`.

---

## 16. CaptureMode Exhaustiveness

**Problem:** Adding new enum cases (e.g., `.webcamOnly`) requires updating ALL switch statements.

**Solution:** Audit all switch statements on `CaptureMode` when adding cases — particularly `ScreenCaptureService.swift`'s `buildFilter` and `configureStream` methods.
