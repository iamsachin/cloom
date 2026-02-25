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
