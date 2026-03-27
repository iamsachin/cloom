import SwiftUI

/// Toolbar section for auto-cut features (silence/filler removal).
/// Shows preview/apply/cancel controls.
struct AutoCutToolbarView: View {
    let state: EditorState

    var body: some View {
        if state.isShowingCutPreview {
            previewControls
        } else {
            autoCutButtons
        }
    }

    // MARK: - Preview Mode

    @ViewBuilder
    private var previewControls: some View {
        HStack(spacing: 6) {
            Image(systemName: "eye")
                .foregroundStyle(.orange)
            Text("\(state.previewCutRanges.count) \(state.previewCutLabel)")
                .font(.caption)
                .foregroundStyle(.orange)

            Button("Apply") {
                state.applyPreviewedCuts()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.small)

            Button("Cancel") {
                state.dismissCutPreview()
            }
            .controlSize(.small)
        }
    }

    // MARK: - Auto-Cut Buttons

    @ViewBuilder
    private var autoCutButtons: some View {
        if !state.silenceRanges.isEmpty {
            Button {
                state.previewSilenceRemoval()
            } label: {
                Label("Silences", systemImage: "waveform.slash")
            }
            .help("Preview and remove silent regions")
        }

        if state.transcriptWords.contains(where: { $0.isFillerWord }) {
            Button {
                state.previewFillerRemoval()
            } label: {
                Label("Fillers", systemImage: "text.line.last.and.arrowtriangle.forward")
            }
            .help("Preview and remove filler words")
        }
    }
}
