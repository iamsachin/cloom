# Swift Modules Detail

## App/ — Application Lifecycle & Menu Bar

**Responsibilities:**
- `@main` SwiftUI App with `MenuBarExtra` + `WindowGroup`
- Window management (library window, floating panels, settings)
- Global keyboard shortcut registration via Carbon `RegisterEventHotKey`
- Launch-at-startup via `SMAppService`
- Notification scheduling via `UNUserNotificationCenter`

**Key Types:**
- `CloomApp: App` — top-level
- `AppState: ObservableObject` — global state (current recording, library selection)
- `PermissionsManager` — TCC permission handling (screen capture, camera, mic)
- `KeyboardShortcutManager` — registers/listens global hotkeys

**macOS APIs:** `MenuBarExtra`, `Settings` scene, `WindowGroup`, `SMAppService`, Carbon `RegisterEventHotKey`

---

## Capture/ — Screen Capture Engine

**Responsibilities:**
- Enumerate screens/windows/apps via `SCShareableContent`
- Build `SCContentFilter` for full-screen, window, or region capture
- Configure `SCStreamConfiguration` (resolution, FPS, pixel format, cursor, audio)
- Manage `SCStream` lifecycle (start, pause, resume, stop)
- Use `SCRecordingOutput` (macOS 15+) for direct-to-file recording
- Region selection UI via transparent full-screen overlay

**Key Types:**
- `ScreenCaptureService` (protocol) — abstraction
- `DefaultScreenCaptureService` — concrete SCKit implementation
- `CaptureConfiguration` — value type wrapping filter + config
- `RegionSelectionWindow` — transparent overlay with drag-to-select

**macOS APIs:** `SCShareableContent`, `SCStream`, `SCStreamConfiguration`, `SCContentFilter`, `SCRecordingOutput`

---

## Camera/ — Webcam Capture

**Responsibilities:**
- Enumerate cameras via `AVCaptureDevice.DiscoverySession`
- Manage `AVCaptureSession` with video input
- Camera flip/mirror
- Person segmentation for background blur/virtual backgrounds via Vision
- Deliver camera frames as `CVPixelBuffer`

**Key Types:**
- `CameraService` (protocol)
- `DefaultCameraService` — AVCaptureSession implementation
- `PersonSegmentation` — Vision `VNGeneratePersonSegmentationRequest`, CoreImage blur

**macOS APIs:** `AVCaptureSession`, `AVCaptureDevice`, Vision (`VNGeneratePersonSegmentationRequest`), `CoreImage`

---

## Recording/ — Recording State Machine & Coordination

**Responsibilities:**
- Central state machine: `idle → countdown → recording → paused → recording → stopped`
- Countdown timer (3-2-1 overlay)
- Pause/Resume with timestamp gap management
- Recording timer display (elapsed time)
- Coordinates Capture + Camera + Audio into single session
- Mic mute/unmute without stopping recording

**Key Types:**
- `RecordingCoordinator: ObservableObject` — THE source of truth for recording lifecycle
- `RecordingState` (enum) — all possible states
- `RecordingMode` — screen+cam, screen-only, cam-only
- `CountdownView` — visual countdown overlay

**This is the HEART of the app.** Gets all recording signals flowing.

---

## Compositing/ — Post-Recording Video Composition

**Responsibilities:**
- Compose screen recording + webcam overlay into single video during export
- Apply webcam bubble (circular crop, position, size) via custom `AVVideoCompositing`
- Burn drawing annotations into frames via `CoreImage`/`CoreGraphics`
- Hardware-accelerated compositing via Metal/GPU

**Key Types:**
- `CompositingService` (protocol) — abstraction for testing
- `DefaultCompositingService` — `AVMutableComposition` + `AVMutableVideoComposition`
- `WebcamCompositor: AVVideoCompositing` — custom compositor that overlays circular webcam onto screen frames
- `AnnotationRenderer` — renders `DrawingStroke` array into `CIImage` overlays keyed by timestamp

**macOS APIs:** `AVMutableComposition`, `AVMutableVideoComposition`, `AVVideoCompositing`, `CoreImage`, `CoreGraphics`, `Metal`

---

## Export/ — Video Export Pipeline

**Responsibilities:**
- Apply `EditDecisionList` to produce final MP4 output
- Use `AVMutableComposition` for trims, cuts, speed changes
- Invoke `CompositingService` for webcam overlay + annotation burn-in
- Export via `AVAssetExportSession` with `VideoToolbox` hardware encoding
- Progress reporting to UI

**Key Types:**
- `ExportService` (protocol)
- `MP4ExportService` — reads source MP4, applies EDL via `AVMutableComposition`, writes output
- `ExportProgressReporter` — wraps `AVAssetExportSession.progress` for UI

**macOS APIs:** `AVMutableComposition`, `AVAssetExportSession`, `VideoToolbox`

**Note:** GIF export is handled by Rust (see 06-rust-modules.md). Swift extracts/resamples frames first, then Rust handles quantization + GIF encoding.

---

## Overlay/ — Webcam Bubble, Drawing Canvas, Control Bar

