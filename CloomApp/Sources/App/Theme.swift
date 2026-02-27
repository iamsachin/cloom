import SwiftUI
import AppKit

// MARK: - Semantic Color Extensions

extension Color {
    /// Hover overlay on video cards — light: black@8%, dark: white@8%
    static var cardHoverOverlay: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.isDarkMode
                ? NSColor.white.withAlphaComponent(0.08)
                : NSColor.black.withAlphaComponent(0.08)
        })
    }

    /// Card shadow — light: black@10%, dark: black@30%
    static var cardShadow: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.isDarkMode
                ? NSColor.black.withAlphaComponent(0.30)
                : NSColor.black.withAlphaComponent(0.10)
        })
    }

    /// Card shadow on hover — light: black@20%, dark: black@40%
    static var cardShadowHover: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.isDarkMode
                ? NSColor.black.withAlphaComponent(0.40)
                : NSColor.black.withAlphaComponent(0.20)
        })
    }

    /// Dimming overlay (countdown, etc.) — light: black@40%, dark: black@50%
    static var dimmingOverlay: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.isDarkMode
                ? NSColor.black.withAlphaComponent(0.50)
                : NSColor.black.withAlphaComponent(0.40)
        })
    }

    /// Region border — light: white@50%, dark: white@70%
    static var regionBorder: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.isDarkMode
                ? NSColor.white.withAlphaComponent(0.70)
                : NSColor.white.withAlphaComponent(0.50)
        })
    }

    /// Trim excluded regions — light: black@40%, dark: black@50%
    static var trimExcluded: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.isDarkMode
                ? NSColor.black.withAlphaComponent(0.50)
                : NSColor.black.withAlphaComponent(0.40)
        })
    }

    /// Caption background pill — light: black@65%, dark: black@75%
    static var captionBackground: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.isDarkMode
                ? NSColor.black.withAlphaComponent(0.75)
                : NSColor.black.withAlphaComponent(0.65)
        })
    }

    /// Selection badge (unselected) — light: black@40%, dark: white@20%
    static var selectionBadge: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.isDarkMode
                ? NSColor.white.withAlphaComponent(0.20)
                : NSColor.black.withAlphaComponent(0.40)
        })
    }

    /// Duration badge background — dark pill on thumbnail
    static var durationBadge: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.isDarkMode
                ? NSColor.black.withAlphaComponent(0.70)
                : NSColor.black.withAlphaComponent(0.60)
        })
    }

    /// List row hover — light: black@4%, dark: white@6%
    static var listRowHover: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.isDarkMode
                ? NSColor.white.withAlphaComponent(0.06)
                : NSColor.black.withAlphaComponent(0.04)
        })
    }

    /// Subtle card background — light: white@95%, dark: white@5%
    static var cardBackgroundSubtle: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.isDarkMode
                ? NSColor.white.withAlphaComponent(0.05)
                : NSColor.white.withAlphaComponent(0.95)
        })
    }

    /// Region dim overlay (outside captured area) — light: black@25%, dark: black@35%
    static var regionDim: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.isDarkMode
                ? NSColor.black.withAlphaComponent(0.35)
                : NSColor.black.withAlphaComponent(0.25)
        })
    }
}

// MARK: - Appearance Helper

extension NSAppearance {
    var isDarkMode: Bool {
        bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}
