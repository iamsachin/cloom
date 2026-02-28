import AVFoundation
import CoreImage
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "ExportService")

enum ExportService {

    static func exportMP4(
        videoRecord: VideoRecord,
        edl: EditDecisionList,
        transcriptWords: [TranscriptWordRecord],
        durationMs: Int64,
        quality: VideoQuality,
        brightness: Float,
        contrast: Float,
        includeSubtitles: Bool,
        destURL: URL,
        progress: @escaping @MainActor (Double) -> Void
    ) async throws {
        let sourceURL = URL(fileURLWithPath: videoRecord.filePath)
        let snapshot = EDLSnapshot(from: edl)

        var subtitlePhrases: [SubtitlePhrase] = []
        if includeSubtitles {
            let subtitleService = SubtitleExportService()
            subtitlePhrases = await subtitleService.buildPhrases(
                from: transcriptWords,
                edl: snapshot,
                totalDurationMs: durationMs
            )
        }

        let unmodified = isExportUnmodified(
            snapshot: snapshot, durationMs: durationMs,
            brightness: brightness, contrast: contrast
        )

        if unmodified && subtitlePhrases.isEmpty {
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            logger.info("Passthrough copy → \(destURL.lastPathComponent)")
            return
        }

        if unmodified && !subtitlePhrases.isEmpty {
            try await ExportWriter.remuxWithSubtitles(
                sourceURL: sourceURL,
                outputURL: destURL,
                phrases: subtitlePhrases
            ) { p in
                Task { @MainActor in progress(p) }
            }
            return
        }

        let builder = EditorCompositionBuilder()
        let result = try await builder.build(
            edl: snapshot,
            sourceURL: sourceURL,
            stitchURLs: []
        )

        if !subtitlePhrases.isEmpty {
            try await ExportWriter.exportEdited(
                composition: result.composition,
                audioMix: result.audioMix,
                brightness: brightness,
                contrast: contrast,
                subtitlePhrases: subtitlePhrases,
                outputURL: destURL
            ) { p in
                Task { @MainActor in progress(p) }
            }
            return
        }

        guard let session = AVAssetExportSession(
            asset: result.composition,
            presetName: presetForQuality(quality)
        ) else {
            throw NSError(
                domain: "ExportService", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Could not create export session"]
            )
        }

        if let audioMix = result.audioMix {
            session.audioMix = audioMix
        }

        let needsAdjustment = brightness != 0 || contrast != 1
        if needsAdjustment {
            let ciContext = SharedCIContext.instance

            let videoComp = try await AVVideoComposition(
                applyingFiltersTo: result.composition
            ) { params in
                var image = params.sourceImage.clampedToExtent()
                image = image.applyingFilter("CIColorControls", parameters: [
                    kCIInputBrightnessKey: brightness,
                    kCIInputContrastKey: contrast,
                ])
                image = image.cropped(to: params.sourceImage.extent)
                return AVCIImageFilteringResult(resultImage: image, ciContext: ciContext)
            }
            session.videoComposition = videoComp
        }

        try await session.export(to: destURL, as: .mp4)
    }

    static func presetForQuality(_ quality: VideoQuality) -> String {
        switch quality {
        case .low: AVAssetExportPresetMediumQuality
        case .medium: AVAssetExportPresetHighQuality
        case .high: AVAssetExportPresetHighestQuality
        }
    }

    static func isExportUnmodified(
        snapshot: EDLSnapshot, durationMs: Int64,
        brightness: Float, contrast: Float
    ) -> Bool {
        snapshot.trimStartMs == 0
        && (snapshot.trimEndMs == 0 || snapshot.trimEndMs >= durationMs)
        && snapshot.cuts.isEmpty
        && snapshot.speedMultiplier == 1.0
        && snapshot.stitchVideoIDs.isEmpty
        && brightness == 0
        && contrast == 1
    }
}
