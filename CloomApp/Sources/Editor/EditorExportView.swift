import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "EditorExport")

enum ExportFormat: String, CaseIterable, Identifiable {
    case mp4 = "MP4"
    case gif = "GIF"
    var id: String { rawValue }
}

struct EditorExportView: View {
    let editorState: EditorState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFormat: ExportFormat = .mp4
    @State private var selectedQuality: VideoQuality = .medium
    @State private var gifWidth: Int = 480
    @State private var gifFPS: Int = 15
    @State private var isExporting = false
    @State private var exportProgress: Double = 0
    @State private var exportError: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Export Recording")
                .font(.headline)

            // Format picker
            Picker("Format", selection: $selectedFormat) {
                ForEach(ExportFormat.allCases) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .pickerStyle(.segmented)
            .disabled(isExporting)

            // Format-specific options
            if selectedFormat == .mp4 {
                Picker("Quality", selection: $selectedQuality) {
                    ForEach(VideoQuality.allCases) { quality in
                        Text(quality.label).tag(quality)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(isExporting)
            } else {
                HStack {
                    Text("Width:")
                    TextField("Width", value: $gifWidth, format: .number)
                        .frame(width: 60)
                    Text("px")

                    Spacer()

                    Text("FPS:")
                    TextField("FPS", value: $gifFPS, format: .number)
                        .frame(width: 40)
                }
                .disabled(isExporting)
            }

            // Edits summary
            if editorState.edl.hasEdits {
                HStack {
                    Image(systemName: "scissors")
                        .foregroundStyle(.secondary)
                    Text("Edits will be applied to export")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if isExporting {
                VStack(spacing: 8) {
                    ProgressView(value: exportProgress)
                    Text("\(Int(exportProgress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let exportError {
                Text(exportError)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .disabled(isExporting)
                Spacer()
                Button("Export") { startExport() }
                    .disabled(isExporting)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 400)
    }

    private func startExport() {
        let panel = NSSavePanel()

        if selectedFormat == .mp4 {
            panel.allowedContentTypes = [.mpeg4Movie]
            panel.nameFieldStringValue = editorState.videoRecord.title + " (Export).mp4"
        } else {
            panel.allowedContentTypes = [.gif]
            panel.nameFieldStringValue = editorState.videoRecord.title + " (Export).gif"
        }

        guard panel.runModal() == .OK, let destURL = panel.url else { return }

        isExporting = true
        exportError = nil

        Task {
            do {
                if selectedFormat == .mp4 {
                    try await exportMP4(to: destURL)
                } else {
                    try await exportGIF(to: destURL)
                }
                exportProgress = 1.0
                try? await Task.sleep(for: .milliseconds(500))
                dismiss()
            } catch {
                exportError = error.localizedDescription
                isExporting = false
            }
        }
    }

    private func exportMP4(to destURL: URL) async throws {
        let builder = EditorCompositionBuilder()
        let sourceURL = URL(fileURLWithPath: editorState.videoRecord.filePath)
        let snapshot = EDLSnapshot(from: editorState.edl)

        let result = try await builder.build(
            edl: snapshot,
            sourceURL: sourceURL,
            stitchURLs: []
        )

        guard let session = AVAssetExportSession(
            asset: result.composition,
            presetName: presetForQuality(selectedQuality)
        ) else {
            throw NSError(domain: "EditorExport", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not create export session"])
        }

        try await session.export(to: destURL, as: .mp4)
    }

    private func exportGIF(to destURL: URL) async throws {
        let service = GifExportService()
        let sourceURL = URL(fileURLWithPath: editorState.videoRecord.filePath)
        let snapshot = EDLSnapshot(from: editorState.edl)

        try await service.export(
            sourceURL: sourceURL,
            edl: snapshot,
            outputURL: destURL,
            width: gifWidth,
            fps: gifFPS
        ) { progress in
            Task { @MainActor in
                exportProgress = progress
            }
        }
    }

    private func presetForQuality(_ quality: VideoQuality) -> String {
        switch quality {
        case .low: AVAssetExportPresetMediumQuality
        case .medium: AVAssetExportPresetHighestQuality
        case .high: AVAssetExportPresetHighestQuality
        }
    }
}
