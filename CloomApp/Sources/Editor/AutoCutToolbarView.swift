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
        let selectedCount = state.selectedPreviewIDs.count
        let totalCount = state.previewCutRanges.count

        HStack(spacing: 6) {
            Image(systemName: "eye")
                .foregroundStyle(.orange)
            Text("\(selectedCount) of \(totalCount) \(state.previewCutLabel)")
                .font(.caption)
                .foregroundStyle(.orange)

            Button("Select All") {
                state.selectAllPreviews()
            }
            .controlSize(.small)
            .disabled(selectedCount == totalCount)

            Button("Deselect All") {
                state.deselectAllPreviews()
            }
            .controlSize(.small)
            .disabled(selectedCount == 0)

            Button("Apply") {
                state.applyPreviewedCuts()
            }
            .buttonStyle(.glassProminent)
            .tint(.orange)
            .controlSize(.small)
            .disabled(selectedCount == 0)

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
