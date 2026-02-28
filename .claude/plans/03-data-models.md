# Data Models

> Note: All model snippets in this document reflect the actual implementation (conceptual pseudocode for reference, not compile-ready source).

## Swift Models — SwiftData (@Model)

These are the persistent data models stored via SwiftData. Cloud/sync features are out of scope.

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
    var webcamFilePath: String?  // Legacy: separate webcam file (no longer used with real-time compositing)

    // Relationships
    @Relationship var folder: FolderRecord?
    @Relationship(inverse: \TagRecord.videos) var tags: [TagRecord]
    @Relationship(deleteRule: .cascade) var transcript: TranscriptRecord?
    @Relationship(deleteRule: .cascade) var chapters: [ChapterRecord]
    @Relationship(deleteRule: .cascade) var comments: [VideoComment]
    @Relationship(deleteRule: .cascade) var viewEvents: [ViewEvent]
    @Relationship(deleteRule: .cascade) var bookmarks: [BookmarkRecord]
    @Relationship(deleteRule: .cascade) var editDecisionList: EditDecisionList?

    // AI-generated
    var hasTranscript: Bool
    var summary: String?

    // Cloud upload
    var driveFileId: String?
    var shareUrl: String?
    var uploadStatus: String?  // nil | "uploading" | "uploaded" | "failed"
    var uploadedAt: Date?
}
```

### UploadStatus

```swift
enum UploadStatus: String, Sendable, CaseIterable {
    case uploading, uploaded, failed

    init?(_ rawValue: String?) {
        guard let rawValue else { return nil }
        self.init(rawValue: rawValue)
    }
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
    @Relationship(deleteRule: .cascade, inverse: \FolderRecord.parent) var children: [FolderRecord]
    @Relationship(inverse: \VideoRecord.folder) var videos: [VideoRecord]

    var videoCount: Int { videos.count }
}
```

### Tag

```swift
@Model
final class TagRecord {
    @Attribute(.unique) var id: String
    var name: String
    var color: String  // Hex color from 8-preset palette

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

