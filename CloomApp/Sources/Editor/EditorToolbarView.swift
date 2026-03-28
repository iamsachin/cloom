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
    @Binding var showCommentsPanel: Bool

    var body: some View {
        HStack(spacing: 12) {
            playbackControls
            Divider().frame(height: 20)
            cutControls
            Divider().frame(height: 20)
            AutoCutToolbarView(state: state)
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
                .font(.title2)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.hover)
        .keyboardShortcut(.space, modifiers: [])
        .help(state.isPlaying ? "Pause" : "Play")
        .accessibilityLabel(state.isPlaying ? "Pause" : "Play")

        Text(formatTime(ms: state.currentTimeMs))
            .font(.system(.body, design: .monospaced).weight(.medium))
            .foregroundStyle(.primary)

        Text("/")
            .foregroundStyle(.quaternary)

        Text(formatTime(ms: state.durationMs))
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.tertiary)
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
        // Navigation / speed group
        if !state.chapters.isEmpty {
            Button {
                showChapterPopover.toggle()
            } label: {
                Image(systemName: "list.bullet")
            }
            .buttonStyle(.hover)
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
        .buttonStyle(.hover)
        .help("Bookmarks")
        .accessibilityLabel(showBookmarksPanel ? "Hide bookmarks" : "Show bookmarks")

        Button {
            showCommentsPanel.toggle()
        } label: {
            Image(systemName: showCommentsPanel ? "text.bubble.fill" : "text.bubble")
                .foregroundStyle(.blue)
        }
        .buttonStyle(.hover)
        .help("Comments")
        .accessibilityLabel(showCommentsPanel ? "Hide comments" : "Show comments")

        SpeedControlView(editorState: state)

        Divider().frame(height: 20)

        // Editing group
        Button("Stitch") { showStitchPanel = true }
            .help("Stitch multiple clips together")
            .accessibilityLabel("Stitch clips")

        Button {
            showThumbnailPicker = true
        } label: {
            Image(systemName: "photo")
        }
        .buttonStyle(.hover)
        .help("Set custom thumbnail")
        .accessibilityLabel("Set custom thumbnail")

        Divider().frame(height: 20)

        // Transcript group
        transcriptControls

        Divider().frame(height: 20)

        // Window / info group
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

        Divider().frame(height: 20)

        // Share CTA
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
            .buttonStyle(.hover)
            .help("Toggle captions")
            .accessibilityLabel(state.captionsEnabled ? "Disable captions" : "Enable captions")

            Button {
                state.toggleTranscript()
            } label: {
                Image(systemName: state.showTranscript ? "doc.text.fill" : "doc.text")
            }
            .buttonStyle(.hover)
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
        .buttonStyle(.hover)
        .help("Toggle fullscreen")
        .accessibilityLabel("Toggle fullscreen")

        Button {
            showInfoPanel.toggle()
        } label: {
            Image(systemName: showInfoPanel ? "info.circle.fill" : "info.circle")
        }
        .buttonStyle(.hover)
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
            .buttonStyle(.hover)
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
