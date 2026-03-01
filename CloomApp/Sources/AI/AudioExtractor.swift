import AVFoundation
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "AudioExtractor")

/// Extract audio from MP4 to a temporary .m4a file.
/// Prefers the mic audio track (second audio track) over system audio.
/// Falls back to mixing all audio tracks if only one exists.
func extractAudioFromVideo(videoPath: String) async throws -> String {
    let videoURL = URL(fileURLWithPath: videoPath)
    let asset = AVURLAsset(url: videoURL)
    let audioTracks = try await asset.loadTracks(withMediaType: .audio)

    guard !audioTracks.isEmpty else {
        throw NSError(domain: "AudioExtractor", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "No audio tracks found in video"
        ])
    }

    let composition = AVMutableComposition()
    let duration = try await asset.load(.duration)

    if audioTracks.count >= 2 {
        let micTrack = audioTracks[1]
        if let compositionTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) {
            try compositionTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: duration),
                of: micTrack,
                at: .zero
            )
        }
        logger.info("Using mic audio track (track 2 of \(audioTracks.count) audio tracks)")
    } else {
        let track = audioTracks[0]
        if let compositionTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) {
            try compositionTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: duration),
                of: track,
                at: .zero
            )
        }
        logger.info("Using single audio track")
    }

    let tempDir = FileManager.default.temporaryDirectory
    let outputURL = tempDir.appendingPathComponent("cloom_audio_\(UUID().uuidString).m4a")

    guard let exportSession = AVAssetExportSession(
        asset: composition,
        presetName: AVAssetExportPresetAppleM4A
    ) else {
        throw NSError(domain: "AudioExtractor", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "Failed to create export session"
        ])
    }

    try await exportSession.export(to: outputURL, as: .m4a)

    return outputURL.path
}

/// Calculate the number of chunks needed to split a file under a size limit.
func calculateChunkCount(fileSize: Int, maxChunkBytes: Int) -> Int {
    guard fileSize > maxChunkBytes, maxChunkBytes > 0 else { return 1 }
    return Int(ceil(Double(fileSize) / Double(maxChunkBytes)))
}

/// Calculate the duration of each chunk given a total duration and chunk count.
func calculateChunkDuration(totalSeconds: Double, chunkCount: Int) -> Double {
    guard chunkCount > 0 else { return totalSeconds }
    return totalSeconds / Double(chunkCount)
}

/// Split an audio file into chunks under `maxChunkBytes` for the Whisper API.
/// Returns an array of (filePath, offsetMs) tuples.
/// If the file is already small enough, returns a single entry with offset 0.
func splitAudioForTranscription(audioPath: String, maxChunkBytes: Int = 20 * 1024 * 1024) async throws -> [(path: String, offsetMs: Int64)] {
    let fileURL = URL(fileURLWithPath: audioPath)
    let fileSize = try FileManager.default.attributesOfItem(atPath: audioPath)[.size] as? Int ?? 0

    if fileSize <= maxChunkBytes {
        return [(path: audioPath, offsetMs: 0)]
    }

    let asset = AVURLAsset(url: fileURL)
    let duration = try await asset.load(.duration)
    let totalSeconds = CMTimeGetSeconds(duration)

    guard totalSeconds > 0 else {
        return [(path: audioPath, offsetMs: 0)]
    }

    let chunkCount = calculateChunkCount(fileSize: fileSize, maxChunkBytes: maxChunkBytes)
    let chunkDurationSeconds = calculateChunkDuration(totalSeconds: totalSeconds, chunkCount: chunkCount)

    var chunks: [(path: String, offsetMs: Int64)] = []
    let tempDir = FileManager.default.temporaryDirectory

    for i in 0..<chunkCount {
        let startSeconds = Double(i) * chunkDurationSeconds
        let endSeconds = min(startSeconds + chunkDurationSeconds, totalSeconds)
        let startTime = CMTime(seconds: startSeconds, preferredTimescale: 1000)
        let chunkDuration = CMTime(seconds: endSeconds - startSeconds, preferredTimescale: 1000)
        let timeRange = CMTimeRange(start: startTime, duration: chunkDuration)

        let composition = AVMutableComposition()
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        for srcTrack in audioTracks {
            if let compTrack = composition.addMutableTrack(
                withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid
            ) {
                try compTrack.insertTimeRange(timeRange, of: srcTrack, at: .zero)
            }
        }

        let chunkURL = tempDir.appendingPathComponent("cloom_audio_chunk_\(i)_\(UUID().uuidString).m4a")

        guard let session = AVAssetExportSession(
            asset: composition, presetName: AVAssetExportPresetAppleM4A
        ) else {
            logger.warning("Failed to create export session for chunk \(i)")
            continue
        }

        try await session.export(to: chunkURL, as: .m4a)

        let offsetMs = Int64(startSeconds * 1000)
        chunks.append((path: chunkURL.path, offsetMs: offsetMs))
        logger.info("Audio chunk \(i + 1)/\(chunkCount): \(String(format: "%.1f", startSeconds))s–\(String(format: "%.1f", endSeconds))s")
    }

    return chunks
}
