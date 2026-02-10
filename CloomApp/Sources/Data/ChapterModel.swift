import Foundation
import SwiftData

@Model
final class ChapterRecord {
    @Attribute(.unique) var id: String
    var title: String
    var startMs: Int64

    @Relationship(inverse: \VideoRecord.chapters) var video: VideoRecord?

    init(
        id: String = UUID().uuidString,
        title: String,
        startMs: Int64
    ) {
        self.id = id
        self.title = title
        self.startMs = startMs
    }
}
