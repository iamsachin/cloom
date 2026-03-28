import SwiftUI
import SwiftData

// MARK: - Editor Content View

struct EditorContentView: View {
    let videoID: String

    @Environment(NavigationState.self) private var navigationState
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
    @State private var showCommentsPanel = false

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
        .onAppear { setupEditor() }
        .onChange(of: video) { _, newVideo in
            // Auto-navigate back if video is deleted while editing
            if newVideo == nil && editorState != nil {
                editorState?.player.pause()
                navigationState.goBackToLibrary()
            }
        }
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

                EditorTimelineView(editorState: state, cutMarkInMs: cutMarkInMs)
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
                    showBookmarksPanel: $showBookmarksPanel,
                    showCommentsPanel: $showCommentsPanel
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            if state.showTranscript && !state.transcriptWords.isEmpty {
                Divider()
                TranscriptPanelView(editorState: state)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            if showInfoPanel {
                Divider()
                EditorInfoPanel(
                    videoRecord: state.videoRecord,
                    durationMs: state.videoRecord.durationMs
                )
                .frame(width: 260)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            if showBookmarksPanel {
                Divider()
                BookmarksPanelView(editorState: state)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            if showCommentsPanel {
                Divider()
                CommentsPanelView(editorState: state)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: state.showTranscript)
        .animation(.easeInOut(duration: 0.25), value: showInfoPanel)
        .animation(.easeInOut(duration: 0.25), value: showBookmarksPanel)
        .animation(.easeInOut(duration: 0.25), value: showCommentsPanel)
        .editorKeyboardShortcuts(state: state, cutMarkInMs: $cutMarkInMs)
        .navigationTitle(state.videoRecord.title)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    editorState?.player.pause()
                    navigationState.goBack()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .keyboardShortcut("[", modifiers: .command)
            }
        }
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

        Task { await state.loadWaveform() }
        Task { await state.loadThumbnailStrip() }
    }
}
