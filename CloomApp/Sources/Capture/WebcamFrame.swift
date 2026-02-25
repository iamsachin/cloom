import CoreGraphics

enum WebcamFrame: String, CaseIterable, Codable, Sendable {
    case none
    case geometric    // 💎✨💠
    case tropical     // 🌴🌺☀️🏖️
    case celebration  // 🎉🎊✨🥳

    var displayName: String {
        switch self {
        case .none: "None"
        case .geometric: "Geometric"
        case .tropical: "Tropical"
        case .celebration: "Celebration"
        }
    }

    var representativeEmoji: String {
        switch self {
        case .none: ""
        case .geometric: "💎"
        case .tropical: "🌴"
        case .celebration: "🎉"
        }
    }

    var stickers: [FrameSticker] {
        switch self {
        case .none: []
        case .geometric: Self.geometricStickers
        case .tropical: Self.tropicalStickers
        case .celebration: Self.celebrationStickers
        }
    }

    // All stickers on left & bottom-left arc (angles 150–310)
    // Sizes: 16pt minimum, 42pt maximum

    private static let geometricStickers: [FrameSticker] = [
        FrameSticker(emoji: "💎", angleDegrees: 165, offsetFromEdge: 8, baseFontSize: 42, rotationDegrees: -15),
        FrameSticker(emoji: "✨", angleDegrees: 195, offsetFromEdge: 12, baseFontSize: 16, rotationDegrees: 0),
        FrameSticker(emoji: "💠", angleDegrees: 225, offsetFromEdge: 6, baseFontSize: 28, rotationDegrees: 10),
        FrameSticker(emoji: "🔷", angleDegrees: 255, offsetFromEdge: 10, baseFontSize: 18, rotationDegrees: -5),
        FrameSticker(emoji: "✨", angleDegrees: 285, offsetFromEdge: 14, baseFontSize: 16, rotationDegrees: 0),
        FrameSticker(emoji: "💎", angleDegrees: 310, offsetFromEdge: 6, baseFontSize: 22, rotationDegrees: 15),
    ]

    private static let tropicalStickers: [FrameSticker] = [
        FrameSticker(emoji: "🌴", angleDegrees: 160, offsetFromEdge: 8, baseFontSize: 42, rotationDegrees: -10),
        FrameSticker(emoji: "🌺", angleDegrees: 190, offsetFromEdge: 10, baseFontSize: 18, rotationDegrees: 5),
        FrameSticker(emoji: "☀️", angleDegrees: 220, offsetFromEdge: 6, baseFontSize: 28, rotationDegrees: 0),
        FrameSticker(emoji: "🏖️", angleDegrees: 250, offsetFromEdge: 10, baseFontSize: 16, rotationDegrees: -5),
        FrameSticker(emoji: "🌊", angleDegrees: 280, offsetFromEdge: 8, baseFontSize: 22, rotationDegrees: 10),
        FrameSticker(emoji: "🐚", angleDegrees: 305, offsetFromEdge: 12, baseFontSize: 16, rotationDegrees: -8),
    ]

    private static let celebrationStickers: [FrameSticker] = [
        FrameSticker(emoji: "🎉", angleDegrees: 155, offsetFromEdge: 8, baseFontSize: 42, rotationDegrees: -15),
        FrameSticker(emoji: "🎊", angleDegrees: 185, offsetFromEdge: 10, baseFontSize: 18, rotationDegrees: 10),
        FrameSticker(emoji: "✨", angleDegrees: 215, offsetFromEdge: 14, baseFontSize: 16, rotationDegrees: 0),
        FrameSticker(emoji: "🥳", angleDegrees: 245, offsetFromEdge: 8, baseFontSize: 30, rotationDegrees: 5),
        FrameSticker(emoji: "🎈", angleDegrees: 275, offsetFromEdge: 12, baseFontSize: 20, rotationDegrees: -10),
        FrameSticker(emoji: "🎊", angleDegrees: 305, offsetFromEdge: 6, baseFontSize: 16, rotationDegrees: 12),
    ]
}

struct FrameSticker: Sendable {
    let emoji: String
    /// Position around bubble perimeter (0=right, 90=top, 180=left, 270=bottom)
    let angleDegrees: CGFloat
    /// Distance beyond the bubble edge in points
    let offsetFromEdge: CGFloat
    /// Font size at 180pt bubble diameter baseline
    let baseFontSize: CGFloat
    /// Visual rotation of the emoji
    let rotationDegrees: CGFloat
}
