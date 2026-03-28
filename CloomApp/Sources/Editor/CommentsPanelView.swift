import SwiftUI

struct CommentsPanelView: View {
    let editorState: EditorState

    @State private var newCommentText = ""
    @State private var useCurrentTime = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            addCommentRow
            Divider()
            commentList
        }
        .frame(width: 260)
        .background(Color(.controlBackgroundColor))
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        HStack {
            Text("Comments")
                .font(.headline)
            Spacer()
            Text("\(editorState.comments.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Add Comment

    @ViewBuilder
    private var addCommentRow: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                TextField("Add a comment...", text: $newCommentText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .onSubmit { addComment() }

                Button {
                    addComment()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .disabled(newCommentText.trimmingCharacters(in: .whitespaces).isEmpty)
                .help("Add comment")
            }

            HStack(spacing: 4) {
                Toggle(isOn: $useCurrentTime) {
                    Text("At current time")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .toggleStyle(.checkbox)
                .controlSize(.mini)
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Comment List

    @ViewBuilder
    private var commentList: some View {
        let currentTimeMs = editorState.currentTimeMs

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(editorState.comments) { comment in
                    commentRow(comment: comment, currentTimeMs: currentTimeMs)
                    Divider().padding(.leading, 12)
                }
            }
        }
    }

    @ViewBuilder
    private func commentRow(comment: CommentSnapshot, currentTimeMs: Int64) -> some View {
        let isNear = comment.timestampMs.map { abs(currentTimeMs - $0) < 2000 } ?? false

        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 9))
                    .foregroundStyle(.blue)

                if let ms = comment.timestampMs {
                    Text(formatTime(ms: ms))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.blue)
                } else {
                    Text("General")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Text(relativeDate(comment.createdAt))
                    .font(.system(size: 9))
                    .foregroundStyle(.quaternary)
            }

            Text(comment.text)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .lineLimit(3)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isNear ? Color.blue.opacity(0.08) : .clear)
        .contentShape(Rectangle())
        .onTapGesture {
            if let ms = comment.timestampMs {
                editorState.seekTo(ms: ms)
            }
        }
        .contextMenu {
            Button("Delete", role: .destructive) {
                editorState.removeComment(id: comment.id)
            }
        }
    }

    // MARK: - Actions

    private func addComment() {
        let text = newCommentText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let timestampMs = useCurrentTime ? editorState.currentTimeMs : nil
        editorState.addComment(text: text, timestampMs: timestampMs)
        newCommentText = ""
    }

    private func formatTime(ms: Int64) -> String {
        let totalSeconds = Int(ms / 1000)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date.now)
    }
}
