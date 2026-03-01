import AVFoundation
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "ExportService")

enum ExportService {

    static func exportMP4(
        filePath: String,
        edlSnapshot: EDLSnapshot,
        transcriptWords: [TranscriptWordSnapshot],
        durationMs: Int64,
        quality: VideoQuality,
        includeSubtitles: Bool,
        destURL: URL,
        progress: @escaping @MainActor (Double) -> Void
    ) async throws {
        let sourceURL = URL(fileURLWithPath: filePath)
        let snapshot = edlSnapshot

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
            snapshot: snapshot, durationMs: durationMs
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

        try await session.export(to: destURL, as: .mp4)
    }

    static func presetForQuality(_ quality: VideoQuality) -> String {
        switch quality {
        case .low: AVAssetExportPresetMediumQuality
        case .medium: AVAssetExportPreset1920x1080
        case .high: AVAssetExportPresetHighestQuality
        }
    }

    static func isExportUnmodified(
        snapshot: EDLSnapshot, durationMs: Int64
    ) -> Bool {
        snapshot.trimStartMs == 0
        && (snapshot.trimEndMs == 0 || snapshot.trimEndMs >= durationMs)
        && snapshot.cuts.isEmpty
        && snapshot.speedMultiplier == 1.0
        && snapshot.stitchVideoIDs.isEmpty
    }
}
