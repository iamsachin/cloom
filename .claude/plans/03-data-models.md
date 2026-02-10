# Data Models

> Note: All model snippets in this document are conceptual pseudocode for architecture planning, not compile-ready source.

## Swift Models — SwiftData (@Model)

These are the persistent data models stored via SwiftData. They replace the previous Rust SQLite approach.
Cloud collaboration/sync features are out of scope for v1.

### Video

```swift
@Model
final class VideoRecord {
    @Attribute(.unique) var id: String  // UUID string
    var title: String
    var filePath: String
    var thumbnailPath: String
    var durationMs: Int64
    var createdAt: Date
    var updatedAt: Date
    var width: Int32
    var height: Int32
    var fileSizeBytes: Int64
    var recordingType: String  // "screenAndWebcam" | "screenOnly" | "webcamOnly"

    // Relationships
    @Relationship var folder: FolderRecord?
    @Relationship(inverse: \TagRecord.videos) var tags: [TagRecord]
    @Relationship(cascade: .delete) var transcript: TranscriptRecord?
    @Relationship(cascade: .delete) var chapters: [ChapterRecord]
    @Relationship(cascade: .delete) var comments: [VideoComment]
    @Relationship(cascade: .delete) var viewEvents: [ViewEvent]

    // AI-generated
    var hasTranscript: Bool
    var summary: String?

    // Optional future fields (disabled in v1 local-only scope)
    var syncStatus: String  // "local" | "synced" | "pendingUpload" | "pendingDelete"
    var remoteID: String?
    var lastSyncedAt: Date?
}
```

### Folder

```swift
@Model
final class FolderRecord {
    @Attribute(.unique) var id: String
    var name: String
    var createdAt: Date

    @Relationship var parent: FolderRecord?
    @Relationship(cascade: .delete, inverse: \FolderRecord.parent) var children: [FolderRecord]
    @Relationship(inverse: \VideoRecord.folder) var videos: [VideoRecord]

    // Optional future fields (disabled in v1 local-only scope)
    var syncStatus: String
    var remoteID: String?
    var lastSyncedAt: Date?

    var videoCount: Int { videos.count }
}
```

### Tag

```swift
@Model
final class TagRecord {
    @Attribute(.unique) var id: String
    var name: String
    var color: String  // Hex color

    @Relationship var videos: [VideoRecord]
}
```

### Transcript

```swift
@Model
final class TranscriptRecord {
    @Attribute(.unique) var id: String
    var videoID: String
    var fullText: String
    var language: String

    @Relationship(cascade: .delete) var words: [TranscriptWordRecord]
    @Relationship(inverse: \VideoRecord.transcript) var video: VideoRecord?
}

@Model
final class TranscriptWordRecord {
    var word: String
    var startMs: Int64
    var endMs: Int64
    var confidence: Float
    var isFillerWord: Bool

    @Relationship(inverse: \TranscriptRecord.words) var transcript: TranscriptRecord?
}
```

### Chapter

```swift
@Model
final class ChapterRecord {
    @Attribute(.unique) var id: String
    var title: String
    var startMs: Int64

    @Relationship(inverse: \VideoRecord.chapters) var video: VideoRecord?
}
```

### Comment & Analytics

```swift
@Model
final class VideoComment {
    @Attribute(.unique) var id: String
    var timestampMs: Int64?
    var text: String
    var createdAt: Date

    @Relationship(inverse: \VideoRecord.comments) var video: VideoRecord?
}

@Model
final class ViewEvent {
    var viewedAt: Date
    var durationWatchedMs: Int64

    @Relationship(inverse: \VideoRecord.viewEvents) var video: VideoRecord?
}
```

---

## Swift Models — Value Types (Shared/Models.swift)

These are non-persistent value types used by UI, recording, and editing.

### Recording Configuration

```swift
enum RecordingState: Equatable {
    case idle
    case preparingCapture
    case countdown(remaining: Int)
    case recording(elapsed: TimeInterval, isPaused: Bool)
    case stopping
    case stopped(videoID: String)
    case error(String)
}

enum RecordingMode: String, Codable, CaseIterable {
    case screenAndWebcam
    case screenOnly
    case webcamOnly
}

enum CaptureSource: Codable {
    case fullScreen(displayID: CGDirectDisplayID)
    case window(windowID: CGWindowID, appName: String)
    case region(rect: CGRect, displayID: CGDirectDisplayID)
}

enum VideoQuality: String, Codable, CaseIterable {
    case low      // 720p, 2 Mbps
    case medium   // 1080p, 5 Mbps
    case high     // 1440p, 10 Mbps
    case ultra    // Native, 20 Mbps
}

enum FrameRate: Int, Codable, CaseIterable {
    case fps24 = 24
    case fps30 = 30
    case fps60 = 60
}

enum VideoCodec: String, Codable, CaseIterable {
    case h264
    case h265
}

struct RecordingConfiguration: Codable {
    var mode: RecordingMode
    var captureSource: CaptureSource?
    var quality: VideoQuality
    var frameRate: FrameRate
    var codec: VideoCodec
    var captureSystemAudio: Bool
    var captureMicrophone: Bool
    var selectedMicrophoneID: String?
    var selectedCameraID: String?
    var countdownSeconds: Int  // 0 = no countdown
    var showCursorInRecording: Bool
}
```