    @Relationship(deleteRule: .cascade) var words: [TranscriptWordRecord]
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

### EditDecisionList

```swift
@Model
final class EditDecisionList {
    @Attribute(.unique) var id: String
    var videoID: String
    var trimStartMs: Int64
    var trimEndMs: Int64
    var cutsJSON: String        // JSON-encoded [CutRange] array
    var stitchVideoIDsJSON: String  // JSON-encoded [String] array
    var speedMultiplier: Double
    var thumbnailTimeMs: Int64

    var hasEdits: Bool { /* computed */ }
}

struct CutRange: Codable {
    var startMs: Int64
    var endMs: Int64
}
```

### Bookmark

```swift
@Model
final class BookmarkRecord {
    @Attribute(.unique) var id: String
    var text: String
    var timestampMs: Int64

    @Relationship(inverse: \VideoRecord.bookmarks) var video: VideoRecord?
}
```

### Comment & Analytics (models exist, UI not yet built)

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

## Swift Models — Value Types

These are non-persistent value types used by UI, recording, and editing.

### Capture Mode

```swift
enum CaptureMode {
    case fullScreen(displayID: CGDirectDisplayID)
    case window(windowID: CGWindowID)
    case region(displayID: CGDirectDisplayID, rect: CGRect)
    case webcamOnly
}
```

### Recording State

```swift
enum RecordingState: Equatable {
    case idle
    case selectingContent
    case countdown(Int)
    case recording(startedAt: Date)
    case paused(startedAt: Date, pausedAt: Date)
    case stopping

    var isRecording: Bool { /* ... */ }
    var isPaused: Bool { /* ... */ }
    var isActiveOrPaused: Bool { /* ... */ }
    var isIdle: Bool { /* ... */ }
    var isSelectingContent: Bool { /* ... */ }
    var isBusy: Bool { /* ... */ }
}
```

### Video Quality & Recording Settings

```swift
enum VideoQuality: String, CaseIterable, Identifiable {
    case low      // 4 Mbps
    case medium   // 10 Mbps
    case high     // 20 Mbps

    var bitrate: Int { /* ... */ }
    var label: String { /* ... */ }
}

struct RecordingSettings {
    let fps: Int                  // 24, 30, or 60 (via @AppStorage)
    let quality: VideoQuality     // low, medium, high
    let micDeviceID: String?
    let cameraDeviceID: String?
    let micSensitivity: Int       // 0–100 (gain applied via MicGainProcessor)

    static func fromDefaults() -> RecordingSettings { /* reads from UserDefaults */ }
}
```

### Webcam Configuration

```swift
enum WebcamShape: String, Codable, CaseIterable {
    case circle
    case roundedRect
    case pill

    var aspectRatio: CGFloat { /* ... */ }
    func cornerRadius(for size: CGFloat) -> CGFloat { /* ... */ }
}

enum WebcamFrame: String, Codable, CaseIterable {
    case none
    case geometric    // 💎✨💠🔷
    case tropical     // 🌴🌺☀️🏖️🌊🐚
    case celebration  // 🎉🎊✨🥳🎈

    var stickers: [FrameSticker] { /* ... */ }
}

struct FrameSticker {
    let emoji: String
    let angleDegrees: CGFloat    // position around bubble perimeter
    let offsetFromEdge: CGFloat  // distance beyond bubble edge
    let baseFontSize: CGFloat    // size at 180pt diameter baseline
    let rotationDegrees: CGFloat // visual rotation
}

struct WebcamAdjustments {
    var brightness: Float    // -1.0 to 1.0
    var contrast: Float      // 0.25 to 4.0
    var saturation: Float    // 0.0 to 2.0
    var highlights: Float    // -1.0 to 1.0
    var shadows: Float       // -1.0 to 1.0
    var temperature: Float   // 2000 to 10000 (Kelvin)
    var tint: Float          // -150 to 150
}
```

### Annotation Models

```swift
enum AnnotationTool: String, CaseIterable {
    case pen, highlighter, arrow, line, rectangle, ellipse, eraser
}

struct StrokePoint {
    var x: CGFloat
    var y: CGFloat
    var pressure: CGFloat
}

struct StrokeColor {
    var r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat

    // Palette: red, blue, green, orange, white, black
    static let palette: [StrokeColor] = [...]
}

struct AnnotationStroke: Identifiable {
    let id: UUID
    var tool: AnnotationTool
    var color: StrokeColor
    var lineWidth: CGFloat
    var points: [StrokePoint]
    var origin: CGPoint?     // For shapes (rect, ellipse, arrow, line)
    var endpoint: CGPoint?
    var timestamp: TimeInterval
}

struct ClickRipple {
    var normalizedX: CGFloat
    var normalizedY: CGFloat
    var color: StrokeColor
    var duration: TimeInterval
    var maxRadius: CGFloat
}

struct SpotlightState {
    var isEnabled: Bool
    var normalizedX: CGFloat
    var normalizedY: CGFloat
    var radius: CGFloat
    var dimOpacity: CGFloat
}

struct AnnotationSnapshot {
    var strokes: [AnnotationStroke]
    var ripples: [ClickRipple]
    var spotlight: SpotlightState
}
```

### Global Hotkeys

```swift
enum HotkeyAction: String, CaseIterable {
    case toggleRecording
    case togglePause
}

struct HotkeyBinding: Codable {
    var keyCode: UInt16
    var modifiers: UInt
    var displayString: String
}
```

---

## Rust Models (cloom-core/src/)

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
    OpenAi,     // Enabled in v1 (gpt-4o-mini)
    Claude,     // Reserved for future — returns error if used
}

#[derive(uniffi::Enum)]
enum TranscriptionProvider {
    OpenAi,     // Enabled in v1 (whisper-1)
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