### Webcam Bubble
- Circular `NSPanel` (floating, non-activating) with camera preview
- Draggable, corner-snapping, resizable (small/medium/large)
- Clips to circle, optional background blur/virtual bg

### Drawing Canvas
- Transparent `NSPanel` layered above capture region
- Tools: pen, highlighter, arrow, rectangle, ellipse, eraser
- Color picker, stroke width, undo/redo stack
- Mouse click emphasis: detects clicks via `CGEvent` tap, draws expanding ripple
- Cursor spotlight: radial gradient around cursor

### Floating Control Bar
- Compact `NSPanel` with stop, pause, mute, draw, timer
- Draggable, stays on top, auto-hides on inactivity

**macOS APIs:** `NSPanel`, `CGEvent` taps, SwiftUI `Canvas`, `CoreImage`

---

## Editor/ — Post-Recording Video Editing

**Responsibilities:**
- Timeline scrubber with frame-accurate seeking
- Trim from start/end via drag handles
- Cut out middle sections via split-and-delete
- Stitch multiple clips
- Speed adjustment
- Thumbnail selection
- All edits produce an `EditDecisionList` (non-destructive)

**Key Types:**
- `EditorView` — main UI
- `TimelineView` — horizontal scrolling timeline + waveform
- `TrimHandleView` — draggable trim controls
- `EditDecisionList` — ordered list of operations

**macOS APIs:** `AVFoundation` (`AVAsset`, `AVAssetImageGenerator`)

---

## Player/ — Video Playback

**Responsibilities:**
- AVPlayer playback with custom transport controls
- Speed control: 0.5x, 1x, 1.5x, 2x
- Full-screen, Picture-in-Picture
- Caption overlay (SRT/VTT from transcript)
- Transcript panel synced to playback position
- Chapter navigation (jump between AI-detected chapters)

**Key Types:**
- `VideoPlayerView` — AVPlayer wrapper
- `CaptionOverlay` — timed text rendering
- `TranscriptPanel` — scrolling transcript with click-to-seek
- `ChapterNavigation` — chapter list + jump

**macOS APIs:** `AVPlayer`, `AVPictureInPictureController`

---

## Library/ — Video Library Browser

**Responsibilities:**
- Grid/list view of all recordings
- Search by title, tags, transcript content
- Folder/workspace organization
- Tags and labels
- Thumbnail previews
- Sorting (date, name, duration)

**Key Types:**
- `LibraryView` — main browser (uses `@Query` from SwiftData for reactive data)
- `VideoCardView` — thumbnail card with metadata
- `FolderSidebar` — folder tree
- `SearchBar`

**Data source:** SwiftData `@Query` for metadata + local SQLite FTS (via GRDB) for transcript search. No FFI calls for library operations.

---

## Data/ — SwiftData Persistence

**Responsibilities:**
- Define all `@Model` classes (VideoRecord, FolderRecord, TagRecord, TranscriptRecord, etc.)
- `ModelContainer` setup and configuration
- Schema versioning and migrations
- Cloud sync field management (syncStatus, remoteID, lastSyncedAt)

**Key Types:**
- `VideoModel`, `FolderModel`, `TagModel`, `TranscriptModel`, `CommentModel`, `ViewEventModel` — `@Model` classes
- `DataManager` — `ModelContainer` factory, migration logic

**macOS APIs:** `SwiftData` (`@Model`, `@Query`, `ModelContainer`, `ModelContext`)

---

## Settings/ — Preferences

**Responsibilities:**
- Tabbed preferences window
- Video quality / frame rate / codec selection
- Camera and microphone device selection
- Keyboard shortcut customization
- Dark mode follows system or forced
- Noise cancellation toggle
- API key management (stored in Keychain)
- All settings persisted via `UserDefaults` (wrapped by `PreferencesManager`)

**Key Types:**
- `PreferencesManager` — `UserDefaults` wrapper with typed accessors for all settings

**macOS APIs:** `Settings` scene, `Security.framework` (Keychain for API keys), `UserDefaults`

**Note:** Config is NOT in Rust. Swift owns all settings. API keys are passed to Rust as function parameters when calling AI functions.

---

## AI/ — AI Feature Integration

**Responsibilities:**
- Orchestrate post-recording AI pipeline
- Send audio file path to Rust for transcription (via FFI; v1 default model `gpt-4o-mini-transcribe`)
- Request title/summary/chapters from Rust LLM client (via FFI)
- Pass API keys from Keychain to Rust as parameters
- Display progress and results in UI
- Store results in SwiftData

**Key Types:**
- `AIOrchestrator` — sequences AI operations after recording
- `TranscriptionService` — wraps Rust bridge calls

---

## Bridge/ — Swift-Rust FFI

**Responsibilities:**
- Contains UniFFI-generated Swift bindings (auto-generated, do not edit)
- Small surface area: audio processing + AI + GIF export only
- Thread safety: Rust calls dispatched off main thread
- Memory management: cleanup of Rust-allocated resources

---

## Shared/ — Models, Utilities, Extensions

- All shared value types (see 03-data-models.md "Swift Models — Value Types")
- SwiftUI view extensions
- Date/time formatters
- File path utilities
- Logging via `os.Logger`
- Error types