### Webcam Bubble

```swift
enum BubbleSize: String, Codable, CaseIterable {
    case small   // 120pt diameter
    case medium  // 180pt
    case large   // 280pt

    var diameter: CGFloat {
        switch self {
        case .small: return 120
        case .medium: return 180
        case .large: return 280
        }
    }
}

enum BubblePosition: Codable {
    case preset(corner: Corner)
    case custom(point: CGPoint)

    enum Corner: String, Codable, CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight
    }
}

struct WebcamBubbleConfig: Codable {
    var size: BubbleSize
    var position: BubblePosition
    var isMirrored: Bool
    var backgroundMode: BackgroundMode
}

enum BackgroundMode: Codable {
    case none
    case blur(radius: Float)
    case virtualBackground(imagePath: String)
}
```

### Drawing / Annotations

```swift
enum DrawingTool: String, Codable, CaseIterable {
    case pen, highlighter, arrow, rectangle, ellipse, eraser
}

struct DrawingStroke: Codable, Identifiable {
    let id: UUID
    var tool: DrawingTool
    var points: [CGPoint]
    var color: CodableColor
    var lineWidth: CGFloat
    var opacity: CGFloat  // 1.0 for pen, 0.3 for highlighter
    var startMs: UInt64    // timestamp relative to recording start
    var endMs: UInt64      // when the stroke should disappear (0 = permanent)
}

struct CodableColor: Codable {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    var alpha: CGFloat
}
```

### Editor

```swift
struct EditDecisionList: Codable {
    var operations: [EditOperation]
}

enum EditOperation: Codable {
    case trim(startMs: UInt64, endMs: UInt64)
    case cut(startMs: UInt64, endMs: UInt64)
    case speed(startMs: UInt64, endMs: UInt64, factor: Float)
}
```

### Export Configuration

```swift
struct MP4ExportConfig: Codable {
    var codec: VideoCodec
    var quality: VideoQuality
    var includeWebcamOverlay: Bool
    var includeAnnotations: Bool
}

struct GifExportConfig: Codable {
    var maxWidth: UInt32        // default 640
    var maxFps: UInt32          // default 10
    var startMs: UInt64
    var endMs: UInt64
}
```

### Settings

```swift
struct AppPreferences: Codable {
    var recording: RecordingConfiguration
    var webcamBubble: WebcamBubbleConfig
    var shortcuts: [ShortcutAction: KeyCombination]
    var darkModePreference: DarkModePreference
    var noiseCancellation: Bool
    var autoTranscribe: Bool
    var autoGenerateTitle: Bool
    var autoGenerateSummary: Bool
    var launchAtStartup: Bool
    var libraryPath: String
}

enum DarkModePreference: String, Codable { case system, light, dark }

enum ShortcutAction: String, Codable, CaseIterable {
    case startStopRecording, pauseResumeRecording, toggleMute, toggleDrawing, cancelRecording
}

struct KeyCombination: Codable {
    var keyCode: UInt16
    var modifiers: UInt
    var displayString: String
}
```

---

## Rust Models (cloom-core/src/lib.rs)

Rust models are minimal — only types that cross the FFI boundary for audio, AI, and GIF export.
All FFI-exposed types derive `uniffi::Record` or `uniffi::Enum`.

### Audio Processing Types

```rust
#[derive(uniffi::Record)]
struct TimeRange {
    start_ms: u64,
    end_ms: u64,
}

#[derive(uniffi::Record)]
struct FillerWord {
    word: String,
    start_ms: u64,
    end_ms: u64,
    count: u32,
}

// Input from Swift for filler word detection
#[derive(uniffi::Record)]
struct TranscriptWord {
    word: String,
    start_ms: u64,
    end_ms: u64,
    confidence: f32,
}
```

### AI Types

```rust
#[derive(uniffi::Record)]
struct Transcript {
    full_text: String,
    words: Vec<TranscriptWord>,
    language: String,
}

#[derive(uniffi::Record)]
struct Chapter {
    id: String,
    title: String,
    start_ms: u64,
}

#[derive(uniffi::Enum)]
enum LlmProvider {
    OpenAI,
    Claude, // Reserved for future provider expansion; v1 uses OpenAI only
}
```

### GIF Export Types

```rust
#[derive(uniffi::Record)]
struct GifConfig {
    max_width: u32,
    max_fps: u32,
    start_ms: u64,
    end_ms: u64,
}
```

### Error Type

```rust
#[derive(uniffi::Error, thiserror::Error)]
enum CloomError {
    #[error("IO error: {0}")]
    IoError(String),
    #[error("API error: {0}")]
    ApiError(String),
    #[error("Audio error: {0}")]
    AudioError(String),
    #[error("Invalid input: {0}")]
    InvalidInput(String),
    #[error("Export error: {0}")]
    ExportError(String),
}
```
