# Project Structure

```
cloom/
├── .claude/
│   ├── CLAUDE.md                       # Project instructions
│   └── plans/                          # These plan files
│
├── CloomApp/                           # Swift macOS app (Xcode primary; optional SPM modularization)
│   ├── Package.swift                   # Swift Package Manager manifest
│   ├── Sources/
│   │   ├── App/
│   │   │   ├── CloomApp.swift              # @main, MenuBarExtra, WindowGroup
│   │   │   ├── AppState.swift              # Global observable state
│   │   │   ├── PermissionsManager.swift    # TCC permission handling
│   │   │   └── KeyboardShortcutManager.swift
│   │   ├── Capture/
│   │   │   ├── ScreenCaptureService.swift      # Protocol
│   │   │   ├── DefaultScreenCaptureService.swift  # SCKit implementation
│   │   │   ├── CaptureConfiguration.swift
│   │   │   └── RegionSelectionWindow.swift     # Custom area selection
│   │   ├── Camera/
│   │   │   ├── CameraService.swift             # Protocol
│   │   │   ├── DefaultCameraService.swift      # AVCaptureSession
│   │   │   └── PersonSegmentation.swift        # Vision framework bg blur
│   │   ├── Recording/
│   │   │   ├── RecordingCoordinator.swift       # Central state machine (CRITICAL)
│   │   │   ├── RecordingState.swift             # Enum: idle/countdown/recording/paused/stopped
│   │   │   ├── RecordingMode.swift              # screen+cam, screen, cam
│   │   │   └── CountdownView.swift
│   │   ├── Compositing/
│   │   │   ├── CompositingService.swift         # Protocol
│   │   │   ├── DefaultCompositingService.swift  # AVMutableComposition + custom compositor
│   │   │   ├── WebcamCompositor.swift           # AVVideoCompositing for webcam overlay
│   │   │   └── AnnotationRenderer.swift         # CoreImage/CoreGraphics annotation burn-in
│   │   ├── Export/
│   │   │   ├── ExportService.swift              # Protocol
│   │   │   ├── MP4ExportService.swift           # AVMutableComposition + EDL → MP4
│   │   │   └── ExportProgressReporter.swift     # Progress callbacks
│   │   ├── Overlay/
│   │   │   ├── WebcamBubbleWindow.swift         # NSPanel, circular, draggable
│   │   │   ├── RecordingControlBar.swift        # Floating toolbar
│   │   │   ├── DrawingCanvasView.swift          # Annotation engine (CRITICAL)
│   │   │   ├── DrawingToolbar.swift
│   │   │   └── MouseEmphasisView.swift          # Click ripple effect
│   │   ├── Editor/
│   │   │   ├── EditorView.swift                 # Main editor UI
│   │   │   ├── TimelineView.swift               # Scrubber + waveform
│   │   │   ├── TrimHandleView.swift
│   │   │   └── EditDecisionList.swift           # Non-destructive edit model
│   │   ├── Player/
│   │   │   ├── VideoPlayerView.swift            # AVPlayer wrapper
│   │   │   ├── CaptionOverlay.swift
│   │   │   ├── TranscriptPanel.swift
│   │   │   └── ChapterNavigation.swift
│   │   ├── Library/
│   │   │   ├── LibraryView.swift                # Grid/list of videos
│   │   │   ├── VideoCardView.swift              # Thumbnail + metadata
│   │   │   ├── FolderSidebar.swift
│   │   │   └── SearchBar.swift
│   │   ├── Data/
│   │   │   ├── VideoModel.swift                 # @Model SwiftData video record
│   │   │   ├── FolderModel.swift                # @Model SwiftData folder
│   │   │   ├── TagModel.swift                   # @Model SwiftData tag
│   │   │   ├── TranscriptModel.swift            # @Model SwiftData transcript
│   │   │   ├── CommentModel.swift               # @Model SwiftData comment
│   │   │   ├── ViewEventModel.swift             # @Model SwiftData view event
│   │   │   └── DataManager.swift                # ModelContainer setup, migrations
│   │   ├── Settings/
│   │   │   ├── SettingsView.swift               # Preferences window
│   │   │   ├── GeneralSettings.swift
│   │   │   ├── RecordingSettings.swift
│   │   │   ├── AISettings.swift                 # API key management
│   │   │   ├── ShortcutSettings.swift
│   │   │   └── PreferencesManager.swift         # UserDefaults wrapper
│   │   ├── AI/
│   │   │   ├── AIOrchestrator.swift             # Post-recording AI pipeline
│   │   │   └── TranscriptionService.swift       # Wraps Rust AI bridge calls
│   │   ├── Bridge/
│   │   │   └── Generated/                       # UniFFI auto-generated Swift
│   │   └── Shared/
│   │       ├── Models.swift                     # Shared Swift value types
│   │       └── Extensions.swift
│   ├── Resources/
│   │   ├── Assets.xcassets
│   │   └── Info.plist                           # NSScreenCaptureUsageDescription, etc.
│   └── Tests/
│       ├── CaptureTests/
│       ├── RecordingTests/
│       ├── CompositingTests/
│       ├── ExportTests/
│       ├── EditorTests/
│       ├── PlayerTests/
│       ├── DataTests/
│       └── LibraryTests/
│
├── cloom-core/                         # Rust library (Cargo project)
│   ├── Cargo.toml
│   ├── build.rs                        # UniFFI scaffolding (proc macros)
│   ├── src/
│   │   ├── lib.rs                      # UniFFI exports + all FFI types
│   │   ├── audio/
│   │   │   ├── mod.rs                  # Audio processing entry
│   │   │   ├── silence.rs              # Silence detection via symphonia
│   │   │   └── filler.rs               # Filler word identification
│   │   ├── ai/
│   │   │   ├── mod.rs
│   │   │   ├── transcribe.rs           # OpenAI gpt-4o-mini-transcribe client (v1 default)
│   │   │   └── llm.rs                  # OpenAI LLM client (v1) with provider abstraction
│   │   └── export/
│   │       └── gif.rs                  # GIF generation
│   └── tests/
│       └── fixtures/                   # Test data (audio, API responses)
│
├── build.sh                            # Orchestrates Rust build + UniFFI codegen
├── .gitignore
└── README.md
```

## Critical Files (implementation priority)

1. `CloomApp/Sources/Recording/RecordingCoordinator.swift` — Central state machine, heart of the app
2. `CloomApp/Sources/Capture/DefaultScreenCaptureService.swift` — ScreenCaptureKit wrapper
3. `CloomApp/Sources/Data/VideoModel.swift` — SwiftData video record, foundation everything depends on
4. `CloomApp/Sources/Compositing/DefaultCompositingService.swift` — AVMutableComposition + webcam overlay
5. `CloomApp/Sources/Overlay/DrawingCanvasView.swift` — Most complex UI component
6. `cloom-core/src/lib.rs` — FFI entry point, all Rust-side types and exported functions
7. `build.sh` — Glue between Rust and Swift worlds
