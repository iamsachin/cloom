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
│   │   │   └── KeychainService.swift          # API key storage (file-based ~/Library/Application Support/Cloom/)
│   │   ├── Annotations/
│   │   │   ├── AnnotationCanvasWindow.swift   # Transparent NSPanel overlay for drawing
│   │   │   ├── AnnotationCanvasView.swift     # SwiftUI Canvas with mouse/pressure tracking
│   │   │   ├── AnnotationStore.swift          # @Observable store for real-time stroke editing
│   │   │   ├── AnnotationModels.swift         # AnnotationTool, StrokePoint, StrokeColor, AnnotationStroke, ClickRipple, SpotlightState
│   │   │   ├── AnnotationRenderer.swift       # Burns annotations as CIImage into video frames
│   │   │   ├── AnnotationToolbarPanel.swift   # NSPanel for tool/color/width controls
│   │   │   ├── AnnotationToolbarContentView.swift  # SwiftUI toolbar content
│   │   │   ├── ClickEmphasisMonitor.swift     # CGEvent tap for click ripple effects
│   │   │   └── CursorSpotlightMonitor.swift   # Cursor position tracking for spotlight
│   │   ├── App/
│   │   │   ├── CloomApp.swift                 # @main, MenuBarExtra, WindowGroup scenes
│   │   │   ├── AppState.swift                 # @MainActor global state, cleanup, disk monitoring
│   │   │   ├── GlobalHotkeyManager.swift      # CGEvent tap hotkeys (Cmd+Shift+R, etc.)
│   │   │   ├── PermissionChecker.swift        # TCC permission detection + request
│   │   │   ├── OnboardingView.swift           # Permission setup flow with live status
│   │   │   └── Theme.swift                    # Dark mode semantic colors
│   │   ├── Bridge/
│   │   │   ├── Cloom-Bridging-Header.h        # Bridging header for UniFFI modulemap
│   │   │   └── Generated/                     # UniFFI auto-generated (gitignored)
│   │   │       ├── cloom_core.swift
│   │   │       ├── cloom_coreFFI.h
│   │   │       └── cloom_coreFFI.modulemap
│   │   ├── Capture/
│   │   │   ├── CaptureMode.swift              # enum: fullScreen, window, region, webcamOnly
│   │   │   ├── ScreenCaptureService.swift     # SCStreamOutput per-frame pipeline + audio
│   │   │   ├── ScreenCapturePermission.swift  # TCC permission check
│   │   │   ├── ContentPicker.swift            # SCContentSharingPicker wrapper
│   │   │   ├── RegionSelectionWindow.swift    # Rubber-band NSPanel for region selection
│   │   │   ├── CameraService.swift            # AVCaptureSession wrapper, frame callback
│   │   │   ├── PersonSegmenter.swift          # VNGeneratePersonSegmentationRequest blur
│   │   │   ├── WebcamBubbleWindow.swift       # Circular/shaped draggable NSPanel
│   │   │   ├── WebcamRecordingService.swift   # Webcam-only AVAssetWriter recording
│   │   │   ├── WebcamShape.swift              # enum: circle, roundedRect, pill
│   │   │   ├── WebcamFrame.swift               # Emoji frame decorations (geometric/tropical/celebration)
│   │   │   ├── EmojiFrameRenderer.swift       # Shared sticker positioning + CGImage rendering
│   │   │   ├── WebcamImageAdjustments.swift   # CIColorControls + CIHighlightShadowAdjust + CITemperatureAndTint
│   │   │   └── NoiseCancellationProcessor.swift  # RMS noise gate on mic samples
│   │   ├── Compositing/
│   │   │   ├── VideoWriter.swift              # actor: AVAssetWriter, HEVC, dual audio inputs
│   │   │   ├── WebcamCompositor.swift         # Real-time CIContext circular overlay, Metal-backed
│   │   │   ├── SegmentStitcher.swift          # AVMutableComposition segment concatenation
│   │   │   └── ExportProgressWindow.swift     # Export/stitch progress modal
│   │   ├── Data/
│   │   │   ├── VideoModel.swift               # @Model VideoRecord
│   │   │   ├── FolderModel.swift              # @Model FolderRecord (hierarchical)
│   │   │   ├── TagModel.swift                 # @Model TagRecord (color-coded)
│   │   │   ├── TranscriptModel.swift          # @Model TranscriptRecord + TranscriptWordRecord
│   │   │   ├── ChapterModel.swift             # @Model ChapterRecord
│   │   │   ├── EditDecisionListModel.swift    # @Model EditDecisionList (trim, cuts, stitch, speed)
│   │   │   ├── CommentModel.swift             # @Model VideoComment (not yet used)
│   │   │   └── ViewEventModel.swift           # @Model ViewEvent (not yet used)
│   │   ├── Editor/
│   │   │   ├── EditorView.swift               # Main editor window (1000x700)
│   │   │   ├── EditorState.swift              # @MainActor @ObservableObject editing state
│   │   │   ├── EditorCompositionBuilder.swift # EDL → AVMutableComposition
│   │   │   ├── TimelineView.swift             # EditorTimelineView (waveform + thumbnails + playhead)
│   │   │   ├── TrimHandlesView.swift          # Yellow drag handles + grayed overlay
│   │   │   ├── CutRegionOverlay.swift         # Red hatched cut regions
│   │   │   ├── VideoPreviewView.swift         # AVPlayer + PiP/fullscreen coordinator
│   │   │   ├── CaptionOverlayView.swift       # Karaoke word-by-word highlight
│   │   │   ├── TranscriptPanelView.swift      # Right sidebar, click-to-seek, auto-scroll
│   │   │   ├── ChapterNavigationView.swift    # Popover + timeline markers
│   │   │   ├── StitchPanelView.swift          # Multi-clip drag-to-reorder
│   │   │   ├── SpeedControlView.swift         # 0.25x–4x popover
│   │   │   ├── ThumbnailPickerView.swift      # Frame selection + "Use Current Frame"
│   │   │   ├── ThumbnailStripGenerator.swift  # Preview strip for timeline
│   │   │   ├── WaveformGenerator.swift        # Audio waveform peaks
│   │   │   ├── EditorExportView.swift         # Quality picker + brightness/contrast adjustments
│   │   │   └── GifExportService.swift         # Rust gifski FFI bridge
│   │   ├── Library/
│   │   │   ├── LibraryView.swift              # Grid + hover preview + sort/filter
│   │   │   ├── LibrarySidebarView.swift       # Folders + tags navigation
│   │   │   ├── VideoCardView.swift            # Thumbnail + metadata + context menu
│   │   │   ├── TagEditorView.swift            # 8-preset color picker + CRUD
│   │   │   ├── BulkTagSheet.swift             # Bulk tag assignment
│   │   │   └── FolderPickerSheet.swift        # Move videos to folders
│   │   ├── Player/
│   │   │   └── PlayerView.swift               # AVPlayer wrapper (legacy, most player in Editor/)
│   │   ├── Recording/
│   │   │   ├── RecordingCoordinator.swift         # @MainActor central orchestrator (~350 lines)
│   │   │   ├── RecordingCoordinator+Capture.swift       # Capture setup extension
│   │   │   ├── RecordingCoordinator+CaptureDelegate.swift # AVCaptureDelegate conformance
│   │   │   ├── RecordingCoordinator+PostRecording.swift   # Post-recording pipeline
│   │   │   ├── RecordingCoordinator+UI.swift              # Window management
│   │   │   ├── RecordingState.swift               # enum: idle, selectingContent, countdown, recording, paused, stopping
│   │   │   ├── RecordingToolbarPanel.swift        # NSPanel with mode/toggle controls
│   │   │   ├── BubbleControlPill.swift            # Floating pill on webcam bubble
│   │   │   ├── DiscardConfirmationWindow.swift    # Discard alert
│   │   │   ├── CountdownOverlayWindow.swift       # 3-2-1 countdown
│   │   │   └── RegionHighlightOverlay.swift       # Region selection feedback
│   │   ├── Settings/
│   │   │   ├── SettingsView.swift                 # TabView shell (~24 lines)
│   │   │   ├── GeneralSettingsTab.swift           # Launch at startup, notifications, appearance
│   │   │   ├── RecordingSettingsTab.swift         # FPS, quality, mic/camera device pickers
│   │   │   ├── WebcamSettingsTab.swift            # Shape, adjustments, theme, temperature/tint
│   │   │   ├── AISettingsTab.swift                # API key (file-based), auto-transcribe toggle
│   │   │   ├── ShortcutsSettingsTab.swift         # Global hotkey recorder
│   │   │   └── RecordingSettings.swift            # @AppStorage backing types + VideoQuality enum
│   │   └── Shared/
│   │       └── ThumbnailGenerator.swift           # Shared thumbnail utility
│   └── Resources/
│       ├── Assets.xcassets
│       ├── Info.plist                             # TCC usage descriptions
│       └── Cloom.entitlements                     # App sandbox + capabilities
│
├── CloomTests/                        # Swift unit tests (32 tests)
│   ├── DataModelTests.swift           # VideoRecord, FolderRecord, TagRecord, EDL, Transcript, Chapter, Bookmark
│   └── RecordingSettingsTests.swift   # VideoQuality enum, RecordingSettings defaults
│
├── cloom-core/                        # Rust library (Cargo project)
│   ├── Cargo.toml
│   ├── Cargo.lock
│   ├── src/
│   │   ├── lib.rs                     # UniFFI scaffolding + CloomError + hello_from_rust
│   │   ├── gif_export.rs             # gifski PNG manifest → GIF encoder
│   │   ├── ai/
│   │   │   ├── mod.rs
│   │   │   ├── transcribe.rs         # OpenAI whisper-1 multipart upload
│   │   │   └── llm.rs               # OpenAI gpt-4o-mini: title/summary/chapters
│   │   └── audio/
│   │       ├── mod.rs
│   │       ├── filler.rs            # Single + multi-word filler detection
│   │       └── silence.rs           # Symphonia decode + RMS silence detection
│   └── tests/
│       └── fixtures/                 # Test data
│           ├── chapters_response.json
│           ├── chat_completion_response.json
│           └── transcription_response.json
│
├── libs/
│   └── libcloom_core.a               # Compiled Rust static library (~50 MB)
│
├── build.sh                           # Rust build + UniFFI codegen + copy .a to libs/
├── project.yml                        # xcodegen configuration
└── .gitignore
```

## Module Summary (87 Swift files, 8 Rust files)

| Module | Files | Description |
|--------|-------|-------------|
| AI/ | 3 | AI orchestration pipeline, API key storage |
| Annotations/ | 9 | Drawing tools, canvas, click/cursor effects, renderer |
| App/ | 6 | App entry, state, hotkeys, permissions, onboarding, theme |
| Bridge/ | 3 | UniFFI generated bindings (gitignored) |
| Capture/ | 13 | Screen capture, camera, webcam UI, shapes, themes, adjustments, noise |
| Compositing/ | 4 | VideoWriter, webcam compositor, segment stitcher, export progress |
| Data/ | 8 | SwiftData models |
| Editor/ | 17 | Timeline, trim, cut, stitch, speed, export, GIF, captions, transcript, chapters |
| Library/ | 6 | Grid, sidebar, cards, tags, folders |
| Player/ | 1 | Legacy AVPlayer wrapper |
| Recording/ | 11 | Coordinator (split into 5 files), toolbar, pill, discard, countdown |
| Settings/ | 7 | Tabbed settings (5 tabs + shell + backing types) |
| Shared/ | 1 | Thumbnail generator |

## Critical Files (by importance)

1. `CloomApp/Sources/Recording/RecordingCoordinator.swift` + extensions — Central state machine, heart of the app
2. `CloomApp/Sources/Capture/ScreenCaptureService.swift` — SCStreamOutput per-frame pipeline
3. `CloomApp/Sources/Compositing/VideoWriter.swift` — AVAssetWriter actor, HEVC encoding
4. `CloomApp/Sources/Compositing/WebcamCompositor.swift` — Real-time webcam overlay
5. `CloomApp/Sources/Annotations/AnnotationRenderer.swift` — Real-time annotation burn-in
6. `CloomApp/Sources/Data/VideoModel.swift` — SwiftData video record
7. `CloomApp/Sources/Editor/EditorView.swift` — Main editor UI
8. `cloom-core/src/lib.rs` — FFI entry point
9. `build.sh` — Glue between Rust and Swift worlds
