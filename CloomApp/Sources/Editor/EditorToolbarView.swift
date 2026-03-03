import SwiftUI
import AppKit

struct EditorToolbarView: View {
    let state: EditorState
    let video: VideoRecord?
    @Binding var cutMarkInMs: Int64?
    @Binding var showChapterPopover: Bool
    @Binding var showStitchPanel: Bool
    @Binding var showThumbnailPicker: Bool
    @Binding var showExportSheet: Bool
    @Binding var showInfoPanel: Bool
    @Binding var showBookmarksPanel: Bool

    var body: some View {
        HStack(spacing: 12) {
            playbackControls
            Divider().frame(height: 20)
            cutControls
            Spacer()
            trailingControls
        }
    }

    // MARK: - Playback

    @ViewBuilder
    private var playbackControls: some View {
        Button {
            state.togglePlayPause()
        } label: {
            Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                .font(.title3)
        }
        .keyboardShortcut(.space, modifiers: [])
        .help(state.isPlaying ? "Pause" : "Play")
        .accessibilityLabel(state.isPlaying ? "Pause" : "Play")

        Text(formatTime(ms: state.currentTimeMs))
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(.secondary)

        Text("/")
            .foregroundStyle(.tertiary)

        Text(formatTime(ms: state.durationMs))
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(.secondary)
    }

    // MARK: - Cut Controls

    @ViewBuilder
    private var cutControls: some View {
        if let markIn = cutMarkInMs {
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
    }

    // MARK: - Trailing Controls

    @ViewBuilder
    private var trailingControls: some View {
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

        Button {
            showBookmarksPanel.toggle()
        } label: {
            Image(systemName: showBookmarksPanel ? "bookmark.fill" : "bookmark")
                .foregroundStyle(.green)
        }
        .help("Bookmarks")
        .accessibilityLabel(showBookmarksPanel ? "Hide bookmarks" : "Show bookmarks")

        SpeedControlView(editorState: state)

        Button("Stitch") { showStitchPanel = true }
            .help("Stitch multiple clips together")
            .accessibilityLabel("Stitch clips")

        Button {
            showThumbnailPicker = true
        } label: {
            Image(systemName: "photo")
        }
        .help("Set custom thumbnail")
        .accessibilityLabel("Set custom thumbnail")

        transcriptControls
        windowControls

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

        Button("Share") { showExportSheet = true }
            .buttonStyle(.borderedProminent)
            .help("Share or export video")
            .accessibilityLabel("Share or export video")
    }

    @ViewBuilder
    private var transcriptControls: some View {
        if !state.transcriptWords.isEmpty {
            Button {
                state.toggleCaptions()
            } label: {
                Image(systemName: state.captionsEnabled ? "captions.bubble.fill" : "captions.bubble")
            }
            .help("Toggle captions")
            .accessibilityLabel(state.captionsEnabled ? "Disable captions" : "Enable captions")

            Button {
                state.toggleTranscript()
            } label: {
                Image(systemName: state.showTranscript ? "doc.text.fill" : "doc.text")
            }
            .help("Toggle transcript")
            .accessibilityLabel(state.showTranscript ? "Hide transcript" : "Show transcript")
        } else if state.isTranscribing {
            HStack(spacing: 4) {
                ProgressView().controlSize(.mini)
                Text("Transcribing...")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        } else {
            Button {
                state.generateTranscript()
            } label: {
                Label("Transcribe", systemImage: "waveform")
            }
            .help("Generate transcript for this video")
        }
    }

    @ViewBuilder
    private var windowControls: some View {
        Button {
            NSApp.mainWindow?.toggleFullScreen(nil)
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
        }
        .help("Toggle fullscreen")
        .accessibilityLabel("Toggle fullscreen")

        Button {
            showInfoPanel.toggle()
        } label: {
            Image(systemName: showInfoPanel ? "info.circle.fill" : "info.circle")
        }
        .help("Video info")
        .accessibilityLabel(showInfoPanel ? "Hide video info" : "Show video info")

        if let shareUrl = video?.shareUrl, !shareUrl.isEmpty {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(shareUrl, forType: .string)
            } label: {
                Image(systemName: "link")
                    .foregroundStyle(.green)
            }
            .help("Copy Drive share link")
            .accessibilityLabel("Copy share link")
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
