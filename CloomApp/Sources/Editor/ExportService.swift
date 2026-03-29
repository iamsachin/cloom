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
        recordingQuality: VideoQuality?,
        includeSubtitles: Bool,
        reframeConfig: ReframeConfig? = nil,
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
        let qualityMatchesRecording = quality == (recordingQuality ?? quality)
        let hasReframe = reframeConfig != nil
        let hasBlurRegions = !snapshot.blurRegions.isEmpty

        // Unmodified + quality matches recording + no subtitles + no reframe → passthrough copy
        if unmodified && qualityMatchesRecording && subtitlePhrases.isEmpty && !hasReframe {
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            logger.info("Passthrough copy → \(destURL.lastPathComponent)")
            return
        }

        // Unmodified + quality matches recording + subtitles + no reframe → inject directly
        if unmodified && qualityMatchesRecording && !subtitlePhrases.isEmpty && !hasReframe {
            try await ExportWriter.injectSubtitles(
                sourceURL: sourceURL,
                outputURL: destURL,
                phrases: subtitlePhrases,
                durationMs: durationMs
            ) { p in Task { @MainActor in progress(p) } }
            return
        }

        // Unmodified + no reframe + different quality → re-encode from source asset
        if unmodified && !hasReframe {
            let asset = AVURLAsset(url: sourceURL)
            if subtitlePhrases.isEmpty {
                guard let session = AVAssetExportSession(
                    asset: asset,
                    presetName: presetForQuality(quality)
                ) else {
                    throw NSError(
                        domain: "ExportService", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Could not create export session"]
                    )
                }
                try await session.export(to: destURL, as: .mp4)
                logger.info("Re-encoded at \(quality.rawValue) quality → \(destURL.lastPathComponent)")
                return
            }

            // Re-encode to temp, then inject subtitles
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".mp4")
            defer { try? FileManager.default.removeItem(at: tempURL) }

            guard let session = AVAssetExportSession(
                asset: asset,
                presetName: presetForQuality(quality)
            ) else {
                throw NSError(
                    domain: "ExportService", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Could not create export session"]
                )
            }
            try await session.export(to: tempURL, as: .mp4)

            try await ExportWriter.injectSubtitles(
                sourceURL: tempURL,
                outputURL: destURL,
                phrases: subtitlePhrases,
                durationMs: durationMs
            ) { p in Task { @MainActor in progress(p) } }
            return
        }

        // Reframe from source (unmodified video, just reframing)
        if unmodified && hasReframe {
            let asset = AVURLAsset(url: sourceURL)
            try await exportWithReframe(
                asset: asset,
                audioMix: nil,
                reframeConfig: reframeConfig!,
                quality: quality,
                subtitlePhrases: subtitlePhrases,
                durationMs: durationMs,
                destURL: destURL,
                progress: progress
            )
            return
        }

        // Edited: build composition
        let builder = EditorCompositionBuilder()
        let result = try await builder.build(
            edl: snapshot,
            sourceURL: sourceURL,
            stitchURLs: []
        )

        // Edited + reframe
        if hasReframe {
            try await exportWithReframe(
                asset: result.composition,
                audioMix: result.audioMix,
                reframeConfig: reframeConfig!,
                quality: quality,
                subtitlePhrases: subtitlePhrases,
                durationMs: Int64(result.composition.duration.seconds * 1000),
                destURL: destURL,
                progress: progress
            )
            return
        }

        // Edited + no subtitles → AVAssetExportSession
        if subtitlePhrases.isEmpty {
            let preset = hasBlurRegions ? AVAssetExportPresetHighestQuality : presetForQuality(quality)
            guard let session = AVAssetExportSession(
                asset: result.composition,
                presetName: preset
            ) else {
                throw NSError(
                    domain: "ExportService", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Could not create export session"]
                )
            }
            if let audioMix = result.audioMix {
                session.audioMix = audioMix
            }
            let sourceSize = await resolveVideoSize(for: result.composition)
            try await applyBlurIfNeeded(
                to: session, asset: result.composition,
                blurRegions: snapshot.blurRegions, sourceSize: sourceSize
            )
            if hasBlurRegions {
                try await exportWithProgress(session: session, destURL: destURL, progress: progress)
            } else {
                try await session.export(to: destURL, as: .mp4)
            }
            return
        }

        // Edited + subtitles → export to temp, then inject subtitles
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mp4")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let preset = hasBlurRegions ? AVAssetExportPresetHighestQuality : presetForQuality(quality)
        guard let session = AVAssetExportSession(
            asset: result.composition,
            presetName: preset
        ) else {
            throw NSError(
                domain: "ExportService", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Could not create export session"]
            )
        }
        if let audioMix = result.audioMix {
            session.audioMix = audioMix
        }
        let sourceSize = await resolveVideoSize(for: result.composition)
        try await applyBlurIfNeeded(
            to: session, asset: result.composition,
            blurRegions: snapshot.blurRegions, sourceSize: sourceSize
        )
        if hasBlurRegions {
            try await exportWithProgress(session: session, destURL: tempURL, progress: progress)
        } else {
            try await session.export(to: tempURL, as: .mp4)
        }

        let compositionDurationMs = Int64(result.composition.duration.seconds * 1000)
        try await ExportWriter.injectSubtitles(
            sourceURL: tempURL,
            outputURL: destURL,
            phrases: subtitlePhrases,
            durationMs: compositionDurationMs
        ) { p in Task { @MainActor in progress(p) } }
    }

    // MARK: - Reframe Export

    private static func exportWithReframe(
        asset: AVAsset,
        audioMix: AVMutableAudioMix?,
        reframeConfig: ReframeConfig,
        quality: VideoQuality,
        subtitlePhrases: [SubtitlePhrase],
        durationMs: Int64,
        destURL: URL,
        progress: @escaping @MainActor (Double) -> Void
    ) async throws {
        let videoComposition = try await ReframeCompositor.buildVideoComposition(
            for: asset,
            config: reframeConfig
        )

        // Must use HighestQuality preset — named resolution presets ignore videoComposition
        guard let session = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw NSError(
                domain: "ExportService", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Could not create export session"]
            )
        }
        session.videoComposition = videoComposition
        if let audioMix { session.audioMix = audioMix }

        if subtitlePhrases.isEmpty {
            try await session.export(to: destURL, as: .mp4)
            logger.info("Reframe export → \(destURL.lastPathComponent)")
        } else {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".mp4")
            defer { try? FileManager.default.removeItem(at: tempURL) }

            try await session.export(to: tempURL, as: .mp4)

            try await ExportWriter.injectSubtitles(
                sourceURL: tempURL,
                outputURL: destURL,
                phrases: subtitlePhrases,
                durationMs: durationMs
            ) { p in Task { @MainActor in progress(p) } }
            logger.info("Reframe + subtitles export → \(destURL.lastPathComponent)")
        }
    }

    static func presetForQuality(_ quality: VideoQuality) -> String {
        switch quality {
        case .low: AVAssetExportPresetMediumQuality
        case .medium: AVAssetExportPreset1920x1080
        case .high: AVAssetExportPresetHighestQuality
        }
    }

    /// Exports with progress polling — needed because `session.export(to:as:)` doesn't report progress.
    private static func exportWithProgress(
        session: AVAssetExportSession,
        destURL: URL,
        progress: @escaping @MainActor (Double) -> Void
    ) async throws {
        session.outputURL = destURL
        session.outputFileType = .mp4

        // Poll progress on a background task
        nonisolated(unsafe) let sessionRef = session
        let pollingTask = Task { @MainActor in
            while !Task.isCancelled {
                progress(Double(sessionRef.progress))
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
        defer { pollingTask.cancel() }

        try await session.export(to: destURL, as: .mp4)
    }

    /// Attaches a blur region video composition to an export session if blur regions exist.
    /// Must use HighestQuality preset when applying video compositions.
    private static func applyBlurIfNeeded(
        to session: AVAssetExportSession,
        asset: AVAsset,
        blurRegions: [BlurRegion],
        sourceSize: CGSize
    ) async throws {
        guard !blurRegions.isEmpty else { return }
        let videoComposition = try await BlurRegionCompositor.buildVideoComposition(
            for: asset,
            regions: blurRegions,
            sourceSize: sourceSize
        )
        session.videoComposition = videoComposition
    }

    /// Resolves the natural size of the video asset's first video track.
    private static func resolveVideoSize(for asset: AVAsset) async -> CGSize {
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let size = try? await track.load(.naturalSize),
              size.width > 0 && size.height > 0 else {
            return CGSize(width: 1920, height: 1080)
        }
        return size
    }

    static func isExportUnmodified(
        snapshot: EDLSnapshot, durationMs: Int64
    ) -> Bool {
        snapshot.trimStartMs == 0
        && (snapshot.trimEndMs == 0 || snapshot.trimEndMs >= durationMs)
        && snapshot.cuts.isEmpty
        && snapshot.speedMultiplier == 1.0
        && snapshot.stitchVideoIDs.isEmpty
        && snapshot.blurRegions.isEmpty
    }
}
