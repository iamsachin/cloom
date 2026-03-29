import Foundation

// MARK: - Feature Category

enum AppFeatureCategory: String, CaseIterable, Identifiable {
    case recording = "Recording"
    case editing = "Editing"
    case export = "Export"
    case ai = "AI"
    case library = "Library"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .recording: "record.circle"
        case .editing: "scissors"
        case .export: "square.and.arrow.up"
        case .ai: "sparkles"
        case .library: "rectangle.stack"
        }
    }
}

// MARK: - Feature Model

struct AppFeature: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let shortcut: String?
    let systemImage: String
    let category: AppFeatureCategory
}

// MARK: - Feature Directory

extension AppFeature {
    static let all: [AppFeature] = [
        // MARK: Recording
        AppFeature(
            id: "fullscreen-recording",
            name: "Full Screen Recording",
            description: "Record your entire display with system and microphone audio.",
            shortcut: "\u{21E7}\u{2318}R",
            systemImage: "rectangle.inset.filled",
            category: .recording
        ),
        AppFeature(
            id: "window-recording",
            name: "Window Recording",
            description: "Capture a specific application window using the system picker.",
            shortcut: nil,
            systemImage: "macwindow",
            category: .recording
        ),
        AppFeature(
            id: "region-recording",
            name: "Region Recording",
            description: "Select and record a custom rectangular area of your screen.",
            shortcut: nil,
            systemImage: "crop",
            category: .recording
        ),
        AppFeature(
            id: "webcam-overlay",
            name: "Webcam Overlay",
            description: "Show a floating webcam bubble with shape, theme, and beauty options.",
            shortcut: nil,
            systemImage: "web.camera",
            category: .recording
        ),
        AppFeature(
            id: "pause-resume",
            name: "Pause / Resume",
            description: "Pause and resume recording without creating separate clips.",
            shortcut: "\u{21E7}\u{2318}P",
            systemImage: "pause.circle",
            category: .recording
        ),
        AppFeature(
            id: "punch-in-rerecord",
            name: "Punch-In Re-Record",
            description: "Rewind to any point during recording and re-record from there.",
            shortcut: nil,
            systemImage: "arrow.counterclockwise",
            category: .recording
        ),
        AppFeature(
            id: "countdown-timer",
            name: "Countdown Timer",
            description: "Configurable countdown before recording starts.",
            shortcut: nil,
            systemImage: "timer",
            category: .recording
        ),
        AppFeature(
            id: "system-audio",
            name: "System Audio Capture",
            description: "Record system audio output alongside microphone input.",
            shortcut: nil,
            systemImage: "speaker.wave.2",
            category: .recording
        ),
        AppFeature(
            id: "annotations",
            name: "Drawing & Annotations",
            description: "Draw arrows, shapes, and text directly on your recording.",
            shortcut: nil,
            systemImage: "pencil.tip.crop.circle",
            category: .recording
        ),
        AppFeature(
            id: "keystroke-viz",
            name: "Keystroke Visualization",
            description: "Display pressed keys as a floating overlay during recording.",
            shortcut: nil,
            systemImage: "keyboard",
            category: .recording
        ),
        AppFeature(
            id: "teleprompter",
            name: "Teleprompter",
            description: "Floating script overlay with auto-scroll for reading while recording.",
            shortcut: "\u{21E7}\u{2318}T",
            systemImage: "scroll",
            category: .recording
        ),
        AppFeature(
            id: "click-emphasis",
            name: "Click Emphasis",
            description: "Visual highlight effect on mouse clicks during recording.",
            shortcut: nil,
            systemImage: "cursorarrow.click.2",
            category: .recording
        ),

        // MARK: Editing
        AppFeature(
            id: "trim",
            name: "Trim",
            description: "Trim the start and end of your recording on the timeline.",
            shortcut: nil,
            systemImage: "timeline.selection",
            category: .editing
        ),
        AppFeature(
            id: "cut-segments",
            name: "Cut Segments",
            description: "Mark in/out points to remove unwanted sections.",
            shortcut: "I / O",
            systemImage: "scissors",
            category: .editing
        ),
        AppFeature(
            id: "stitch",
            name: "Stitch Clips",
            description: "Combine multiple recordings into a single video.",
            shortcut: nil,
            systemImage: "film.stack",
            category: .editing
        ),
        AppFeature(
            id: "speed-adjust",
            name: "Speed Adjustment",
            description: "Change playback speed for selected segments of your recording.",
            shortcut: nil,
            systemImage: "gauge.with.dots.needle.67percent",
            category: .editing
        ),
        AppFeature(
            id: "undo-redo",
            name: "Undo / Redo",
            description: "Full undo/redo stack for all editing operations.",
            shortcut: "\u{2318}Z / \u{21E7}\u{2318}Z",
            systemImage: "arrow.uturn.backward",
            category: .editing
        ),
        AppFeature(
            id: "shuttle-playback",
            name: "Shuttle Playback",
            description: "J/K/L shuttle controls for fast forward and reverse playback.",
            shortcut: "J / K / L",
            systemImage: "forward",
            category: .editing
        ),
        AppFeature(
            id: "bookmarks",
            name: "Bookmarks",
            description: "Mark important moments in the timeline for quick navigation.",
            shortcut: "B",
            systemImage: "bookmark",
            category: .editing
        ),
        AppFeature(
            id: "blur-regions",
            name: "Blur Regions",
            description: "Draw redaction regions with Gaussian, pixelate, or black box styles.",
            shortcut: nil,
            systemImage: "eye.slash",
            category: .editing
        ),
        AppFeature(
            id: "social-reframe",
            name: "Social Reframe",
            description: "Crop to 9:16, 1:1, or 4:5 with draggable focus point and backgrounds.",
            shortcut: nil,
            systemImage: "aspectratio",
            category: .editing
        ),
        AppFeature(
            id: "auto-cut-silence",
            name: "Auto-Cut Silence",
            description: "Automatically detect and remove silent sections with preview.",
            shortcut: nil,
            systemImage: "waveform.path",
            category: .editing
        ),
        AppFeature(
            id: "auto-cut-fillers",
            name: "Auto-Cut Fillers",
            description: "Detect and remove filler words (um, uh, etc.) with configurable list.",
            shortcut: nil,
            systemImage: "text.word.spacing",
            category: .editing
        ),

        // MARK: Export
        AppFeature(
            id: "mp4-export",
            name: "MP4 Export",
            description: "Export recordings as MP4 with configurable quality presets.",
            shortcut: nil,
            systemImage: "film",
            category: .export
        ),
        AppFeature(
            id: "subtitle-embed",
            name: "Embedded Subtitles",
            description: "Burn subtitles into the exported video or embed as a text track.",
            shortcut: nil,
            systemImage: "captions.bubble",
            category: .export
        ),
        AppFeature(
            id: "batch-export",
            name: "Batch Export",
            description: "Export multiple recordings at once with shared settings.",
            shortcut: nil,
            systemImage: "square.stack.3d.up",
            category: .export
        ),
        AppFeature(
            id: "social-presets",
            name: "Social Media Presets",
            description: "One-click export presets for YouTube, Instagram, TikTok, and more.",
            shortcut: nil,
            systemImage: "shared.with.you",
            category: .export
        ),
        AppFeature(
            id: "share-sheet",
            name: "System Share Sheet",
            description: "Share recordings directly via macOS share extensions.",
            shortcut: nil,
            systemImage: "square.and.arrow.up",
            category: .export
        ),
        AppFeature(
            id: "google-drive",
            name: "Google Drive Upload",
            description: "Upload recordings directly to Google Drive with resume support.",
            shortcut: nil,
            systemImage: "icloud.and.arrow.up",
            category: .export
        ),
        AppFeature(
            id: "transcript-export",
            name: "Transcript Export",
            description: "Export transcripts as Markdown or PDF with timestamps.",
            shortcut: nil,
            systemImage: "doc.text",
            category: .export
        ),
        AppFeature(
            id: "multi-lang-translation",
            name: "Multi-Language Translation",
            description: "Translate subtitles and transcripts to 14 languages.",
            shortcut: nil,
            systemImage: "globe",
            category: .export
        ),

        // MARK: AI
        AppFeature(
            id: "transcription",
            name: "Transcription",
            description: "Automatic speech-to-text transcription powered by AI.",
            shortcut: nil,
            systemImage: "waveform.and.mic",
            category: .ai
        ),
        AppFeature(
            id: "ai-title-summary",
            name: "Title & Summary",
            description: "AI-generated titles, summaries, and chapter markers.",
            shortcut: nil,
            systemImage: "sparkles.rectangle.stack",
            category: .ai
        ),
        AppFeature(
            id: "filler-detection",
            name: "Filler Word Detection",
            description: "Detect filler words with configurable word list and confidence threshold.",
            shortcut: nil,
            systemImage: "character.bubble",
            category: .ai
        ),
        AppFeature(
            id: "silence-detection",
            name: "Silence Detection",
            description: "Find silent segments with adjustable duration and threshold settings.",
            shortcut: nil,
            systemImage: "speaker.slash",
            category: .ai
        ),
        AppFeature(
            id: "chapters",
            name: "Auto Chapters",
            description: "AI-generated chapter markers based on content analysis.",
            shortcut: nil,
            systemImage: "list.bullet.rectangle",
            category: .ai
        ),

        // MARK: Library
        AppFeature(
            id: "open-library",
            name: "Video Library",
            description: "Browse, search, and organize all your recordings.",
            shortcut: "\u{2318}L",
            systemImage: "rectangle.stack",
            category: .library
        ),
        AppFeature(
            id: "folders",
            name: "Folders",
            description: "Organize recordings into nested folders with drag and drop.",
            shortcut: nil,
            systemImage: "folder",
            category: .library
        ),
        AppFeature(
            id: "tags",
            name: "Tags",
            description: "Tag recordings and filter the library by tag from the sidebar.",
            shortcut: nil,
            systemImage: "tag",
            category: .library
        ),
        AppFeature(
            id: "search",
            name: "Search",
            description: "Full-text search across titles, descriptions, and transcripts.",
            shortcut: nil,
            systemImage: "magnifyingglass",
            category: .library
        ),
        AppFeature(
            id: "hover-preview",
            name: "Hover Preview",
            description: "Preview video playback by hovering over library thumbnails.",
            shortcut: nil,
            systemImage: "play.rectangle",
            category: .library
        ),
        AppFeature(
            id: "comments",
            name: "Timestamped Comments",
            description: "Add time-stamped notes and comments to recordings.",
            shortcut: nil,
            systemImage: "text.bubble",
            category: .library
        ),
    ]

    /// Features grouped by category, in the order defined by `AppFeatureCategory.allCases`.
    static var groupedByCategory: [(category: AppFeatureCategory, features: [AppFeature])] {
        AppFeatureCategory.allCases.compactMap { category in
            let features = all.filter { $0.category == category }
            return features.isEmpty ? nil : (category, features)
        }
    }
}
