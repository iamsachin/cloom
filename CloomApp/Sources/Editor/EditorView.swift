import SwiftUI
import SwiftData

struct EditorView: View {
    let videoID: String

    @Query private var videos: [VideoRecord]
    @Environment(\.modelContext) private var modelContext
    @State private var editorState: EditorState?
    @State private var showExportSheet = false
    @State private var showStitchPanel = false
    @State private var showThumbnailPicker = false
    @State private var cutMarkInMs: Int64?

    init(videoID: String) {
        self.videoID = videoID
        let id = videoID
        _videos = Query(filter: #Predicate<VideoRecord> { $0.id == id })
    }

    private var video: VideoRecord? {
        videos.first
    }

    var body: some View {
        Group {
            if let editorState {
                editorContent(state: editorState)
            } else if video != nil {
                ProgressView("Loading editor...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "Video Not Found",
                    systemImage: "film.fill",
                    description: Text("The requested video could not be loaded.")
                )
            }
        }
        .frame(minWidth: 800, minHeight: 550)
        .onAppear { setupEditor() }
        .onDisappear {
            editorState?.player.pause()
        }
    }

    @ViewBuilder
    private func editorContent(state: EditorState) -> some View {
        VStack(spacing: 0) {
            // Video preview
            VideoPreviewView(player: state.player) {
                state.togglePlayPause()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Timeline
            EditorTimelineView(editorState: state)
                .frame(height: 120)
                .padding(.horizontal, 8)

            Divider()

            // Toolbar
            editorToolbar(state: state)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .navigationTitle(state.videoRecord.title)
        .sheet(isPresented: $showExportSheet) {
            EditorExportView(editorState: state)
        }
        .sheet(isPresented: $showStitchPanel) {
            StitchPanelView(editorState: state)
        }
        .sheet(isPresented: $showThumbnailPicker) {
            ThumbnailPickerView(editorState: state)
        }
    }

    @ViewBuilder
    private func editorToolbar(state: EditorState) -> some View {
        HStack(spacing: 12) {
            // Play/Pause
            Button {
                state.togglePlayPause()
            } label: {
                Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
            }
            .keyboardShortcut(.space, modifiers: [])

            // Time display
            Text(formatTime(ms: state.currentTimeMs))
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)

            Text("/")
                .foregroundStyle(.tertiary)

            Text(formatTime(ms: state.durationMs))
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)

            Divider()
                .frame(height: 20)

            // Cut controls
            if let markIn = cutMarkInMs {
                // Mark-in is set — show indicator and Mark Out button
                HStack(spacing: 4) {
                    Image(systemName: "scissors")
                        .foregroundStyle(.orange)
                    Text("In: \(formatTime(ms: markIn))")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.orange)
                }

                Button {
                    let endMs = state.currentTimeMs
                    if markIn < endMs {
                        state.addCut(startMs: markIn, endMs: endMs)
                    }
                    cutMarkInMs = nil
                } label: {
                    Label("Mark Out", systemImage: "scissors")
                }
                .help("Cut from mark-in to current playhead")

                Button {
                    cutMarkInMs = nil
                } label: {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Cancel cut")
            } else {
                Button {
                    cutMarkInMs = state.currentTimeMs
                } label: {
                    Label("Mark In", systemImage: "scissors")
                }
                .help("Set cut start point at playhead")
            }

            Spacer()

            // Speed
            SpeedControlView(editorState: state)

            // Stitch
            Button("Stitch") {
                showStitchPanel = true
            }

            // Thumbnail
            Button {
                showThumbnailPicker = true
            } label: {
                Image(systemName: "photo")
            }
            .help("Set custom thumbnail")

            // Export
            Button("Export") {
                showExportSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func setupEditor() {
        guard let video, editorState == nil else { return }
        let state = EditorState(videoRecord: video, modelContext: modelContext)
        self.editorState = state

        Task {
            await state.loadWaveform()
            await state.loadThumbnailStrip()
        }
    }

    private func formatTime(ms: Int64) -> String {
        let totalSeconds = Int(ms / 1000)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let millis = Int((ms % 1000) / 10)
        return String(format: "%d:%02d.%02d", minutes, seconds, millis)
    }
}
