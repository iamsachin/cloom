import Foundation
import SwiftData

@Model
final class EditDecisionList {
    @Attribute(.unique) var id: String
    var videoID: String
    var trimStartMs: Int64
    var trimEndMs: Int64
    var cutsJSON: String          // JSON array of CutRange
    var stitchVideoIDsJSON: String // JSON array of String
    var speedMultiplier: Double
    var thumbnailTimeMs: Int64
    var updatedAt: Date

    @Relationship(inverse: \VideoRecord.editDecisionList)
    var video: VideoRecord?

    init(
        id: String = UUID().uuidString,
        videoID: String,
        trimStartMs: Int64 = 0,
        trimEndMs: Int64 = 0,
        speedMultiplier: Double = 1.0,
        thumbnailTimeMs: Int64 = 500
    ) {
        self.id = id
        self.videoID = videoID
        self.trimStartMs = trimStartMs
        self.trimEndMs = trimEndMs
        self.cutsJSON = "[]"
        self.stitchVideoIDsJSON = "[]"
        self.speedMultiplier = speedMultiplier
        self.thumbnailTimeMs = thumbnailTimeMs
        self.updatedAt = .now
    }
}

// MARK: - CutRange

struct CutRange: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var startMs: Int64
    var endMs: Int64

    init(id: String = UUID().uuidString, startMs: Int64, endMs: Int64) {
        self.id = id
        self.startMs = startMs
        self.endMs = endMs
    }
}

// MARK: - JSON Helpers

extension EditDecisionList {
    var cuts: [CutRange] {
        get {
            guard let data = cutsJSON.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([CutRange].self, from: data)) ?? []
        }
        set {
            let data = (try? JSONEncoder().encode(newValue)) ?? Data()
            cutsJSON = String(data: data, encoding: .utf8) ?? "[]"
            updatedAt = .now
        }
    }

    var stitchVideoIDs: [String] {
        get {
            guard let data = stitchVideoIDsJSON.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            let data = (try? JSONEncoder().encode(newValue)) ?? Data()
            stitchVideoIDsJSON = String(data: data, encoding: .utf8) ?? "[]"
            updatedAt = .now
        }
    }

    var hasEdits: Bool {
        trimStartMs > 0
        || trimEndMs > 0
        || !cuts.isEmpty
        || !stitchVideoIDs.isEmpty
        || speedMultiplier != 1.0
        || thumbnailTimeMs != 500
    }
}
