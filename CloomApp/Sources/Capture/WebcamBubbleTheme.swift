import AppKit
import CoreGraphics

enum BubbleTheme: String, CaseIterable, Codable, Sendable {
    case none
    case solidRed
    case solidBlue
    case solidGreen
    case solidPurple
    case gradientSunset
    case gradientOcean
    case gradientForest
    case gradientCosmic

    var displayName: String {
        switch self {
        case .none: "None"
        case .solidRed: "Red"
        case .solidBlue: "Blue"
        case .solidGreen: "Green"
        case .solidPurple: "Purple"
        case .gradientSunset: "Sunset"
        case .gradientOcean: "Ocean"
        case .gradientForest: "Forest"
        case .gradientCosmic: "Cosmic"
        }
    }

    func cgColor() -> CGColor? {
        switch self {
        case .solidRed: CGColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1)
        case .solidBlue: CGColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1)
        case .solidGreen: CGColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1)
        case .solidPurple: CGColor(red: 0.6, green: 0.2, blue: 0.9, alpha: 1)
        default: nil
        }
    }

    func gradientCGColors() -> (CGColor, CGColor)? {
        switch self {
        case .gradientSunset:
            (CGColor(red: 1.0, green: 0.4, blue: 0.2, alpha: 1),
             CGColor(red: 0.9, green: 0.2, blue: 0.5, alpha: 1))
        case .gradientOcean:
            (CGColor(red: 0.1, green: 0.6, blue: 0.9, alpha: 1),
             CGColor(red: 0.2, green: 0.3, blue: 0.8, alpha: 1))
        case .gradientForest:
            (CGColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1),
             CGColor(red: 0.1, green: 0.5, blue: 0.5, alpha: 1))
        case .gradientCosmic:
            (CGColor(red: 0.5, green: 0.1, blue: 0.9, alpha: 1),
             CGColor(red: 0.9, green: 0.2, blue: 0.6, alpha: 1))
        default: nil
        }
    }

    func gradientNSColors() -> (NSColor, NSColor)? {
        guard let (c1, c2) = gradientCGColors() else { return nil }
        return (NSColor(cgColor: c1)!, NSColor(cgColor: c2)!)
    }

    func swatchColor() -> NSColor {
        if let color = cgColor() {
            return NSColor(cgColor: color)!
        }
        if let (c1, _) = gradientCGColors() {
            return NSColor(cgColor: c1)!
        }
        return .clear
    }
}
