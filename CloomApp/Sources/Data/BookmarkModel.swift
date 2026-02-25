import Foundation
import SwiftData

@Model
final class BookmarkRecord {
    @Attribute(.unique) var id: String
    var text: String
    var timestampMs: Int64

    @Relationship(inverse: \VideoRecord.bookmarks) var video: VideoRecord?

    init(
        id: String = UUID().uuidString,
        text: String = "",
        timestampMs: Int64
    ) {
        self.id = id
        self.text = text
        self.timestampMs = timestampMs
    }
}
