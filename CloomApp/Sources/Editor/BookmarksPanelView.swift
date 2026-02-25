import SwiftUI

struct BookmarksPanelView: View {
    let editorState: EditorState

    @State private var newBookmarkText = ""
    @State private var editingID: String?
    @State private var editText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            addBookmarkRow
            Divider()
            bookmarkList
        }
        .frame(width: 260)
        .background(Color(.controlBackgroundColor))
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        HStack {
            Text("Bookmarks")
                .font(.headline)
            Spacer()
            Text("\(editorState.bookmarks.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Add Bookmark

    @ViewBuilder
    private var addBookmarkRow: some View {
        HStack(spacing: 6) {
            TextField("Note (optional)", text: $newBookmarkText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .onSubmit { addBookmark() }

            Button {
                addBookmark()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
            .help("Add bookmark at current time")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Bookmark List

    @ViewBuilder
    private var bookmarkList: some View {
        let currentTimeMs = editorState.currentTimeMs

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(editorState.bookmarks) { bookmark in
                    bookmarkRow(bookmark: bookmark, currentTimeMs: currentTimeMs)
                    Divider().padding(.leading, 12)
                }
            }
        }
    }

    @ViewBuilder
    private func bookmarkRow(bookmark: BookmarkSnapshot, currentTimeMs: Int64) -> some View {
        let isNear = abs(currentTimeMs - bookmark.timestampMs) < 2000

        HStack(spacing: 8) {
            // Green diamond icon
            Image(systemName: "diamond.fill")
                .font(.system(size: 8))
                .foregroundStyle(.green)

            // Timestamp
            Text(formatTime(ms: bookmark.timestampMs))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)

            // Note text or edit field
            if editingID == bookmark.id {
                TextField("Note", text: $editText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .onSubmit { finishEditing(id: bookmark.id) }
            } else {
                Text(bookmark.text.isEmpty ? "—" : bookmark.text)
                    .font(.system(size: 12))
                    .foregroundStyle(bookmark.text.isEmpty ? .tertiary : .primary)
                    .lineLimit(1)
            }

            Spacer()

            // Edit button
            if editingID == bookmark.id {
                Button {
                    finishEditing(id: bookmark.id)
                } label: {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    editingID = bookmark.id
                    editText = bookmark.text
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Edit note")
            }

            // Delete button
            Button {
                editorState.removeBookmark(id: bookmark.id)
            } label: {
                Image(systemName: "trash")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Delete bookmark")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isNear ? Color.green.opacity(0.08) : .clear)
        .contentShape(Rectangle())
        .onTapGesture {
            if editingID != bookmark.id {
                editorState.seekTo(ms: bookmark.timestampMs)
            }
        }
    }

    // MARK: - Actions

    private func addBookmark() {
        editorState.addBookmark(ms: editorState.currentTimeMs, text: newBookmarkText)
        newBookmarkText = ""
    }

    private func finishEditing(id: String) {
        editorState.updateBookmarkText(id: id, text: editText)
        editingID = nil
        editText = ""
    }

    private func formatTime(ms: Int64) -> String {
        let totalSeconds = Int(ms / 1000)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let millis = Int((ms % 1000) / 10)
        return String(format: "%d:%02d.%02d", minutes, seconds, millis)
    }
}
