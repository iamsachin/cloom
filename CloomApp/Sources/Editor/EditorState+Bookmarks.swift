import SwiftData

struct BookmarkSnapshot: Identifiable {
    let id: String
    var text: String
    let timestampMs: Int64
}

extension EditorState {
    func loadBookmarks() {
        bookmarks = videoRecord.bookmarks
            .sorted { $0.timestampMs < $1.timestampMs }
            .map { BookmarkSnapshot(id: $0.id, text: $0.text, timestampMs: $0.timestampMs) }
    }

    func addBookmark(ms: Int64, text: String = "") {
        let record = BookmarkRecord(text: text, timestampMs: ms)
        modelContext.insert(record)
        record.video = videoRecord
        save()
        loadBookmarks()
    }

    func removeBookmark(id: String) {
        guard let record = videoRecord.bookmarks.first(where: { $0.id == id }) else { return }
        modelContext.delete(record)
        save()
        loadBookmarks()
    }

    func updateBookmarkText(id: String, text: String) {
        guard let record = videoRecord.bookmarks.first(where: { $0.id == id }) else { return }
        record.text = text
        save()
        loadBookmarks()
    }
}
