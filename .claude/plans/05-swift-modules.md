# Swift Modules Detail

## App/ — Application Lifecycle & Navigation (8 files)

**Responsibilities:**
- `@main` SwiftUI App with `MenuBarExtra` + single `Window` scene (no separate Editor window)
- Single-window navigation: library and editor modes in one window via `NavigationState`
- `MainWindowView` with `NavigationSplitView` — sidebar + detail switching
- Global keyboard shortcuts via CGEvent tap
- Launch-at-startup via `SMAppService`
- Notification scheduling via `UNUserNotificationCenter`
- Permission checking and onboarding flow
- Dark mode theme management

**Key Types:**
- `CloomApp: App` — top-level, MenuBarExtra + single Window (library)
- `NavigationState: @Observable @MainActor` — navigation mode (library/editor), view style (grid/list), navigation stack, UserDefaults persistence
- `MainWindowView` — root view: NavigationSplitView with sidebar + detail mode switch, Escape key handling
- `AppState: @MainActor ObservableObject` — global state (recording, mic/camera toggles, modelContainer, crash recovery, disk monitoring)
- `PermissionChecker: @MainActor ObservableObject` — live polling for Screen Recording, Camera, Mic, Accessibility TCC permissions
- `OnboardingView` — step-by-step permission setup with live status indicators
- `HotkeyNames` — `KeyboardShortcuts.Name` extensions for `.toggleRecording` (Cmd+Shift+R) and `.togglePause` (Cmd+Shift+P), using sindresorhus/KeyboardShortcuts library
- `Theme` — semantic Color extensions with NSColor dynamic provider, 12 adaptive colors, System/Light/Dark picker

**macOS APIs:** `MenuBarExtra`, `Settings` scene, `Window`, `UNUserNotificationCenter`, `NSAppearance`
**Libraries:** `LaunchAtLogin` (login item), `KeyboardShortcuts` (global hotkeys)

---

## Capture/ — Screen Capture + Camera + Webcam UI (18 files)

**Responsibilities:**
- SCStreamOutput per-frame pipeline (not SCRecordingOutput)
- Build `SCContentFilter` for full-screen, window, or region capture via `SCContentSharingPicker`
- Configure `SCStreamConfiguration` (resolution, FPS, pixel format, cursor, audio)
- Manage `SCStream` lifecycle with separate outputQueue (video) and audioQueue (audio/mic)
- Camera management via AVCaptureSession with frame callback
- Person segmentation for background blur via Vision
- Region selection UI via transparent NSPanel
- Webcam bubble window (draggable, resizable, shape-aware)
- Webcam-only recording mode via dedicated AVAssetWriter
- Webcam shape, theme, and image adjustment configuration
- Noise cancellation on microphone samples

**Key Types:**
- `CaptureMode` (enum) — fullScreen(displayID), window(windowID), region(displayID, rect), webcamOnly
- `ScreenCaptureService: @MainActor` + 2 extensions (Configuration, StreamOutput) — SCStreamOutput pipeline with OSAllocatedUnfairLock<CaptureState>, integrates WebcamCompositor + AnnotationRenderer + MicGainProcessor
- `CameraService: @unchecked Sendable` — AVCaptureSession wrapper, device selection, frame delivery via onFrame callback
- `PersonSegmenter` — VNGeneratePersonSegmentationRequest + CIFilter blur
- `ContentPicker` — SCContentSharingPicker wrapper for window/display selection
- `RegionSelectionWindow` — transparent NSPanel with rubber-band selection
- `WebcamBubbleWindow` — circular/rounded/pill NSPanel, draggable, click-to-cycle size
- `WebcamRecordingService` — webcam-only AVAssetWriter (HEVC 720p, camera+mic)
- `WebcamShape` (enum) — circle, roundedRect, pill with aspectRatio and cornerRadius
- `WebcamFrame` (enum) — emoji frame decorations: none, geometric, tropical, celebration
- `EmojiFrameRenderer` — shared sticker positioning (polar→Cartesian) + CGImage rendering via CoreText
- `WebcamImageAdjuster` — CIColorControls + CIHighlightShadowAdjust + CITemperatureAndTint, thread-safe via OSAllocatedUnfairLock
- `BubbleContentView` — NSView for webcam bubble click/drag handling (extracted from WebcamBubbleWindow)
- `BubbleLayerBuilder` — Panel creation, emoji frame, rebuild (extracted from WebcamBubbleWindow)
- `MicGainProcessor` — Applies configurable gain/sensitivity to mic CMSampleBuffers
- `PersonSegmenter` — VNGeneratePersonSegmentationRequest + CIFilter blur, throttled to every 5th frame with cached mask

