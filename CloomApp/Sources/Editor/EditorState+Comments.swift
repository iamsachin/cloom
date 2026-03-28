import Foundation
import SwiftData

struct CommentSnapshot: Identifiable {
    let id: String
    let timestampMs: Int64?
    let text: String
    let createdAt: Date
}

extension CommentSnapshot {
    static func sorted(_ comments: [CommentSnapshot]) -> [CommentSnapshot] {
        comments.sorted { a, b in
            let aMs = a.timestampMs ?? Int64.max
            let bMs = b.timestampMs ?? Int64.max
            return aMs < bMs
        }
    }
}

extension EditorState {
    func loadComments() {
        comments = CommentSnapshot.sorted(
            videoRecord.comments.map {
                CommentSnapshot(id: $0.id, timestampMs: $0.timestampMs, text: $0.text, createdAt: $0.createdAt)
            }
        )
    }

    func addComment(text: String, timestampMs: Int64?) {
        let record = VideoComment(timestampMs: timestampMs, text: text)
        modelContext.insert(record)
        record.video = videoRecord
        save()
        loadComments()
    }

    func removeComment(id: String) {
        guard let record = videoRecord.comments.first(where: { $0.id == id }) else { return }
        modelContext.delete(record)
        save()
        loadComments()
    }
}
