import Foundation
import SwiftData

@Model
final class TagRecord {
    @Attribute(.unique) var id: String
    var name: String
    var color: String  // Hex color string

    @Relationship var videos: [VideoRecord]

    init(
        id: String = UUID().uuidString,
        name: String,
        color: String = "#007AFF"
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.videos = []
    }
}