**macOS APIs:** `SCShareableContent`, `SCStream`, `SCStreamOutput`, `SCContentSharingPicker`, `AVCaptureSession`, `AVCaptureDevice`, Vision (`VNGeneratePersonSegmentationRequest`), `CoreImage`, `NSPanel`

---

## Recording/ — Recording State Machine & Coordination (15 files)

**Responsibilities:**
- Central state machine: `idle → selectingContent → countdown → recording → paused → stopping`
- Countdown timer (3-2-1 overlay)
- Pause/Resume with segment-based recording
- Coordinates Capture + Camera + Compositing + Annotations into single session
- Mic/camera/blur/annotation/click emphasis/cursor spotlight toggles
- Webcam-only recording mode
- Discard recording with confirmation
- Floating control pill on webcam bubble
- Post-recording pipeline (AI orchestration, library save)

**Key Types:**
- `RecordingCoordinator: @MainActor ObservableObject` — THE source of truth (+ 7 extension files)
  - `+Annotations.swift` — canvas/toolbar management
  - `+Capture.swift` — capture setup and stream configuration
  - `+CaptureDelegate.swift` — nonisolated AVCaptureVideoDataOutputSampleBufferDelegate
  - `+PauseResume.swift` — pause/resume/segment management
  - `+PostRecording.swift` — AI pipeline, segment stitching, library save
  - `+Toggles.swift` — mic/camera/blur/annotation toggle methods
  - `+UI.swift` — window management (bubble, toolbar, annotation, countdown)
  - `+Webcam.swift` — webcam start/stop/preview/adjustments
- `RecordingState` (enum) — idle, selectingContent, countdown, recording, paused, stopping
- `RecordingToolbarPanel` — NSPanel with mode selection, mic/camera/blur toggles, draw/click/spotlight controls
- `BubbleControlPill: @MainActor` — NSPanel child of webcam bubble (stop, timer, pause, discard)
- `DiscardConfirmationWindow` — confirmation dialog
- `CountdownOverlayWindow` — 3-2-1 countdown overlay
- `RegionHighlightOverlay` — visual feedback for selected region

**This is the HEART of the app.** All recording signals flow through RecordingCoordinator.

---

## Compositing/ — Real-Time Video Compositing (6 files)

**Responsibilities:**
- Real-time webcam overlay onto screen frames during recording (not post-process)
- AVAssetWriter encoding (HEVC primary, H.264 fallback)
- Dual audio input (system audio + microphone on separate writer inputs)
- Segment stitching for pause/resume via AVMutableComposition
- Export progress UI

**Key Types:**
- `VideoWriter` (actor) — AVAssetWriter wrapper, HEVC encoding, PTS normalization, pixel buffer pool, actor isolation for thread safety
- `WebcamCompositor: @unchecked Sendable` + 2 extensions (ShapeMask, EmojiFrame) — Metal-backed CIContext, composites webcam frame onto screen frame as circular/rounded/pill overlay with shape masking, theme border, brightness/contrast/saturation adjustments. Thread-safe via OSAllocatedUnfairLock
- `SegmentStitcher` — AVMutableComposition concatenation of pause/resume segments + audio mixdown for web player compatibility
- `ExportProgressWindow` — progress modal for export and stitching operations

**macOS APIs:** `AVAssetWriter`, `AVAssetWriterInput`, `CoreImage` (`CIContext`, `CIFilter`), `Metal`, `AVMutableComposition`

---

## Annotations/ — Drawing & Click Effects (11 files)

**Responsibilities:**
- Drawing tools: pen, highlighter, arrow, line, rectangle, ellipse, eraser
- Color palette (6 colors) and stroke width selection
- Transparent NSPanel overlay for drawing during recording
- Undo stack, clear all, Escape to exit draw mode
- Mouse click emphasis (expanding ripple via CGEvent tap)
- Cursor spotlight (radial gradient dim overlay)
- Real-time burn-in of all annotations into recorded video frames via CIImage

**Key Types:**
- `AnnotationModels` — AnnotationTool, StrokePoint, StrokeColor, AnnotationStroke, ClickRipple, SpotlightState, AnnotationSnapshot
- `AnnotationStore: @Observable` — real-time stroke editing, snapshot generation
- `AnnotationRenderer: @unchecked Sendable` — renders annotations as CIImage overlay for burn-in (called from SCStreamOutput queue)
- `AnnotationCanvasWindow` — transparent NSPanel overlay at CGShieldingWindowLevel
- `AnnotationCanvasView` — SwiftUI Canvas with mouse down/drag/up tracking, pressure via NSEvent
- `AnnotationCanvasRenderer` — All drawing code (extracted from CanvasView)
- `AnnotationInputHandler` — Mouse events, eraser (extracted from CanvasView)
- `AnnotationToolbarPanel` — NSPanel above canvas for tool/color/width controls
- `AnnotationToolbarContentView` — SwiftUI content for toolbar
- `ClickEmphasisMonitor` — CGEvent tap for mouse clicks → ClickRipple
- `CursorSpotlightMonitor` — cursor position tracking → SpotlightState

