import SwiftUI
import SwiftData
import AVFoundation
@preconcurrency import ScreenCaptureKit
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "RecordingCoordinator")

@MainActor
final class RecordingCoordinator: ObservableObject {
    @Published var state: RecordingState = .idle

    private let modelContainer: ModelContainer
    private let captureService = ScreenCaptureService()
    private var countdownTimer: Timer?
    private var currentOutputURL: URL?

    private let countdownOverlay = CountdownOverlayWindow()
    private let recordingToolbar = RecordingToolbarPanel()

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        captureService.delegate = self
    }

    // MARK: - Public API

    func startRecording() {
        guard state.isIdle else { return }

        Task {
            do {
                _ = try await SCShareableContent.current
            } catch {
                logger.error("Permission check failed: \(error)")
                showCaptureFailedAlert(error: error)
                return
            }
            state = .countdown(3)
            countdownOverlay.show(count: 3)
            startCountdownTimer()
        }
    }

    func stopRecording() {
        guard state.isRecording else { return }

        state = .stopping
        recordingToolbar.dismiss()

        Task {
            do {
                try await captureService.stopCapture()
            } catch {
                logger.error("Failed to stop capture: \(error)")
            }
            if let url = currentOutputURL {
                await handleRecordingFinished(outputURL: url)
            } else {
                state = .idle
            }
        }
    }

    // MARK: - Countdown

    private func startCountdownTimer() {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tickCountdown()
            }
        }
    }

    private func tickCountdown() {
        guard case .countdown(let remaining) = state else {
            countdownTimer?.invalidate()
            countdownTimer = nil
            return
        }

        let next = remaining - 1
        if next > 0 {
            state = .countdown(next)
            countdownOverlay.show(count: next)
        } else {
            countdownTimer?.invalidate()
            countdownTimer = nil
            countdownOverlay.dismiss()
            beginCapture()
        }
    }

    // MARK: - Capture

    private func beginCapture() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "Cloom Recording \(timestamp).mp4"

        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let outputURL = desktopURL.appendingPathComponent(filename)
        self.currentOutputURL = outputURL

        Task {
            do {
                try await captureService.startCapture(outputURL: outputURL)
            } catch {
                logger.error("Failed to start capture: \(error)")
                state = .idle
                showCaptureFailedAlert(error: error)
            }
        }
    }

    private func showCaptureFailedAlert(error: Error) {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Failed"
        alert.informativeText = "\(error.localizedDescription)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "OK")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
        }
    }

    // MARK: - Post-Recording

    private func handleRecordingFinished(outputURL: URL) async {
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

        let thumbnailPath = await ThumbnailGenerator.generateThumbnail(for: outputURL) ?? ""

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
            recordingType: "screenOnly"
        )
        context.insert(record)
        do {
            try context.save()
            logger.info("Saved recording: \(record.title) (\(durationMs)ms)")
        } catch {
            logger.error("Failed to save recording: \(error)")
        }

        state = .idle
    }
}

// MARK: - CaptureServiceDelegate

extension RecordingCoordinator: CaptureServiceDelegate {
    func captureDidStart() {
        let now = Date()
        state = .recording(startedAt: now)
        recordingToolbar.show(startedAt: now) { [weak self] in
            self?.stopRecording()
        }
    }

    func captureDidFail(error: Error) {
        logger.error("Recording failed: \(error)")
        recordingToolbar.dismiss()
        state = .idle
    }
}
