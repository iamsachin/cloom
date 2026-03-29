import CoreGraphics

/// Aspect ratio presets for social media export.
enum SocialAspectRatio: String, CaseIterable, Identifiable, Sendable {
    case landscape_16_9 = "16:9"
    case vertical_9_16 = "9:16"
    case square_1_1 = "1:1"
    case portrait_4_5 = "4:5"

    var id: String { rawValue }

    var widthRatio: Double {
        switch self {
        case .landscape_16_9: 16.0
        case .vertical_9_16: 9.0
        case .square_1_1: 1.0
        case .portrait_4_5: 4.0
        }
    }

    var heightRatio: Double {
        switch self {
        case .landscape_16_9: 9.0
        case .vertical_9_16: 16.0
        case .square_1_1: 1.0
        case .portrait_4_5: 5.0
        }
    }

    var aspectRatio: Double { widthRatio / heightRatio }

    var label: String {
        switch self {
        case .landscape_16_9: "16:9"
        case .vertical_9_16: "9:16"
        case .square_1_1: "1:1"
        case .portrait_4_5: "4:5"
        }
    }

    var platformLabel: String {
        switch self {
        case .landscape_16_9: "YouTube"
        case .vertical_9_16: "Shorts / Reels"
        case .square_1_1: "Instagram"
        case .portrait_4_5: "LinkedIn"
        }
    }

    /// Output pixel dimensions with the short edge at the given resolution.
    func outputSize(shortEdge: Int = 1080) -> CGSize {
        switch self {
        case .landscape_16_9:
            return CGSize(width: shortEdge * 16 / 9, height: shortEdge)
        case .vertical_9_16:
            return CGSize(width: shortEdge, height: shortEdge * 16 / 9)
        case .square_1_1:
            return CGSize(width: shortEdge, height: shortEdge)
        case .portrait_4_5:
            return CGSize(width: shortEdge, height: shortEdge * 5 / 4)
        }
    }
}

/// Background fill style for letterboxing when content doesn't fill the reframed output.
enum BackgroundFillStyle: Sendable, Equatable {
    case blur(radius: Double)
    case solidColor(red: Double, green: Double, blue: Double, alpha: Double)
    case gradient(
        topRed: Double, topGreen: Double, topBlue: Double,
        bottomRed: Double, bottomGreen: Double, bottomBlue: Double
    )

    static let defaultBlur = BackgroundFillStyle.blur(radius: 30)
    static let defaultSolid = BackgroundFillStyle.solidColor(red: 0, green: 0, blue: 0, alpha: 1)
    static let defaultGradient = BackgroundFillStyle.gradient(
        topRed: 0.15, topGreen: 0.15, topBlue: 0.2,
        bottomRed: 0.05, bottomGreen: 0.05, bottomBlue: 0.1
    )
}

/// Configuration for a social media reframe export.
struct ReframeConfig: Sendable {
    let aspectRatio: SocialAspectRatio
    let backgroundFill: BackgroundFillStyle
    /// Normalized focus point (0–1 range, origin = top-left in screen coordinates).
    let focusX: Double
    let focusY: Double
    let outputSize: CGSize

    init(
        aspectRatio: SocialAspectRatio,
        backgroundFill: BackgroundFillStyle = .defaultBlur,
        focusX: Double = 0.5,
        focusY: Double = 0.5
    ) {
        self.aspectRatio = aspectRatio
        self.backgroundFill = backgroundFill
        self.focusX = focusX
        self.focusY = focusY
        self.outputSize = aspectRatio.outputSize()
    }
}

// MARK: - Crop Math

/// Computes the largest crop rect with the target aspect ratio that fits within
/// `sourceSize`, centered on the given normalized focus point.
/// Focus coordinates use CIImage convention: (0,0) = bottom-left.
func reframeCropRect(
    for aspectRatio: SocialAspectRatio,
    in sourceSize: CGSize,
    focusX: Double = 0.5,
    focusY: Double = 0.5
) -> CGRect {
    let sw = sourceSize.width
    let sh = sourceSize.height
    let targetRatio = aspectRatio.aspectRatio

    let cropW: Double
    let cropH: Double
    if sw / sh > targetRatio {
        cropH = sh
        cropW = sh * targetRatio
    } else {
        cropW = sw
        cropH = sw / targetRatio
    }

    let idealX = focusX * sw - cropW / 2.0
    let idealY = focusY * sh - cropH / 2.0
    let clampedX = max(0, min(idealX, sw - cropW))
    let clampedY = max(0, min(idealY, sh - cropH))

    return CGRect(x: clampedX, y: clampedY, width: cropW, height: cropH)
}
