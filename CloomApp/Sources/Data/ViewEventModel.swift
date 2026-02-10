import Foundation
import SwiftData

@Model
final class ViewEvent {
    var viewedAt: Date
    var durationWatchedMs: Int64

    @Relationship(inverse: \VideoRecord.viewEvents) var video: VideoRecord?

    init(
        viewedAt: Date = .now,
        durationWatchedMs: Int64 = 0
    ) {
        self.viewedAt = viewedAt
        self.durationWatchedMs = durationWatchedMs
    }
}