**macOS APIs:** `NSPanel`, `CGEvent` taps, SwiftUI `Canvas`, `CoreImage`, `CoreGraphics`

---

## Editor/ — Post-Recording Video Editing (22 files)

**Responsibilities:**
- Non-destructive editing with EditDecisionList (SwiftData @Model)
- Timeline scrubber with frame-accurate seeking + audio waveform + thumbnail strip
- Trim from start/end via drag handles
- Cut out middle sections via split-and-delete
- Stitch multiple clips with drag-to-reorder
- Speed adjustment (0.25x–4x)
- Thumbnail selection
- Caption overlay (karaoke-style word-by-word highlighting)
- Transcript panel (right sidebar, click-to-seek, auto-scroll, filler word styling)
- Chapter navigation (popover list + timeline markers)
- Bookmark panel (add/edit/delete, seek on click, timeline markers)
- PiP and fullscreen playback
- MP4 export with quality selection + brightness/contrast adjustments + subtitle mode
- MP4 export via ExportService (extracted from EditorExportView)
- Subtitle export: embedded tx3g track, EDL-aware timing

**Key Types:**
- `EditorView` — main editor UI (1000x700 window)
- `EditorState: @Observable @MainActor` + bookmark extension — editing state, current video, EDL, playback position, bookmark CRUD
- `EditorCompositionBuilder` — transforms EditDecisionList → AVMutableComposition (trim, cuts, stitch, speed)
- `EditorTimelineView` — Canvas-based waveform + thumbnail strip + red playhead (renamed from TimelineView to avoid SwiftUI collision)
- `TrimHandlesView` — yellow drag handles + grayed-out overlay
- `CutRegionOverlay` — red hatched cut regions + context menu
- `VideoPreviewView` — AVPlayer wrapper + AVPictureInPictureController coordinator
- `CaptionOverlayView` — karaoke-style word-by-word highlight with phrase grouping + binary search lookup
- `TranscriptPanelView` — FlowLayout right sidebar, auto-scroll, click-to-seek, filler word styling
- `ChapterNavigationView` — popover list + accent color timeline markers/triangles
- `StitchPanelView` — multi-clip drag-to-reorder
- `SpeedControlView` — 0.25x–4x presets popover
- `ThumbnailPickerView` — slider + "Use Current Frame" + PNG save
- `ThumbnailStripGenerator` — generates preview thumbnails for timeline
- `WaveformGenerator` — AVAssetReader-based audio waveform peak extraction with sqrt normalization
- `EditorExportView` — quality picker + brightness/contrast sliders, AVAssetExportSession with CIColorControls
- `BookmarksPanelView` — add/edit/delete bookmarks, seek on click, highlight near-current-time rows
- `EditorToolbarView` — playback/cut/chapter/export controls (extracted from EditorView)
- `EditorInfoPanel` — info sidebar with title, summary, metadata (extracted from EditorView)
- `SubtitleExportService` (actor) — subtitle phrase building, EDL-aware timing
- `ExportService` — MP4 export logic, presetForQuality, passthrough detection (extracted from EditorExportView)
- `ExportWriter+Subtitles` — tx3g subtitle track embedding extension

**macOS APIs:** `AVFoundation` (`AVAsset`, `AVAssetImageGenerator`, `AVAssetReader`, `AVMutableComposition`, `AVAssetExportSession`), `AVPictureInPictureController`

---

## Library/ — Video Library Browser (8 files)

**Responsibilities:**
- Grid view of all recordings with hover preview effect
- Folder management (create, rename, move, nest) via sidebar
- Tags/labels (create, assign, 8-preset color picker, bulk tagging)
- Full-text search (.searchable, title/summary/transcript SwiftData predicate filtering)
- Sort/filter (7 sort options, transcript filter)
- Video context menus (copy path, show in Finder, move to folder, tags, delete)
- Info sidebar panel (title, full summary, metadata)
- Storage summary in toolbar ("{count} videos · {size}")

