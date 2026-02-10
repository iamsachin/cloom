# Key Technical Challenges & Solutions

## 1. Screen Recording Permission (TCC)

**Problem:** ScreenCaptureKit requires user permission. macOS shows a dialog on first use. macOS 15+ permissions may expire monthly.

**Solution:**
- Check `CGPreflightScreenCaptureAccess()` on launch
- Show onboarding UI explaining why permission is needed
- Handle denial gracefully with "Open System Settings" button
- `Info.plist` needs `NSScreenCaptureUsageDescription`
- Reset during testing: `tccutil reset ScreenCapture <bundle-id>`

---

## 2. Webcam Compositing (Performance)

**Problem:** Compositing webcam onto screen capture must produce high-quality output without real-time processing overhead.

**Solution:** During recording, webcam bubble is a separate floating `NSPanel` (NOT captured by SCKit, which excludes the app's own windows). Record screen + webcam as **separate files**. Composite during **export** in Swift:
- `AVMutableComposition` combines screen + webcam tracks
- `AVMutableVideoComposition` with custom `AVVideoCompositing` protocol implementation
- Custom compositor renders webcam as circular overlay at configured position/size
- GPU-accelerated via `CoreImage` / Metal
- Hardware encoding via `VideoToolbox` during export

This avoids real-time compositing entirely and leverages Apple's GPU pipeline.

---

## 3. Drawing Annotations

**Problem:** Annotations must appear on screen during recording AND in the final video.

**Solution:**
- Drawing canvas is a transparent `NSPanel` overlay (NOT captured by SCKit)
- Strokes stored with timestamps (time relative to recording start)
- During **playback**: re-rendered as SwiftUI overlay synced to playback time
- During **export**: `AnnotationRenderer` uses `CoreImage`/`CoreGraphics` to burn annotations into frames via `AVVideoCompositing` custom compositor
- Fundamentally **non-destructive** — annotations can be edited post-recording

---

## 4. Pause/Resume

**Problem:** Pausing creates timestamp gaps. Output video must not have frozen frames or jumps.

**Solution:**
- Track cumulative pause duration
- On resume, adjust PTS: `adjustedPTS = originalPTS - totalPauseDuration`
- If using `SCRecordingOutput`: stop stream on pause, restart on resume, producing separate segment files
- **Stitching** separate segments: Swift uses `AVMutableComposition` to concatenate segment files into a single video. Each segment is added as a time range in the composition. This is handled by the `CompositingService` during the post-recording step, before the video enters the library.
- If using `SCStreamOutput` + `AVAssetWriter`: stop delivering frames during pause, adjust timestamps on resume

---

## 5. Region Selection UI

**Problem:** User must draw a rectangle on screen to select capture region.

**Solution:**
- Borderless, transparent `NSWindow` covering all screens
- `window.level = .screenSaver` to appear above everything
- `backgroundColor = NSColor.black.withAlphaComponent(0.3)` for dimming
- Handle `mouseDown`, `mouseDragged`, `mouseUp` for selection rectangle
- Show dimensions during drag
- Convert selected rect to screen coordinates for `SCContentFilter`
- Multi-monitor: overlay on all screens, detect which screen selection is on

---

## 6. Person Segmentation (Background Blur)

**Problem:** Running Vision `VNGeneratePersonSegmentationRequest` on every frame at 30 FPS is GPU-intensive.

**Solution:**
- Use `.balanced` quality (not `.accurate`) for real-time
- Process every other frame, interpolate mask for skipped frames
- Use `CIFilter` for GPU-accelerated blur compositing
- Virtual backgrounds: use mask as alpha channel, composite via `CIFilter.sourceOverCompositing`
- Cache most recent mask and reuse if processing falls behind

---

## 7. System Audio + Microphone Mixing

**Problem:** Mixing system audio + microphone requires careful synchronization.

**Solution:**
- `SCStreamConfiguration.capturesAudio = true` for system audio (macOS 13+)
- Separate `AVCaptureSession` for microphone
- Synchronize both streams by PTS timestamps
- **Mixing happens in Swift** during export: `AVMutableComposition` adds both audio tracks, `AVMutableAudioMix` controls volume levels
- Simple recording path: `SCRecordingOutput` can capture system audio directly into the MP4

---

## 8. Build System (Swift + Rust)

**Problem:** Xcode doesn't natively support Rust.

**Solution:** `build.sh` orchestrates:
1. `cargo build --release --manifest-path cloom-core/Cargo.toml --target aarch64-apple-darwin` → `target/aarch64-apple-darwin/release/libcloom_core.a`
2. `uniffi-bindgen generate --library target/aarch64-apple-darwin/release/libcloom_core.dylib --language swift --out-dir CloomApp/Sources/Bridge/Generated/`
3. Copy static library to known location
4. Xcode Build Phase runs `build.sh` before compilation
5. Consider SPM package wrapper for the Rust static library

**Note:** The Rust codebase is small (audio + AI + GIF), so build times should be fast.

---

## 9. UniFFI Async and Callbacks

**Problem:** AI API calls are async/long-running. GIF export needs progress callbacks.

**Solution:**
- UniFFI async support: Rust `async fn` → Swift `async` function
- Rust side uses `tokio` runtime
- Progress callbacks: UniFFI callback interfaces (Rust trait → Swift protocol)
- Cancellation: `tokio_util::sync::CancellationToken`, expose `cancel()` function

---

## 10. GIF Export Quality and Size

**Problem:** GIF files can be enormous without optimization.

**Solution (Rust):**
- Extract frames at reduced rate (max 10 FPS)
- Resize to max 640px width
- NeuQuant or median cut color quantization
- Frame differencing (only encode changed pixels)
- Show estimated file size during export configuration

---

## 11. Crash Recovery & Temp File Cleanup

**Problem:** If the app crashes during recording, temp files (partial recordings, segment files) may be left on disk.

**Solution:**
- On launch, scan temp recording directory for orphaned files
- If partial recording found: attempt to salvage (if MP4 is valid but incomplete, add to library with warning)
- If unsalvageable: prompt user to delete or keep for debugging
- Temp directory: `~/Library/Application Support/Cloom/temp/`
- Final recordings: `~/Movies/Cloom/` (or user-configured library path)
- Recording coordinator writes a "recording in progress" marker file; absence on launch with temp files = crash

---

## 12. SwiftData Schema Migration

**Problem:** As features evolve, the SwiftData schema will change. Migrations must be handled without data loss.

**Solution:**
- Use SwiftData's `VersionedSchema` and `SchemaMigrationPlan`
- Define schema versions as the app evolves
- Write lightweight migration plans for additive changes (new fields with defaults)
- Write custom migration plans for breaking changes (field renames, type changes)
- Cloud sync/collaboration features are out of scope for v1; add sync fields only when cloud scope is approved

---

## 13. Storage Management

**Problem:** Video files can be very large. Users may run low on disk space.

**Solution:**
- Monitor available disk space before and during recording
- Show warning when disk space falls below threshold (e.g., 1 GB remaining)
- Display total library size in settings
- Allow configurable library/storage path (default: `~/Movies/Cloom/`)
- Show per-video file sizes in library view
