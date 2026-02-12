import SwiftUI
import SwiftData

struct StitchPanelView: View {
    let editorState: EditorState
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \VideoRecord.createdAt, order: .reverse) private var allVideos: [VideoRecord]

    private var availableVideos: [VideoRecord] {
        allVideos.filter { $0.id != editorState.videoRecord.id }
    }

    private var stitchedVideos: [VideoRecord] {
        let ids = editorState.edl.stitchVideoIDs
        return ids.compactMap { id in availableVideos.first(where: { $0.id == id }) }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Stitch Clips")
                .font(.headline)
                .padding()

            Divider()

            // Current stitch order
            if !stitchedVideos.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stitched Clips (in order)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    List {
                        ForEach(stitchedVideos, id: \.id) { video in
                            HStack {
                                Image(systemName: "film")
                                Text(video.title)
                                Spacer()
                                Button(role: .destructive) {
                                    editorState.removeStitchVideo(id: video.id)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .onMove { from, to in
                            var ids = editorState.edl.stitchVideoIDs
                            ids.move(fromOffsets: from, toOffset: to)
                            editorState.edl.stitchVideoIDs = ids
                            editorState.save()
                        }
                    }
                    .frame(maxHeight: 150)
                }
            }

            Divider()

            // Available clips to add
            VStack(alignment: .leading, spacing: 4) {
                Text("Available Clips")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 8)

                if availableVideos.isEmpty {
                    Text("No other recordings available")
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    List(availableVideos, id: \.id) { video in
                        HStack {
                            Image(systemName: "film")
                            VStack(alignment: .leading) {
                                Text(video.title)
                                Text(formatDuration(ms: video.durationMs))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if editorState.edl.stitchVideoIDs.contains(video.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Button("Add") {
                                    editorState.addStitchVideo(id: video.id)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 400, height: 500)
    }

    private func formatDuration(ms: Int64) -> String {
        let totalSeconds = Int(ms / 1000)
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return "\(m):\(String(format: "%02d", s))"
    }
}
