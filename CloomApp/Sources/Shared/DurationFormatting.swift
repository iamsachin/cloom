import Foundation

extension Int64 {
    /// Formats milliseconds as "M:SS" duration string.
    var formattedDuration: String {
        let totalSeconds = self / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
