import CoreGraphics

enum WebcamShape: String, CaseIterable, Codable, Sendable {
    case circle
    case roundedRect
    case pill

    var displayName: String {
        switch self {
        case .circle: "Circle"
        case .roundedRect: "Rounded"
        case .pill: "Pill"
        }
    }

    /// Width-to-height aspect ratio for each shape.
    var aspectRatio: CGFloat {
        switch self {
        case .circle: 1.0
        case .roundedRect: 1.33
        case .pill: 1.8
        }
    }

    /// Corner radius as a fraction of the shorter dimension (height).
    func cornerRadius(forHeight height: CGFloat) -> CGFloat {
        switch self {
        case .circle: height / 2.0
        case .roundedRect: height * 0.2
        case .pill: height / 2.0
        }
    }

    var next: WebcamShape {
        let all = WebcamShape.allCases
        guard let idx = all.firstIndex(of: self) else { return .circle }
        return all[(idx + 1) % all.count]
    }
}
