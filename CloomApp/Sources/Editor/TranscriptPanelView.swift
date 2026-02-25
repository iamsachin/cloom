import SwiftUI

struct TranscriptPanelView: View {
    let editorState: EditorState

    var body: some View {
        let currentTimeMs = editorState.currentTimeMs

        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Transcript")
                    .font(.headline)
                Spacer()
                Text("\(editorState.transcriptWords.count) words")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Scrollable word list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(editorState.transcriptSentences) { sentence in
                            sentenceRow(sentence: sentence, currentTimeMs: currentTimeMs)
                        }
                    }
                    .padding(12)
                }
                .onChange(of: currentTimeMs) { _, newTime in
                    // Auto-scroll to current word
                    if let activeWord = editorState.transcriptWords.first(where: {
                        $0.startMs <= newTime && newTime < $0.endMs
                    }) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(activeWord.id, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(width: 280)
        .background(Color(.controlBackgroundColor))
    }

    @ViewBuilder
    private func sentenceRow(sentence: TranscriptSentence, currentTimeMs: Int64) -> some View {
        let startTime = sentence.words.first?.startMs ?? 0
        VStack(alignment: .leading, spacing: 2) {
            // Timestamp
            Text(formatTimestamp(ms: startTime))
                .font(.caption2)
                .foregroundStyle(.tertiary)

            // Words
            FlowLayout(spacing: 2) {
                ForEach(sentence.words) { word in
                    let isActive = word.startMs <= currentTimeMs && currentTimeMs < word.endMs
                    Text(word.word)
                        .font(.system(size: 13))
                        .padding(.horizontal, 2)
                        .padding(.vertical, 1)
                        .background(isActive ? Color.accentColor.opacity(0.3) : .clear, in: RoundedRectangle(cornerRadius: 3))
                        .foregroundStyle(word.isFillerWord ? .secondary : .primary)
                        .opacity(word.isFillerWord ? 0.6 : 1.0)
                        .id(word.id)
                        .onTapGesture {
                            editorState.seekTo(ms: word.startMs)
                        }
                        .help("Click to seek to \(formatTimestamp(ms: word.startMs))")
                }
            }
        }
    }

    private func formatTimestamp(ms: Int64) -> String {
        let totalSeconds = Int(ms / 1000)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    static func groupIntoSentences(_ words: [TranscriptWordSnapshot]) -> [TranscriptSentence] {
        guard !words.isEmpty else { return [] }
        var sentences: [TranscriptSentence] = []
        var current: [TranscriptWordSnapshot] = []

        for word in words {
            current.append(word)
            let trimmed = word.word.trimmingCharacters(in: .whitespaces)
            let endsWithPunctuation = trimmed.hasSuffix(".") || trimmed.hasSuffix("?") || trimmed.hasSuffix("!")
            if endsWithPunctuation || current.count >= 18 {
                sentences.append(TranscriptSentence(words: current))
                current = []
            }
        }
        if !current.isEmpty {
            sentences.append(TranscriptSentence(words: current))
        }
        return sentences
    }
}

struct TranscriptSentence: Identifiable {
    let id = UUID()
    let words: [TranscriptWordSnapshot]
}

// Simple horizontal flow layout for wrapping words
struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> ArrangementResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return ArrangementResult(
            positions: positions,
            size: CGSize(width: maxX, height: y + rowHeight)
        )
    }

    private struct ArrangementResult {
        let positions: [CGPoint]
        let size: CGSize
    }
}
