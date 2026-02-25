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
    @State private var showChapterPopover = false
    @State private var showInfoPanel = false
    @State private var showBookmarksPanel = false

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
            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    VideoPreviewView(
                        player: state.player,
                        onTap: { state.togglePlayPause() },
                        onPiPControllerReady: { controller in
                            state.pipController = controller
                        }
                    )

                    CaptionOverlayView(
                        phrases: state.captionPhrases,
                        currentTimeMs: state.currentTimeMs,
                        isEnabled: state.captionsEnabled
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                EditorTimelineView(editorState: state)
                    .frame(height: 120)
                    .padding(.horizontal, 8)

                Divider()

                EditorToolbarView(
                    state: state,
                    video: video,
                    cutMarkInMs: $cutMarkInMs,
                    showChapterPopover: $showChapterPopover,
                    showStitchPanel: $showStitchPanel,
                    showThumbnailPicker: $showThumbnailPicker,
                    showExportSheet: $showExportSheet,
                    showInfoPanel: $showInfoPanel,
                    showBookmarksPanel: $showBookmarksPanel
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            if state.showTranscript && state.videoRecord.hasTranscript {
                Divider()
                TranscriptPanelView(editorState: state)
            }

            if showInfoPanel {
                Divider()
                EditorInfoPanel(
                    videoRecord: state.videoRecord,
                    durationMs: state.videoRecord.durationMs
                )
                .frame(width: 260)
            }

            if showBookmarksPanel {
                Divider()
                BookmarksPanelView(editorState: state)
            }
        }
        .onKeyPress("b") {
            state.addBookmark(ms: state.currentTimeMs)
            return .handled
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

    private func setupEditor() {
        guard let video, editorState == nil else { return }
        let state = EditorState(videoRecord: video, modelContext: modelContext)
        self.editorState = state

        Task {
            await state.loadWaveform()
            await state.loadThumbnailStrip()
        }
    }
}
