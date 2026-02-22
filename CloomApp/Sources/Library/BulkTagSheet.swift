import SwiftUI
import SwiftData

struct BulkTagSheet: View {
    let tags: [TagRecord]
    let videoIDs: Set<String>
    let videos: [VideoRecord]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Text("Apply Tags")
                .font(.headline)

            List {
                ForEach(tags, id: \.id) { tag in
                    Button {
                        applyTag(tag)
                        dismiss()
                    } label: {
                        HStack {
                            Circle()
                                .fill(Color(hex: tag.color))
                                .frame(width: 10, height: 10)
                            Text(tag.name)
                        }
                    }
                }
            }
            .frame(width: 250, height: 250)

            Button("Cancel") { dismiss() }
        }
        .padding()
    }

    private func applyTag(_ tag: TagRecord) {
        for video in videos where videoIDs.contains(video.id) {
            if !video.tags.contains(where: { $0.id == tag.id }) {
                video.tags.append(tag)
            }
        }
        try? modelContext.save()
    }
}
