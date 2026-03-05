# Project Structure

```
cloom/
├── .claude/
│   ├── CLAUDE.md                       # Project instructions
│   ├── plans/                          # These plan files + PROGRESS.md
│   └── skills/build/                   # /build CLI skill
│
├── .github/
│   └── workflows/tests.yml            # CI: Rust tests + Swift tests
│
├── CloomApp/                           # Swift macOS app
│   ├── Sources/
│   │   ├── AI/
│   │   │   ├── AIOrchestrator.swift           # actor: transcribe → fillers → LLM → silence → persist
│   │   │   ├── AIProcessingTracker.swift      # Loading spinner state for library cards
│   │   │   ├── AudioExtractor.swift           # Extract audio track from MP4
│   │   │   └── KeychainService.swift          # API key storage (file-based ~/Library/Application Support/Cloom/)
│   │   ├── Annotations/
│   │   │   ├── AnnotationCanvasRenderer.swift # All drawing code (extracted from CanvasView)
│   │   │   ├── AnnotationCanvasView.swift     # SwiftUI Canvas with mouse/pressure tracking
│   │   │   ├── AnnotationCanvasWindow.swift   # Transparent NSPanel overlay for drawing
│   │   │   ├── AnnotationInputHandler.swift   # Mouse events, eraser (extracted from CanvasView)
│   │   │   ├── AnnotationModels.swift         # AnnotationTool, StrokePoint, StrokeColor, AnnotationStroke, ClickRipple, SpotlightState
│   │   │   ├── AnnotationRenderer.swift       # Burns annotations as CIImage into video frames
│   │   │   ├── AnnotationStore.swift          # @Observable store for real-time stroke editing
│   │   │   ├── AnnotationToolbarContentView.swift  # SwiftUI toolbar content
│   │   │   ├── AnnotationToolbarPanel.swift   # NSPanel for tool/color/width controls
│   │   │   ├── ClickEmphasisMonitor.swift     # CGEvent tap for click ripple effects
│   │   │   └── CursorSpotlightMonitor.swift   # Cursor position tracking for spotlight
│   │   ├── App/
│   │   │   ├── CloomApp.swift                 # @main, MenuBarExtra, single Window scene
│   │   │   ├── AppState.swift                 # @MainActor global state, cleanup, disk monitoring
│   │   │   ├── HotkeyNames.swift               # KeyboardShortcuts.Name extensions (.toggleRecording, .togglePause)
│   │   │   ├── MainWindowView.swift           # Single-window root: NavigationSplitView + mode switch
│   │   │   ├── NavigationState.swift          # @Observable navigation state (library/editor mode, view style)
│   │   │   ├── PermissionChecker.swift        # TCC permission detection + request
│   │   │   ├── OnboardingView.swift           # Permission setup flow with live status
│   │   │   ├── SparkleUpdater.swift           # Sparkle auto-update wrapper (SPUStandardUpdaterController)
│   │   │   └── Theme.swift                    # Dark mode semantic colors
│   │   ├── Bridge/
│   │   │   ├── Cloom-Bridging-Header.h        # Bridging header for UniFFI modulemap
│   │   │   └── Generated/                     # UniFFI auto-generated (gitignored)
│   │   │       ├── cloom_core.swift
│   │   │       ├── cloom_coreFFI.h
│   │   │       └── cloom_coreFFI.modulemap
│   │   ├── Cloud/
│   │   │   ├── DriveUploadManager.swift         # @Observable @MainActor upload coordinator
│   │   │   ├── DriveUploadService.swift         # actor: resumable upload to Google Drive v3
│   │   │   ├── GoogleAuthConfig.swift           # OAuth config (reads from Secrets.googleClientID)
│   │   │   ├── GoogleAuthService.swift          # @Observable @MainActor OAuth singleton
│   │   │   ├── Secrets.swift                    # GITIGNORED — real OAuth Client ID
│   │   │   └── Secrets.swift.example              # Template for contributors to copy (non-compilable extension)
│   │   ├── Capture/
│   │   │   ├── BubbleContentView.swift        # NSView for webcam bubble click/drag (extracted from WebcamBubbleWindow)
│   │   │   ├── BubbleLayerBuilder.swift       # Panel creation, emoji frame, rebuild (extracted from WebcamBubbleWindow)
│   │   │   ├── CameraService.swift            # AVCaptureSession wrapper, frame callback
│   │   │   ├── CaptureMode.swift              # enum: fullScreen, window, region
│   │   │   ├── ContentPicker.swift            # SCContentSharingPicker wrapper
│   │   │   ├── EmojiFrameRenderer.swift       # Shared sticker positioning + CGImage rendering
│   │   │   ├── MicGainProcessor.swift         # Mic sensitivity/gain applied to mic samples
│   │   │   ├── PersonSegmenter.swift          # VNGeneratePersonSegmentationRequest blur (throttled to every 5th frame)
│   │   │   ├── RegionSelectionWindow.swift    # Rubber-band NSPanel for region selection
│   │   │   ├── ScreenCapturePermission.swift  # TCC permission check
│   │   │   ├── ScreenCaptureService.swift     # SCStreamOutput per-frame pipeline + audio (OSAllocatedUnfairLock)
│   │   │   ├── ScreenCaptureService+Configuration.swift  # Filter builder, stream config, CaptureError
│   │   │   ├── ScreenCaptureService+StreamOutput.swift   # SCStreamOutput/Delegate implementations
│   │   │   ├── WebcamBubbleWindow.swift       # Circular/shaped draggable NSPanel
│   │   │   ├── WebcamFrame.swift              # Emoji frame decorations (geometric/tropical/celebration)
│   │   │   ├── WebcamImageAdjustments.swift   # CIColorControls + CIHighlightShadowAdjust + CITemperatureAndTint
│   │   │   └── WebcamShape.swift              # enum: circle, roundedRect, pill
│   │   ├── Compositing/
│   │   │   ├── ExportProgressWindow.swift     # Export/stitch progress modal
│   │   │   ├── SegmentStitcher.swift          # AVMutableComposition segment concatenation + audio mixdown
│   │   │   ├── VideoWriter.swift              # actor: AVAssetWriter, HEVC, dual audio inputs
│   │   │   ├── WebcamCompositor.swift         # Real-time CIContext circular overlay, Metal-backed
│   │   │   ├── WebcamCompositor+EmojiFrame.swift  # Emoji frame rendering + cache
│   │   │   └── WebcamCompositor+ShapeMask.swift   # Shape mask generation + cache
│   │   ├── Data/
│   │   │   ├── BookmarkModel.swift            # @Model BookmarkRecord (timestamped bookmarks)
│   │   │   ├── ChapterModel.swift             # @Model ChapterRecord
│   │   │   ├── CommentModel.swift             # @Model VideoComment (not yet used)
│   │   │   ├── EditDecisionListModel.swift    # @Model EditDecisionList (trim, cuts, stitch, speed)
│   │   │   ├── FolderModel.swift              # @Model FolderRecord (hierarchical)
│   │   │   ├── TagModel.swift                 # @Model TagRecord (color-coded)
│   │   │   ├── TranscriptModel.swift          # @Model TranscriptRecord + TranscriptWordRecord
│   │   │   ├── UploadStatus.swift              # Upload status enum (uploading/uploaded/failed)
│   │   │   ├── VideoModel.swift               # @Model VideoRecord
│   │   │   └── ViewEventModel.swift           # @Model ViewEvent (not yet used)
│   │   ├── Editor/
│   │   │   ├── BookmarksPanelView.swift       # Bookmark list sidebar (add/edit/delete, seek on click)
│   │   │   ├── CaptionOverlayView.swift       # Karaoke word-by-word highlight
│   │   │   ├── ChapterNavigationView.swift    # Popover + timeline markers
│   │   │   ├── CutRegionOverlay.swift         # Red hatched cut regions
│   │   │   ├── EditorCompositionBuilder.swift # EDL → AVMutableComposition (multi-track audio)
│   │   │   ├── EditorContentView.swift        # Editor in-window view with back navigation
│   │   │   ├── EditorExportView.swift         # Export + Upload to Drive sheet (quality, subtitles, brightness/contrast, passthrough)
│   │   │   ├── EditorInfoPanel.swift          # Info sidebar (title, summary, metadata)
│   │   │   ├── EditorState.swift              # @Observable @MainActor editing state
│   │   │   ├── EditorState+Bookmarks.swift    # Bookmark CRUD extension
│   │   │   ├── EditorToolbarView.swift        # Playback/cut/chapter/export controls
│   │   │   ├── HoverButtonStyle.swift         # Subtle hover background for icon-only toolbar buttons
│   │   │   ├── ExportWriter.swift             # AVAssetReader/Writer + tx3g subtitle embedding (remux + re-encode)
│   │   │   ├── ExportService.swift              # MP4 export logic (extracted from EditorExportView)
│   │   │   ├── ExportWriter+Subtitles.swift    # tx3g subtitle track embedding extension
│   │   │   ├── SpeedControlView.swift         # 0.25x–4x popover
│   │   │   ├── StitchPanelView.swift          # Multi-clip drag-to-reorder
│   │   │   ├── SubtitleExportService.swift    # EDL-aware subtitle phrase building + timing
│   │   │   ├── ThumbnailPickerView.swift      # Frame selection + "Use Current Frame"
│   │   │   ├── ThumbnailStripGenerator.swift  # Preview strip for timeline
│   │   │   ├── TimelineView.swift             # EditorTimelineView (waveform + thumbnails + playhead + bookmarks)
│   │   │   ├── TranscriptPanelView.swift      # Right sidebar, click-to-seek, auto-scroll
│   │   │   ├── TrimHandlesView.swift          # Yellow drag handles + grayed overlay
│   │   │   ├── VideoPreviewView.swift         # AVPlayer + PiP/fullscreen coordinator
│   │   │   └── WaveformGenerator.swift        # Audio waveform peaks
│   │   ├── Library/
│   │   │   ├── BulkTagSheet.swift             # Bulk tag assignment
│   │   │   ├── FolderPickerSheet.swift        # Move videos to folders
│   │   │   ├── LibraryContentView.swift       # Detail content: grid/list views, filtering, sorting, search
│   │   │   ├── LibraryFilterModels.swift      # Sort/filter enums
│   │   │   ├── LibraryListRowView.swift       # Compact list row with thumbnail, title, duration, date
│   │   │   ├── LibrarySidebarView.swift       # Folders + tags navigation
│   │   │   ├── LibraryVideoGrid.swift         # Grid item, context menu, selection badge
│   │   │   ├── ProcessingCardView.swift       # Post-recording processing placeholder card
│   │   │   ├── TagEditorView.swift            # 8-preset color picker + CRUD
│   │   │   └── VideoCardView.swift            # Thumbnail + duration badge + metadata card
│   │   ├── Recording/
│   │   │   ├── BubbleControlPill.swift            # Floating pill on webcam bubble
│   │   │   ├── CountdownOverlayWindow.swift       # 3-2-1 countdown
│   │   │   ├── DiscardConfirmationWindow.swift    # Discard alert
│   │   │   ├── RecordingCoordinator.swift         # @MainActor central orchestrator
│   │   │   ├── RecordingCoordinator+Annotations.swift  # Canvas/toolbar management
│   │   │   ├── RecordingCoordinator+Capture.swift      # Capture setup extension
│   │   │   ├── RecordingCoordinator+CaptureDelegate.swift # AVCaptureDelegate conformance
│   │   │   ├── RecordingCoordinator+PauseResume.swift  # Pause/resume/segment management
│   │   │   ├── RecordingCoordinator+PostRecording.swift # Post-recording pipeline
│   │   │   ├── RecordingCoordinator+Toggles.swift      # Mic/camera/blur/annotation toggles
│   │   │   ├── RecordingCoordinator+UI.swift            # Window management
│   │   │   ├── RecordingCoordinator+Webcam.swift        # Webcam start/stop/preview/adjustments
│   │   │   ├── RecordingMetrics.swift              # Frame/drop/segment/memory instrumentation (60s periodic + final log)
│   │   │   ├── RecordingState.swift               # enum: idle, selectingContent, countdown, recording, paused, stopping
│   │   │   ├── RecordingToolbarPanel.swift        # NSPanel window management
│   │   │   ├── RecordingToolbarContentView.swift  # Recording-state toolbar SwiftUI view
│   │   │   ├── ReadyToolbarContentView.swift      # Ready-state toolbar SwiftUI view
│   │   │   └── RegionHighlightOverlay.swift       # Region selection feedback
│   │   ├── Settings/
│   │   │   ├── AISettingsTab.swift                # API key (file-based), auto-transcribe toggle
│   │   │   ├── GeneralSettingsTab.swift           # Launch at startup, notifications, appearance
│   │   │   ├── MicLevelMonitor.swift              # Real-time mic level display (30Hz timer)
│   │   │   ├── RecordingSettings.swift            # @AppStorage backing types + VideoQuality enum
│   │   │   ├── RecordingSettingsTab.swift         # FPS, quality, mic sensitivity, device pickers
│   │   │   ├── CloudSettingsTab.swift              # Google OAuth client ID + account management
│   │   │   ├── SettingsView.swift                 # TabView shell (~24 lines)
│   │   │   ├── ShortcutsSettingsTab.swift         # Global hotkey recorder
│   │   │   └── WebcamSettingsTab.swift            # Shape, adjustments, theme, temperature/tint
│   │   └── Shared/
│   │       ├── LabeledSlider.swift                # Reusable slider component (extracted from WebcamSettingsTab)
│   │       ├── SharedCIContext.swift               # Thread-safe singleton CIContext (Metal-backed)
│   │       ├── ThumbnailGenerator.swift           # Shared thumbnail utility
│   │       └── ToolbarToggleButton.swift          # Reusable toggle button for toolbars
│   └── Resources/
│       ├── Assets.xcassets                        # App icon + menu bar icon
│       ├── Info.plist                             # TCC descriptions, SUFeedURL, SUPublicEDKey, $(GOOGLE_REVERSED_CLIENT_ID)
│       ├── Cloom.entitlements                     # App sandbox + capabilities
│       └── Secrets.xcconfig.example               # Template for Google OAuth build-time variables
│
├── CloomTests/                        # Swift unit tests
│   ├── CacheTests.swift               # FrameImageCache + ShapeMaskCache eviction behavior
│   ├── CloudTests.swift               # UploadStatus + GoogleAuthConfig tests
│   ├── DataModelTests.swift           # VideoRecord, FolderRecord, TagRecord, EDL, Transcript, Chapter, Bookmark
│   ├── FFIBridgeTests.swift           # helloFromRust + cloomCoreVersion semver validation
│   ├── LibraryFilterTests.swift       # LibrarySortOrder (7 cases) + TranscriptFilter tests
│   └── RecordingSettingsTests.swift   # VideoQuality enum, RecordingSettings defaults
│
├── cloom-core/                        # Rust library (Cargo project)
│   ├── Cargo.toml
│   ├── Cargo.lock
│   ├── src/
│   │   ├── lib.rs                     # UniFFI scaffolding + CloomError + hello_from_rust
│   │   ├── runtime.rs                 # Shared Tokio runtime (LazyLock singleton)
│   │   ├── ai/
│   │   │   ├── mod.rs
│   │   │   ├── transcribe.rs         # OpenAI whisper-1 multipart upload
│   │   │   ├── llm.rs               # OpenAI gpt-4o-mini: title/summary/chapters/paragraphs
│   │   │   └── llm_tests.rs         # LLM client tests (extracted from llm.rs)
│   │   └── audio/
│   │       ├── mod.rs
│   │       ├── filler.rs            # Single + multi-word filler detection
│   │       ├── silence.rs           # Symphonia decode + RMS silence detection
│   │       └── silence_tests.rs     # Silence detection tests (extracted from silence.rs)
│   └── tests/
│       └── fixtures/                 # Test data
│           ├── chapters_response.json
│           ├── chat_completion_response.json
│           └── transcription_response.json
│
├── LICENSE                            # MIT license
├── README.md                          # Project description, build instructions
├── libs/
│   └── libcloom_core.a               # Compiled Rust static library (~50 MB)
│
├── build.sh                           # Rust build + UniFFI codegen + copy .a to libs/
├── project.yml                        # xcodegen configuration
├── scripts/
│   ├── release.sh                     # Local release build (Rust → Xcode → DMG + EdDSA sign)
│   └── generate-appcast.sh            # Generate/update Sparkle appcast.xml
└── .gitignore
```

