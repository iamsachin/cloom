import Foundation

struct RecordingSegment: Sendable {
    let url: URL
    let index: Int
    var duration: TimeInterval
    /// If set, only use this portion of the segment (for punch-in truncation).
    /// Nil means use the full segment duration.
    var effectiveDuration: TimeInterval?
}
