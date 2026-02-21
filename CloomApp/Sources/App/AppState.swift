import SwiftUI
import SwiftData
import Combine
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
            EditDecisionList.self,
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

        cleanupOrphanedTempFiles()
        setupGlobalHotkeys()
    }

    // MARK: - Global Hotkeys

    private func setupGlobalHotkeys() {
        let mgr = GlobalHotkeyManager.shared
        mgr.onToggleRecording = { [weak self] in
            guard let self else { return }
            if self.recordingState.isIdle {
                self.startRecording()
            } else if self.recordingState.isActiveOrPaused {
                self.stopRecording()
            }
        }
        mgr.onTogglePause = { [weak self] in
            guard let self else { return }
            if self.recordingState.isRecording {
                self.pauseRecording()
            } else if self.recordingState.isPaused {
                self.resumeRecording()
            }
        }
        mgr.start()
    }

    // MARK: - Crash Recovery

    private func cleanupOrphanedTempFiles() {
        let tempDir = FileManager.default.temporaryDirectory
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: tempDir, includingPropertiesForKeys: nil
        ) else { return }

        let orphaned = contents.filter { url in
            let name = url.lastPathComponent
            return name.hasPrefix("cloom_segment_") || name.hasPrefix("cloom_audio_")
        }

        guard !orphaned.isEmpty else { return }

        for url in orphaned {
            try? FileManager.default.removeItem(at: url)
        }
        logger.info("Cleaned up \(orphaned.count) orphaned temp file(s)")
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
