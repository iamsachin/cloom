import SwiftUI

/// Controls for managing blur regions: draw toggle, selected region editing, region list.
struct BlurRegionControlsView: View {
    let editorState: EditorState
    @Binding var isDrawing: Bool
    @Binding var selectedRegionID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if let selected = selectedRegion {
                selectedRegionEditor(selected)
            }
            regionList
            Spacer()
        }
        .padding(12)
        .frame(width: 240)
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        HStack {
            Label("Blur Regions", systemImage: "eye.slash")
                .font(.headline)
            Spacer()
            Toggle(isOn: $isDrawing) {
                Image(systemName: "plus.rectangle.on.rectangle")
            }
            .toggleStyle(.button)
            .help(isDrawing ? "Stop drawing" : "Draw new blur region")
        }
    }

    // MARK: - Selected Region Editor

    private var selectedRegion: BlurRegion? {
        guard let id = selectedRegionID else { return nil }
        return editorState.edl.blurRegions.first { $0.id == id }
    }

    @ViewBuilder
    private func selectedRegionEditor(_ region: BlurRegion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selected Region")
                .font(.subheadline.weight(.semibold))

            // Blur style picker — use short labels to fit in 240pt panel
            Picker("Style", selection: styleBinding(for: region)) {
                Text("Blur").tag(BlurStyle.gaussian)
                Text("Pixel").tag(BlurStyle.pixelate)
                Text("Black").tag(BlurStyle.blackBox)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            // Time range — formatted as m:ss
            HStack(spacing: 6) {
                Text("Start")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(formatTimePrecise(ms: region.startMs))
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                Spacer()
                Text("End")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(formatTimePrecise(ms: region.endMs))
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            }

            HStack(spacing: 8) {
                Button("Set Start") {
                    var updated = region
                    updated.startMs = editorState.currentTimeMs
                    editorState.updateBlurRegion(updated)
                }
                .font(.caption)
                .controlSize(.small)

                Button("Set End") {
                    var updated = region
                    updated.endMs = editorState.currentTimeMs
                    editorState.updateBlurRegion(updated)
                }
                .font(.caption)
                .controlSize(.small)

                Spacer()

                Button(role: .destructive) {
                    editorState.removeBlurRegion(id: region.id)
                    selectedRegionID = nil
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }

    private func formatTimePrecise(ms: Int64) -> String {
        let totalSeconds = Int(ms / 1000)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let centis = Int((ms % 1000) / 10)
        return String(format: "%d:%02d.%02d", minutes, seconds, centis)
    }

    // MARK: - Region List

    @ViewBuilder
    private var regionList: some View {
        let regions = editorState.edl.blurRegions
        if regions.isEmpty {
            Text("No blur regions. Toggle the draw button and drag on the video to create one.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(regions) { region in
                        regionRow(region)
                    }
                }
            }
            .frame(maxHeight: 200)
        }
    }

    @ViewBuilder
    private func regionRow(_ region: BlurRegion) -> some View {
        let isSelected = selectedRegionID == region.id
        HStack {
            Image(systemName: iconForStyle(region.style))
                .foregroundStyle(.secondary)
            Text(region.style.displayName)
                .font(.caption)
            Spacer()
            Text("\(formatTime(ms: region.startMs))–\(formatTime(ms: region.endMs))")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture {
            selectedRegionID = isSelected ? nil : region.id
        }
    }

    private func iconForStyle(_ style: BlurStyle) -> String {
        switch style {
        case .gaussian: "aqi.medium"
        case .pixelate: "squareshape.split.3x3"
        case .blackBox: "rectangle.fill"
        }
    }

    // MARK: - Bindings

    private func styleBinding(for region: BlurRegion) -> Binding<BlurStyle> {
        Binding(
            get: { region.style },
            set: { newStyle in
                var updated = region
                updated.style = newStyle
                editorState.updateBlurRegion(updated)
            }
        )
    }

    private func formatTime(ms: Int64) -> String {
        let totalSeconds = Int(ms / 1000)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