## Module Summary (117 Swift files, 12 Rust files)

| Module | Files | Description |
|--------|-------|-------------|
| AI/ | 4 | AI orchestration pipeline, audio extraction, API key storage |
| Annotations/ | 11 | Drawing tools, canvas, input handler, renderer, click/cursor effects |
| App/ | 9 | App entry, state, navigation, main window, hotkeys, permissions, onboarding, Sparkle updater, theme |
| Bridge/ | 3 | UniFFI generated bindings (gitignored) |
| Capture/ | 18 | Screen capture, camera, webcam UI, shapes, themes, adjustments, mic gain |
| Compositing/ | 6 | VideoWriter, webcam compositor (+ shape/emoji extensions), segment stitcher, export progress |
| Data/ | 9 | SwiftData models (VideoRecord, FolderRecord, TagRecord, BookmarkRecord, etc.) |
| Editor/ | 23 | EditorContentView, timeline, trim, cut, stitch, speed, export, subtitles, captions, transcript, chapters, bookmarks |
| Library/ | 10 | Grid, list, sidebar, cards, processing card, tags, folders, filter models |
| Recording/ | 15 | Coordinator (split into 8 files), toolbar, pill, discard, countdown, region overlay |
| Settings/ | 8 | Tabbed settings (5 tabs + shell + backing types + mic level monitor) |
| Shared/ | 4 | Thumbnail generator, SharedCIContext, LabeledSlider, ToolbarToggleButton |

## Critical Files (by importance)

1. `CloomApp/Sources/Recording/RecordingCoordinator.swift` + 7 extensions — Central state machine, heart of the app
2. `CloomApp/Sources/Capture/ScreenCaptureService.swift` + 2 extensions — SCStreamOutput per-frame pipeline
3. `CloomApp/Sources/Compositing/VideoWriter.swift` — AVAssetWriter actor, HEVC encoding
4. `CloomApp/Sources/Compositing/WebcamCompositor.swift` + 2 extensions — Real-time webcam overlay
5. `CloomApp/Sources/Annotations/AnnotationRenderer.swift` — Real-time annotation burn-in
6. `CloomApp/Sources/Data/VideoModel.swift` — SwiftData video record
7. `CloomApp/Sources/Editor/EditorState.swift` + bookmark extension — @Observable editing state
8. `CloomApp/Sources/Editor/EditorContentView.swift` — Main editor UI (in-window)
9. `cloom-core/src/lib.rs` — FFI entry point
10. `build.sh` — Glue between Rust and Swift worlds
