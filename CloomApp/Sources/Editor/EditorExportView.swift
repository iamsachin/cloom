import SwiftUI
import AVFoundation
import CoreImage
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
    @State private var exportBrightness: Float = 0
    @State private var exportContrast: Float = 1
    @State private var subtitleMode: SubtitleMode = .none

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

                VStack(alignment: .leading, spacing: 6) {
                    Text("Video Adjustments")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text("Brightness")
                            .font(.caption)
                            .frame(width: 70, alignment: .leading)
                        Slider(value: Binding(
                            get: { Double(exportBrightness) },
                            set: { exportBrightness = Float($0) }
                        ), in: -1...1)
                        Text(String(format: "%.2f", exportBrightness))
                            .font(.caption.monospacedDigit())
                            .frame(width: 40)
                    }

                    HStack {
                        Text("Contrast")
                            .font(.caption)
                            .frame(width: 70, alignment: .leading)
                        Slider(value: Binding(
                            get: { Double(exportContrast) },
                            set: { exportContrast = Float($0) }
                        ), in: 0...4)
                        Text(String(format: "%.2f", exportContrast))
                            .font(.caption.monospacedDigit())
                            .frame(width: 40)
                    }
                }
                .disabled(isExporting)

                if editorState.videoRecord.hasTranscript {
                    Picker("Subtitles", selection: $subtitleMode) {
                        ForEach(SubtitleMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .disabled(isExporting)
                }
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

        // Apply audio mix for multi-track audio
        if let audioMix = result.audioMix {
            session.audioMix = audioMix
        }

        // Build subtitle phrases if needed
        var subtitlePhrases: [SubtitlePhrase] = []
        if subtitleMode.needsHardBurn || subtitleMode.needsSRT {
            let subtitleService = SubtitleExportService()
            subtitlePhrases = await subtitleService.buildPhrases(
                from: editorState.transcriptWords,
                edl: snapshot,
                totalDurationMs: editorState.durationMs
            )
        }

        // Apply video composition if brightness/contrast or hard-burn subtitles needed
        let needsAdjustment = exportBrightness != 0 || exportContrast != 1
        let needsHardBurn = subtitleMode.needsHardBurn && !subtitlePhrases.isEmpty

        if needsAdjustment || needsHardBurn {
            let brightness = exportBrightness
            let contrast = exportContrast
            let phrases = subtitlePhrases
            let ciContext = CIContext(options: [.useSoftwareRenderer: false])

            let videoComp = try await AVMutableVideoComposition.videoComposition(
                with: result.composition,
                applyingCIFiltersWithHandler: { request in
                    var image = request.sourceImage.clampedToExtent()

                    // Apply brightness/contrast
                    if needsAdjustment {
                        image = image.applyingFilter("CIColorControls", parameters: [
                            kCIInputBrightnessKey: brightness,
                            kCIInputContrastKey: contrast,
                        ])
                    }

                    image = image.cropped(to: request.sourceImage.extent)

                    // Burn subtitles
                    if needsHardBurn {
                        let frameTimeMs = Int64(request.compositionTime.seconds * 1000)
                        let extent = request.sourceImage.extent
                        image = SubtitleExportService.burnSubtitle(
                            onto: image,
                            phrases: phrases,
                            frameTimeMs: frameTimeMs,
                            videoWidth: extent.width,
                            videoHeight: extent.height
                        )
                    }

                    request.finish(with: image, context: ciContext)
                }
            )
            session.videoComposition = videoComp
        }

        try await session.export(to: destURL, as: .mp4)

        // Generate SRT sidecar if requested
        if subtitleMode.needsSRT && !subtitlePhrases.isEmpty {
            let srtURL = destURL.deletingPathExtension().appendingPathExtension("srt")
            let subtitleService = SubtitleExportService()
            try await subtitleService.generateSRT(phrases: subtitlePhrases, outputURL: srtURL)
        }
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
