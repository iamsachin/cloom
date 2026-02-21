import SwiftUI
import SwiftData
import AppKit

struct EditorView: View {
    let videoID: String

    @Query private var videos: [VideoRecord]
    @Environment(\.modelContext) private var modelContext
    @State private var editorState: EditorState?
    @State private var showExportSheet = false
    @State private var showStitchPanel = false
    @State private var showThumbnailPicker = false
    @State private var cutMarkInMs: Int64?
    @State private var showChapterPopover = false
    @State private var showInfoPanel = false

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
        HStack(spacing: 0) {
            // Main editor area
            VStack(spacing: 0) {
                // Video preview with caption overlay
                ZStack(alignment: .bottom) {
                    VideoPreviewView(
                        player: state.player,
                        onTap: { state.togglePlayPause() },
                        onPiPControllerReady: { controller in
                            state.pipController = controller
                        }
                    )

                    CaptionOverlayView(
                        words: state.transcriptWords,
                        currentTimeMs: state.currentTimeMs,
                        isEnabled: state.captionsEnabled
                    )
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

            // Transcript sidebar
            if state.showTranscript && state.videoRecord.hasTranscript {
                Divider()
                TranscriptPanelView(editorState: state)
            }

            // Info sidebar
            if showInfoPanel {
                Divider()
                videoInfoPanel(state: state)
                    .frame(width: 260)
            }
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
            .help(state.isPlaying ? "Pause" : "Play")

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

            // Chapters
            if !state.chapters.isEmpty {
                Button {
                    showChapterPopover.toggle()
                } label: {
                    Image(systemName: "list.bullet")
                }
                .help("Chapters")
                .popover(isPresented: $showChapterPopover) {
                    ChapterNavigationView(editorState: state)
                }
            }

            // Speed
            SpeedControlView(editorState: state)

            // Stitch
            Button("Stitch") {
                showStitchPanel = true
            }
            .help("Stitch multiple clips together")

            // Thumbnail
            Button {
                showThumbnailPicker = true
            } label: {
                Image(systemName: "photo")
            }
            .help("Set custom thumbnail")

            // Captions toggle
            if state.videoRecord.hasTranscript {
                Button {
                    state.toggleCaptions()
                } label: {
                    Image(systemName: state.captionsEnabled ? "captions.bubble.fill" : "captions.bubble")
                }
                .help("Toggle captions")

                Button {
                    state.toggleTranscript()
                } label: {
                    Image(systemName: state.showTranscript ? "doc.text.fill" : "doc.text")
                }
                .help("Toggle transcript")
            }

            // PiP
            if state.pipController != nil {
                Button {
                    state.togglePiP()
                } label: {
                    Image(systemName: "pip")
                }
                .help("Picture in Picture")
            }

            // Fullscreen
            Button {
                NSApp.mainWindow?.toggleFullScreen(nil)
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .help("Toggle fullscreen")

            // Info panel toggle
            Button {
                showInfoPanel.toggle()
            } label: {
                Image(systemName: showInfoPanel ? "info.circle.fill" : "info.circle")
            }
            .help("Video info")

            // Copy path
            Menu {
                Button("Copy File Path") {
                    if let path = video?.filePath {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(path, forType: .string)
                    }
                }
                Button("Show in Finder") {
                    if let path = video?.filePath {
                        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                    }
                }
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .help("Copy path or reveal in Finder")

            // Export
            Button("Export") {
                showExportSheet = true
            }
            .buttonStyle(.borderedProminent)
            .help("Export video")
        }
    }

    @ViewBuilder
    private func videoInfoPanel(state: EditorState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Info")
                    .font(.headline)
                    .padding(.bottom, 4)

                Text(state.videoRecord.title)
                    .font(.title3.bold())

                if let summary = state.videoRecord.summary, !summary.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Summary")
                            .font(.caption.bold())
                            .foregroundStyle(.tertiary)
                        Text(summary)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Label(formatTime(ms: state.videoRecord.durationMs), systemImage: "clock")
                    Label(formattedFileSize(state.videoRecord.fileSizeBytes), systemImage: "doc")
                    Label("\(state.videoRecord.width)x\(state.videoRecord.height)", systemImage: "rectangle")
                    Label(state.videoRecord.createdAt.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
    }

    private func formattedFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
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