**Key Types:**
- `LibraryView` — main browser grid with `@Query` from SwiftData, hover scale effect on cards
- `LibrarySidebarView` — flat folder tree + tag section
- `VideoCardView` — thumbnail + metadata + summary tooltip + tag pills + context menu
- `LibraryFilterModels` — sort/filter enums (extracted from LibraryView)
- `LibraryVideoGrid` — grid item, context menu, selection badge (extracted from LibraryView)
- `TagEditorView` — 8-preset color picker + tag CRUD
- `BulkTagSheet` — bulk tag assignment
- `FolderPickerSheet` — move videos to folders

**Data source:** SwiftData `@Query` for metadata. Search uses SwiftData predicates (no external FTS library).

---

## Player/ — Video Playback (1 file)

**Note:** Most player functionality was integrated into the Editor module. The standalone Player is a legacy wrapper.

**Key Types:**
- `PlayerView` — AVPlayer wrapper with basic playback controls

---

## Data/ — SwiftData Persistence (9 files)

**Responsibilities:**
- Define all `@Model` classes (VideoRecord, FolderRecord, TagRecord, TranscriptRecord, TranscriptWordRecord, ChapterRecord, BookmarkRecord, EditDecisionList, VideoComment, ViewEvent)
- `ModelContainer` setup in AppState with all schemas registered
- No schema versioning/migration implemented yet

**Key Types:**
- `VideoRecord`, `FolderRecord`, `TagRecord`, `TranscriptRecord`, `TranscriptWordRecord`, `ChapterRecord`, `BookmarkRecord`, `EditDecisionList`, `VideoComment`, `ViewEvent`

**macOS APIs:** `SwiftData` (`@Model`, `@Query`, `ModelContainer`, `ModelContext`)

---

## Settings/ — Preferences (8 files)

**Responsibilities:**
- Tabbed preferences window (5 tabs)
- General: launch at startup, notifications, dark mode appearance
- Recording: FPS, quality, mic/camera device pickers
- Webcam: shape picker, image adjustments (brightness/contrast/saturation/highlights/shadows), theme swatches, temperature/tint, live preview
- AI: API key input (file-based storage), auto-transcribe toggle
- Shortcuts: global hotkey recorder with UCKeyTranslate display strings
- All settings persisted via `@AppStorage` (UserDefaults)

**Key Types:**
- `SettingsView` — TabView shell (~24 lines)
- `GeneralSettingsTab`, `RecordingSettingsTab`, `WebcamSettingsTab`, `AISettingsTab`, `ShortcutsSettingsTab`
- `MicLevelMonitor` — real-time mic level display via AVCaptureAudioDataOutputSampleBufferDelegate (30Hz timer)
- `RecordingSettings` — @AppStorage backing types + VideoQuality enum

**macOS APIs:** `Settings` scene, `UserDefaults` / `@AppStorage`

**Note:** API keys stored in file at `~/Library/Application Support/Cloom/api_key` with `chmod 600` (not Keychain — avoids repeated prompts on debug rebuilds). Values passed to Rust as function parameters.

---

## AI/ — AI Feature Integration (4 files)

**Responsibilities:**
- Orchestrate post-recording AI pipeline (runs as Task.detached after recording)
- Extract audio from MP4 (prefers mic track, falls back to mix)
- Send audio file path to Rust for transcription (OpenAI whisper-1 via FFI)
- Detect filler words from transcript (Rust FFI)
- Request title/summary/chapters from Rust LLM client (gpt-4o-mini via FFI)
- Detect silence regions (Rust FFI)
- Store all results in SwiftData
- Track processing state for library card spinners
- Error alerts for pipeline failures

**Key Types:**
- `AIOrchestrator` (actor) — sequences all AI operations
- `AIProcessingTracker` — tracks which videos are being processed (spinner state)
- `AudioExtractor` — extract audio track from MP4 for transcription
- `KeychainService` — file-based API key storage (migrated from Keychain)

---

## Bridge/ — Swift-Rust FFI (3 generated files + 1 bridging header)

**Responsibilities:**
- Contains UniFFI-generated Swift bindings (auto-generated, gitignored)
- Bridging header includes generated C header (workaround for Xcode 26 explicit modules)
- Small surface area: audio processing + AI only
- Thread safety: Rust calls dispatched off main thread via actors

**Files:**
- `Cloom-Bridging-Header.h` — bridging header (checked in)
- `Generated/cloom_core.swift` — auto-generated Swift bindings
- `Generated/cloom_coreFFI.h` — auto-generated C header
- `Generated/cloom_coreFFI.modulemap` — auto-generated modulemap

---

## Shared/ — Utilities (3 files)

- `ThumbnailGenerator` — shared thumbnail extraction utility using AVAssetImageGenerator
- `SharedCIContext` — thread-safe singleton CIContext (Metal-backed) used across all compositing and rendering
- `LabeledSlider` — reusable slider component (extracted from WebcamSettingsTab)
