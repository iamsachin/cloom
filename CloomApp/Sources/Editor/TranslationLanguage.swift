import Foundation

/// Supported languages for subtitle and transcript translation at export time.
enum TranslationLanguage: String, CaseIterable, Identifiable, Sendable {
    case original = "Original"
    case english = "English"
    case spanish = "Spanish"
    case french = "French"
    case german = "German"
    case portuguese = "Portuguese"
    case japanese = "Japanese"
    case korean = "Korean"
    case chinese = "Chinese"
    case hindi = "Hindi"
    case arabic = "Arabic"
    case italian = "Italian"
    case dutch = "Dutch"
    case russian = "Russian"
    case turkish = "Turkish"

    var id: String { rawValue }
}
