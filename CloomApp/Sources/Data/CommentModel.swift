import Foundation
import SwiftData

@Model
final class VideoComment {
    @Attribute(.unique) var id: String
    var timestampMs: Int64?
    var text: String
    var createdAt: Date

    @Relationship(inverse: \VideoRecord.comments) var video: VideoRecord?

    init(
        id: String = UUID().uuidString,
        timestampMs: Int64? = nil,
        text: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.timestampMs = timestampMs
        self.text = text
        self.createdAt = createdAt
    }
}
