import SwiftUI

struct ChapterNavigationView: View {
    let editorState: EditorState

    var body: some View {
        let chapters = editorState.chapters
        let currentTimeMs = editorState.currentTimeMs

        VStack(alignment: .leading, spacing: 0) {
            Text("Chapters")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(chapters.enumerated()), id: \.offset) { index, chapter in
                        let isCurrent = isCurrentChapter(
                            chapter: chapter,
                            index: index,
                            chapters: chapters,
                            currentTimeMs: currentTimeMs
                        )

                        Button {
                            editorState.seekTo(ms: chapter.startMs)
                        } label: {
                            HStack {
                                Text(chapter.title)
                                    .font(.system(size: 13))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Text(formatTimestamp(ms: chapter.startMs))
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                            .background(isCurrent ? Color.accentColor.opacity(0.15) : .clear)
                        }
                        .buttonStyle(.plain)

                        if index < chapters.count - 1 {
                            Divider()
                                .padding(.leading, 12)
                        }
                    }
                }
            }
        }
        .frame(width: 260, height: min(CGFloat(chapters.count) * 50 + 50, 350))
    }

    private func isCurrentChapter(chapter: ChapterSnapshot, index: Int, chapters: [ChapterSnapshot], currentTimeMs: Int64) -> Bool {
        let start = chapter.startMs
        let end = index + 1 < chapters.count ? chapters[index + 1].startMs : Int64.max
        return currentTimeMs >= start && currentTimeMs < end
    }

    private func formatTimestamp(ms: Int64) -> String {
        let totalSeconds = Int(ms / 1000)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
