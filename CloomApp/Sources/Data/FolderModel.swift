import Foundation
import SwiftData

@Model
final class FolderRecord {
    @Attribute(.unique) var id: String
    var name: String
    var createdAt: Date

    @Relationship var parent: FolderRecord?
    @Relationship(deleteRule: .cascade, inverse: \FolderRecord.parent) var children: [FolderRecord]
    @Relationship(inverse: \VideoRecord.folder) var videos: [VideoRecord]

    var videoCount: Int { videos.count }

    init(
        id: String = UUID().uuidString,
        name: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.children = []
        self.videos = []
    }
}
