import SwiftUI
import SwiftData
import AVFoundation
@preconcurrency import ScreenCaptureKit
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "RecordingCoordinator")

@MainActor
final class RecordingCoordinator: ObservableObject {
    @Published var state: RecordingState = .idle
    @Published var selectedMode: CaptureMode = .default
    @Published var micEnabled: Bool = false
    @Published var cameraEnabled: Bool = false
    @Published var blurEnabled: Bool = false

    private let modelContainer: ModelContainer
    private let captureService = ScreenCaptureService()
    private var countdownTimer: Timer?
    private var currentOutputURL: URL?

    private let countdownOverlay = CountdownOverlayWindow()
    private let recordingToolbar = RecordingToolbarPanel()
    private let regionSelector = RegionSelectionWindow()
    private let regionHighlight = RegionHighlightOverlay()

    private var cameraService: CameraService?
    private var webcamBubble: WebcamBubbleWindow?
    private var personSegmenter: PersonSegmenter?

    private var webcamRecorder: WebcamRecorder?
    private var currentWebcamURL: URL?

    private let systemPicker = SystemContentPicker()
    private var pendingFilter: SCContentFilter?

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        captureService.delegate = self
    }

    // MARK: - Public API

    func startRecording() {
        guard state.isIdle else { return }
        selectedMode = .default
        beginPreRecordingFlow()
    }

    func startRecordingWithPicker() {
        guard state.isIdle else { return }
        state = .selectingContent
        systemPicker.present(
            onFilterSelected: { [weak self] filter in
                Task { @MainActor [weak self] in
                    self?.pendingFilter = filter
                    self?.beginPreRecordingFlow()
                }
            },
            onCancelled: { [weak self] in
                Task { @MainActor [weak self] in
                    self?.state = .idle
                }
            }
        )
    }

    func selectMode(_ mode: CaptureMode) {
        pendingFilter = nil
        selectedMode = mode
        beginPreRecordingFlow()
    }

    func startRegionSelection() {
        regionSelector.show(
            onSelection: { [weak self] displayID, rect in
                Task { @MainActor [weak self] in
                    self?.selectMode(.region(displayID: displayID, rect: rect))
                }
            },
            onCancel: { [weak self] in
                Task { @MainActor [weak self] in
                    self?.state = .idle
                }
            }
        )
    }

    func cancelContentSelection() {
        state = .idle
    }

    func stopRecording() {
        guard state.isRecording else { return }

        state = .stopping
        recordingToolbar.dismiss()
        regionHighlight.dismiss()

        Task {
            stopWebcam()
            webcamRecorder?.stop()

            do {
                try await captureService.stopCapture()
            } catch {
                logger.error("Failed to stop capture: \(error)")
            }

            if let url = currentOutputURL {
                await handleRecordingFinished(outputURL: url, webcamURL: currentWebcamURL)
            } else {
                state = .idle
            }
        }
    }

    func toggleMic() {
        micEnabled.toggle()
        guard state.isRecording else { return }
        Task {
            do {
                try await captureService.updateConfiguration(micEnabled: micEnabled)
            } catch {
                logger.error("Failed to toggle mic: \(error)")
            }
        }
    }

    func toggleCamera() {
        cameraEnabled.toggle()
        if cameraEnabled {
            startWebcam()
        } else {
            stopWebcam()
        }
    }

    func toggleBlur() {
        blurEnabled.toggle()
        personSegmenter?.isEnabled = blurEnabled
    }

    // MARK: - Pre-recording flow

    private func beginPreRecordingFlow() {
        // When using the system picker, we already have a filter — skip permission check
        if pendingFilter == nil {
            Task {
                do {
                    _ = try await SCShareableContent.current
                } catch {
                    logger.info("Screen capture permission not yet granted — waiting for user")
                    state = .idle
                    return
                }
                state = .countdown(3)
                showCountdownOverlay(count: 3)
                startCountdownTimer()
            }
        } else {
            state = .countdown(3)
            showCountdownOverlay(count: 3)
            startCountdownTimer()
        }
    }

    // MARK: - Countdown

    private func showCountdownOverlay(count: Int) {
        switch selectedMode {
        case .region(_, let rect):
            // For region mode, overlay only the selected region area
            countdownOverlay.show(count: count, region: rect)
        default:
            countdownOverlay.show(count: count)
        }
    }

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
            showCountdownOverlay(count: next)
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

        if cameraEnabled {
            let webcamFilename = "Cloom Webcam \(timestamp).mp4"
            let webcamURL = desktopURL.appendingPathComponent(webcamFilename)
            self.currentWebcamURL = webcamURL
        } else {
            self.currentWebcamURL = nil
        }

        Task {
            do {
                if let filter = pendingFilter {
                    try await captureService.startCapture(
                        outputURL: outputURL,
                        filter: filter,
                        micEnabled: micEnabled
                    )
                    pendingFilter = nil
                } else {
                    try await captureService.startCapture(
                        outputURL: outputURL,
                        mode: selectedMode,
                        micEnabled: micEnabled
                    )
                }
            } catch {
                logger.error("Failed to start capture: \(error)")
                state = .idle
                showCaptureFailedAlert(error: error)
            }
        }
    }

    // MARK: - Webcam

    private func startWebcam() {
        if cameraService == nil {
            cameraService = CameraService()
        }
        if blurEnabled && personSegmenter == nil {
            personSegmenter = PersonSegmenter()
            personSegmenter?.isEnabled = true
        }
        if webcamBubble == nil {
            webcamBubble = WebcamBubbleWindow()
        }

        cameraService?.onFrame = { [weak self] pixelBuffer, ciImage in
            guard let self else { return }
            Task { @MainActor in
                self.handleCameraFrame(ciImage, pixelBuffer: pixelBuffer)
            }
        }
        cameraService?.start()
        webcamBubble?.show()
    }

    private func stopWebcam() {
        cameraService?.stop()
        webcamBubble?.dismiss()
    }

    private func handleCameraFrame(_ image: CIImage, pixelBuffer: CVPixelBuffer) {
        var displayImage = image

        if blurEnabled, let segmenter = personSegmenter {
            displayImage = segmenter.process(image: displayImage, pixelBuffer: pixelBuffer)
        }

        webcamBubble?.updateFrame(displayImage)
        webcamRecorder?.appendFrame(pixelBuffer)
    }

    // MARK: - Alerts

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

    private func handleRecordingFinished(outputURL: URL, webcamURL: URL?) async {
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

        let recordingType: String
        if webcamURL != nil {
            recordingType = "screenAndWebcam"
        } else {
            recordingType = "screenOnly"
        }

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
            webcamFilePath: webcamURL?.path
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

        if case .region(_, let rect) = selectedMode {
            regionHighlight.show(region: rect)
        }

        if cameraEnabled, let webcamURL = currentWebcamURL {
            let recorder = WebcamRecorder()
            do {
                try recorder.start(outputURL: webcamURL, width: 1280, height: 720)
                self.webcamRecorder = recorder
            } catch {
                logger.error("Failed to start webcam recording: \(error)")
            }
        }

        recordingToolbar.show(
            startedAt: now,
            micEnabled: micEnabled,
            cameraEnabled: cameraEnabled,
            onStop: { [weak self] in self?.stopRecording() },
            onToggleMic: { [weak self] in self?.toggleMic() },
            onToggleCamera: { [weak self] in self?.toggleCamera() }
        )
    }

    func captureDidFail(error: Error) {
        logger.error("Recording failed: \(error)")
        recordingToolbar.dismiss()
        regionHighlight.dismiss()
        stopWebcam()
        state = .idle
    }
}
