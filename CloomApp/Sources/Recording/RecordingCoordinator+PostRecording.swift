import SwiftUI
import SwiftData
import AVFoundation
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "RecordingCoordinator")

// MARK: - Post-Recording

extension RecordingCoordinator {

    func handleRecordingFinished(outputURL: URL) async {
        let tracker = PostRecordingTracker.shared
        let asset = AVURLAsset(url: outputURL)

        let duration: CMTime
        do {
            duration = try await asset.load(.duration)
        } catch {
            logger.error("Failed to load duration: \(error)")
            duration = .zero
        }

        var width: Int32 = 0
        var height: Int32 = 0
        do {
            let tracks = try await asset.loadTracks(withMediaType: .video)
            if let track = tracks.first {
                let size = try await track.load(.naturalSize)
                width = Int32(size.width)
                height = Int32(size.height)
            }
        } catch {
            logger.error("Failed to load video track: \(error)")
        }

        let fileSize: Int64
        if let attrs = try? FileManager.default.attributesOfItem(atPath: outputURL.path),
           let size = attrs[.size] as? Int64 {
            fileSize = size
        } else {
            fileSize = 0
        }

        tracker.updateStep(.generatingThumbnail)
        let thumbnailPath = await ThumbnailGenerator.generateThumbnail(for: outputURL) ?? ""

        let recordingType: String
        if cameraEnabled {
            recordingType = "screenAndWebcam"
        } else {
            recordingType = "screenOnly"
        }

        tracker.updateStep(.saving)
        let context = ModelContext(modelContainer)
        let durationMs = Int64(duration.seconds * 1000)
        let record = VideoRecord(
            title: outputURL.deletingPathExtension().lastPathComponent,
            filePath: outputURL.path,
            thumbnailPath: thumbnailPath,
            durationMs: durationMs,
            width: width,
            height: height,
            fileSizeBytes: fileSize,
            recordingType: recordingType,
            webcamFilePath: nil
        )
        context.insert(record)
        do {
            try context.save()
            logger.info("Saved recording: \(record.title) (\(durationMs)ms)")
            tracker.finish()
        } catch {
            logger.error("Failed to save recording: \(error)")
            tracker.finish()
        }

        // Launch AI pipeline in background
        let videoID = record.id
        let audioPath = outputURL.path
        let container = self.modelContainer
        Task.detached {
            let orchestrator = AIOrchestrator()
            await orchestrator.runPipeline(
                videoRecordID: videoID,
                audioPath: audioPath,
                modelContainer: container
            )
        }

        NotificationService.post(
            title: "Recording Complete",
            body: record.title,
            categoryIdentifier: "RECORDING_COMPLETE"
        )
        state = .idle
    }
}
