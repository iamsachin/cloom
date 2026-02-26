import CoreGraphics
import CoreImage

// MARK: - Tool Types

enum AnnotationTool: Sendable, Equatable, CaseIterable {
    case pen
    case highlighter
    case arrow
    case line
    case rectangle
    case ellipse
    case eraser
}

// MARK: - Stroke Data

struct StrokePoint: Sendable {
    var x: CGFloat
    var y: CGFloat
    var pressure: CGFloat

    init(x: CGFloat, y: CGFloat, pressure: CGFloat = 1.0) {
        self.x = x
        self.y = y
        self.pressure = pressure
    }

    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

struct StrokeColor: Sendable, Equatable {
    var r: CGFloat
    var g: CGFloat
    var b: CGFloat
    var a: CGFloat

    var cgColor: CGColor {
        CGColor(srgbRed: r, green: g, blue: b, alpha: a)
    }

    var ciColor: CIColor {
        CIColor(red: r, green: g, blue: b, alpha: a)
    }

    static let red = StrokeColor(r: 1, g: 0.23, b: 0.19, a: 1)
    static let blue = StrokeColor(r: 0.0, g: 0.48, b: 1.0, a: 1)
    static let green = StrokeColor(r: 0.3, g: 0.85, b: 0.39, a: 1)
    static let orange = StrokeColor(r: 1.0, g: 0.58, b: 0.0, a: 1)
    static let white = StrokeColor(r: 1, g: 1, b: 1, a: 1)
    static let black = StrokeColor(r: 0, g: 0, b: 0, a: 1)

    static let palette: [StrokeColor] = [.red, .blue, .green, .orange, .white, .black]

    var displayName: String {
        switch self {
        case .red: return "Red"
        case .blue: return "Blue"
        case .green: return "Green"
        case .orange: return "Orange"
        case .white: return "White"
        case .black: return "Black"
        default: return "Custom"
        }
    }
}

struct AnnotationStroke: Sendable, Identifiable {
    let id: UUID
    let tool: AnnotationTool
    let color: StrokeColor
    let lineWidth: CGFloat
    var points: [StrokePoint]
    /// For shape tools: the starting point (mouseDown location)
    var origin: CGPoint?
    /// For shape tools: the ending point (mouseUp location)
    var endpoint: CGPoint?
    let timestamp: TimeInterval

    init(
        id: UUID = UUID(),
        tool: AnnotationTool,
        color: StrokeColor,
        lineWidth: CGFloat,
        points: [StrokePoint] = [],
        origin: CGPoint? = nil,
        endpoint: CGPoint? = nil,
        timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) {
        self.id = id
        self.tool = tool
        self.color = color
        self.lineWidth = lineWidth
        self.points = points
        self.origin = origin
        self.endpoint = endpoint
        self.timestamp = timestamp
    }
}

// MARK: - Click Ripple

struct ClickRipple: Sendable, Identifiable {
    let id: UUID
    /// Normalized X position (0-1) relative to capture area
    let normalizedX: CGFloat
    /// Normalized Y position (0-1) relative to capture area
    let normalizedY: CGFloat
    let color: StrokeColor
    let startTime: TimeInterval
    let duration: TimeInterval
    let maxRadius: CGFloat

    init(
        id: UUID = UUID(),
        normalizedX: CGFloat,
        normalizedY: CGFloat,
        color: StrokeColor = .init(r: 0.0, g: 0.48, b: 1.0, a: 0.5),
        startTime: TimeInterval = ProcessInfo.processInfo.systemUptime,
        duration: TimeInterval = 0.6,
        maxRadius: CGFloat = 40
    ) {
        self.id = id
        self.normalizedX = normalizedX
        self.normalizedY = normalizedY
        self.color = color
        self.startTime = startTime
        self.duration = duration
        self.maxRadius = maxRadius
    }
}

// MARK: - Cursor Spotlight

struct SpotlightState: Sendable {
    var isEnabled: Bool
    /// Normalized X position (0-1) relative to capture area
    var normalizedX: CGFloat
    /// Normalized Y position (0-1) relative to capture area
    var normalizedY: CGFloat
    var radius: CGFloat
    var dimOpacity: CGFloat

    init(
        isEnabled: Bool = false,
        normalizedX: CGFloat = 0.5,
        normalizedY: CGFloat = 0.5,
        radius: CGFloat = 80,
        dimOpacity: CGFloat = 0.5
    ) {
        self.isEnabled = isEnabled
        self.normalizedX = normalizedX
        self.normalizedY = normalizedY
        self.radius = radius
        self.dimOpacity = dimOpacity
    }
}

// MARK: - Snapshot (immutable copy for renderer)

struct AnnotationSnapshot: Sendable {
    let strokes: [AnnotationStroke]
    let ripples: [ClickRipple]
    let spotlight: SpotlightState
    let hasActiveStroke: Bool
}
