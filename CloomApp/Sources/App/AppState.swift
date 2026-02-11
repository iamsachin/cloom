import SwiftUI
import SwiftData
import Combine
import AVFoundation
@preconcurrency import ScreenCaptureKit
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "AppState")

@MainActor
final class AppState: ObservableObject {
    let modelContainer: ModelContainer

    @Published var rustGreeting: String
    @Published var rustVersion: String

    @Published var recordingState: RecordingState = .idle
    @Published var micEnabled: Bool = false
    @Published var cameraEnabled: Bool = false
    @Published var blurEnabled: Bool = false
    // Content picker is now handled by system SCContentSharingPicker

    let recordingCoordinator: RecordingCoordinator

    init() {
        let schema = Schema([
            VideoRecord.self,
            FolderRecord.self,
            TagRecord.self,
            TranscriptRecord.self,
            TranscriptWordRecord.self,
            ChapterRecord.self,
            VideoComment.self,
            ViewEvent.self,
        ])
        let config = ModelConfiguration(
            "CloomStore",
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            self.modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to initialize SwiftData ModelContainer: \(error)")
        }

        self.recordingCoordinator = RecordingCoordinator(modelContainer: modelContainer)

        self.rustGreeting = helloFromRust(name: "Cloom")
        self.rustVersion = cloomCoreVersion()

        recordingCoordinator.$state.assign(to: &$recordingState)
        recordingCoordinator.$micEnabled.assign(to: &$micEnabled)
        recordingCoordinator.$cameraEnabled.assign(to: &$cameraEnabled)
        recordingCoordinator.$blurEnabled.assign(to: &$blurEnabled)

        logger.info("AppState initialized — \(self.rustGreeting), core v\(self.rustVersion)")

        requestPermissions()
    }

    // MARK: - Permissions

    private func requestPermissions() {
        Task {
            // Camera
            let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
            if cameraStatus == .notDetermined {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                logger.info("Camera permission: \(granted ? "granted" : "denied")")
            }

            // Microphone
            let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
            if micStatus == .notDetermined {
                let granted = await AVCaptureDevice.requestAccess(for: .audio)
                logger.info("Microphone permission: \(granted ? "granted" : "denied")")
            }

            // Screen Recording — requesting SCShareableContent triggers the prompt
            do {
                _ = try await SCShareableContent.current
                logger.info("Screen recording permission: granted")
            } catch {
                logger.info("Screen recording permission: not yet granted (\(error.localizedDescription))")
            }
        }
    }

    // MARK: - Recording actions

    func startRecording() {
        recordingCoordinator.startRecording()
    }

    func startRecordingWithPicker() {
        recordingCoordinator.startRecordingWithPicker()
    }

    func stopRecording() {
        recordingCoordinator.stopRecording()
    }

    func selectMode(_ mode: CaptureMode) {
        recordingCoordinator.selectMode(mode)
    }

    func startRegionSelection() {
        recordingCoordinator.startRegionSelection()
    }

    func cancelContentSelection() {
        recordingCoordinator.cancelContentSelection()
    }

    func pauseRecording() {
        recordingCoordinator.pauseRecording()
    }

    func resumeRecording() {
        recordingCoordinator.resumeRecording()
    }

    // MARK: - Toggle controls

    func toggleMic() {
        recordingCoordinator.toggleMic()
    }

    func toggleCamera() {
        recordingCoordinator.toggleCamera()
    }

    func toggleBlur() {
        recordingCoordinator.toggleBlur()
    }
}
