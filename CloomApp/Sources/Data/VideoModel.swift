import Foundation
import SwiftData

@Model
final class VideoRecord {
    @Attribute(.unique) var id: String
    var title: String
    var filePath: String
    var thumbnailPath: String
    var durationMs: Int64
    var createdAt: Date
    var updatedAt: Date
    var width: Int32
    var height: Int32
    var fileSizeBytes: Int64
    var recordingType: String  // "screenAndWebcam" | "screenOnly" | "webcamOnly"
    var webcamFilePath: String?

    // Relationships
    @Relationship var folder: FolderRecord?
    @Relationship(inverse: \TagRecord.videos) var tags: [TagRecord]
    @Relationship(deleteRule: .cascade) var transcript: TranscriptRecord?
    @Relationship(deleteRule: .cascade) var chapters: [ChapterRecord]
    @Relationship(deleteRule: .cascade) var comments: [VideoComment]
    @Relationship(deleteRule: .cascade) var viewEvents: [ViewEvent]
    @Relationship(deleteRule: .cascade) var bookmarks: [BookmarkRecord]
    @Relationship(deleteRule: .cascade) var editDecisionList: EditDecisionList?

    // AI-generated
    var hasTranscript: Bool
    var summary: String?

    // Cloud upload
    var driveFileId: String?
    var shareUrl: String?
    var uploadStatus: String?  // nil | "uploading" | "uploaded" | "failed"
    var uploadedAt: Date?

    init(
        id: String = UUID().uuidString,
        title: String,
        filePath: String,
        thumbnailPath: String = "",
        durationMs: Int64 = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        width: Int32 = 0,
        height: Int32 = 0,
        fileSizeBytes: Int64 = 0,
        recordingType: String = "screenOnly",
        hasTranscript: Bool = false,
        webcamFilePath: String? = nil
    ) {
        self.id = id
        self.title = title
        self.filePath = filePath
        self.thumbnailPath = thumbnailPath
        self.durationMs = durationMs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.width = width
        self.height = height
        self.fileSizeBytes = fileSizeBytes
        self.recordingType = recordingType
        self.tags = []
        self.chapters = []
        self.comments = []
        self.viewEvents = []
        self.bookmarks = []
        self.hasTranscript = hasTranscript
        self.webcamFilePath = webcamFilePath
    }
}
