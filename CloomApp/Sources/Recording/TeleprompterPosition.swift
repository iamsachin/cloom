import Foundation

/// Where the teleprompter overlay appears on screen.
enum TeleprompterPosition: String, CaseIterable, Identifiable {
    case top = "Top"
    case bottom = "Bottom"

    var id: String { rawValue }
}
