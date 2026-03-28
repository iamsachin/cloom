import CoreGraphics
import CoreImage
import AppKit

// MARK: - Tool Types

enum AnnotationTool: Sendable, Equatable, CaseIterable {
    case pen
    case highlighter
    case arrow
    case line
    case rectangle
    case ellipse
    case eraser
    case text
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

    init(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    var cgColor: CGColor {
        CGColor(srgbRed: r, green: g, blue: b, alpha: a)
    }

    var ciColor: CIColor {
        CIColor(red: r, green: g, blue: b, alpha: a)
    }

    static let red = StrokeColor(r: 1.0, g: 0.23, b: 0.19, a: 1.0)
    static let blue = StrokeColor(r: 0.0, g: 0.48, b: 1.0, a: 1.0)
    static let green = StrokeColor(r: 0.3, g: 0.85, b: 0.39, a: 1.0)
    static let orange = StrokeColor(r: 1.0, g: 0.58, b: 0.0, a: 1.0)
    static let white = StrokeColor(r: 1.0, g: 1.0, b: 1.0, a: 1.0)
    static let black = StrokeColor(r: 0.0, g: 0.0, b: 0.0, a: 1.0)

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

    var hexString: String {
        let ri = Int(r * 255)
        let gi = Int(g * 255)
        let bi = Int(b * 255)
        return String(format: "#%02X%02X%02X", ri, gi, bi)
    }

    init?(hex: String) {
        var hexStr = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexStr.hasPrefix("#") { hexStr.removeFirst() }
        guard hexStr.count == 6, let value = UInt64(hexStr, radix: 16) else { return nil }
        self.r = CGFloat((value >> 16) & 0xFF) / 255.0
        self.g = CGFloat((value >> 8) & 0xFF) / 255.0
        self.b = CGFloat(value & 0xFF) / 255.0
        self.a = 1.0
    }

    init(nsColor: NSColor) {
        let c = nsColor.usingColorSpace(.sRGB) ?? nsColor
        self.r = c.redComponent
        self.g = c.greenComponent
        self.b = c.blueComponent
        self.a = c.alphaComponent
    }

    var nsColor: NSColor {
        NSColor(srgbRed: r, green: g, blue: b, alpha: a)
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
    /// For text tool: the committed text content
    var text: String?
    /// For text tool: font size in points
    var fontSize: CGFloat?
    let timestamp: TimeInterval

    init(
        id: UUID = UUID(),
        tool: AnnotationTool,
        color: StrokeColor,
        lineWidth: CGFloat,
        points: [StrokePoint] = [],
        origin: CGPoint? = nil,
        endpoint: CGPoint? = nil,
        text: String? = nil,
        fontSize: CGFloat? = nil,
        timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) {
        self.id = id
        self.tool = tool
        self.color = color
        self.lineWidth = lineWidth
        self.points = points
        self.origin = origin
        self.endpoint = endpoint
        self.text = text
        self.fontSize = fontSize
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

// MARK: - Zoom State

struct ZoomState: Sendable {
    var isActive: Bool
    var isAnimatingOut: Bool
    /// Normalized center X (0-1) relative to capture area
    var normalizedCenterX: CGFloat
    /// Normalized center Y (0-1) relative to capture area
    var normalizedCenterY: CGFloat
    var zoomLevel: CGFloat
    var startTime: TimeInterval
    var animationDuration: TimeInterval

    init(
        isActive: Bool = false,
        isAnimatingOut: Bool = false,
        normalizedCenterX: CGFloat = 0.5,
        normalizedCenterY: CGFloat = 0.5,
        zoomLevel: CGFloat = 2.5,
        startTime: TimeInterval = 0,
        animationDuration: TimeInterval = 0.3
    ) {
        self.isActive = isActive
        self.isAnimatingOut = isAnimatingOut
        self.normalizedCenterX = normalizedCenterX
        self.normalizedCenterY = normalizedCenterY
        self.zoomLevel = zoomLevel
        self.startTime = startTime
        self.animationDuration = animationDuration
    }
}

// MARK: - Keystroke Event

struct KeystrokeEvent: Sendable, Identifiable {
    let id: UUID
    /// Human-readable label (e.g. "⌘S", "Shift+Enter", "A")
    let label: String
    let startTime: TimeInterval
    /// How long the label stays visible before fading
    let displayDuration: TimeInterval
    /// Fade-out duration after displayDuration
    let fadeDuration: TimeInterval

    init(
        id: UUID = UUID(),
        label: String,
        startTime: TimeInterval = ProcessInfo.processInfo.systemUptime,
        displayDuration: TimeInterval = 1.5,
        fadeDuration: TimeInterval = 0.5
    ) {
        self.id = id
        self.label = label
        self.startTime = startTime
        self.displayDuration = displayDuration
        self.fadeDuration = fadeDuration
    }

    var totalDuration: TimeInterval { displayDuration + fadeDuration }

    /// Returns opacity (1.0 during display, fading during fade, 0.0 after)
    func opacity(at currentTime: TimeInterval) -> CGFloat {
        let elapsed = currentTime - startTime
        if elapsed < 0 { return 1.0 }
        if elapsed < displayDuration { return 1.0 }
        let fadeElapsed = elapsed - displayDuration
        if fadeElapsed >= fadeDuration { return 0.0 }
        return CGFloat(1.0 - fadeElapsed / fadeDuration)
    }
}

/// Position corner for the keystroke overlay
enum KeystrokePosition: String, CaseIterable, Sendable {
    case bottomLeft = "Bottom Left"
    case bottomRight = "Bottom Right"
    case topLeft = "Top Left"
    case topRight = "Top Right"
}

/// What keys to show
enum KeystrokeDisplayMode: String, CaseIterable, Sendable {
    case allKeys = "All Keys"
    case modifierCombosOnly = "Modifier Combos Only"
}

// MARK: - Keystroke State

struct KeystrokeState: Sendable {
    var isEnabled: Bool = false
    var events: [KeystrokeEvent] = []
    var position: KeystrokePosition = .bottomLeft
    var displayMode: KeystrokeDisplayMode = .allKeys
}

// MARK: - Snapshot (immutable copy for renderer)

struct AnnotationSnapshot: Sendable {
    let strokes: [AnnotationStroke]
    let ripples: [ClickRipple]
    let spotlight: SpotlightState
    let zoom: ZoomState
    let keystroke: KeystrokeState
    let hasActiveStroke: Bool
}
