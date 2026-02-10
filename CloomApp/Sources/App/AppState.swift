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
    @Published var showContentPicker: Bool = false

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
    }

    // MARK: - Recording actions

    func startRecording() {
        recordingCoordinator.startRecording()
    }

    func startRecordingWithPicker() {
        recordingCoordinator.startRecordingWithPicker()
        showContentPicker = true
    }

    func stopRecording() {
        recordingCoordinator.stopRecording()
    }

    func selectMode(_ mode: CaptureMode) {
        showContentPicker = false
        recordingCoordinator.selectMode(mode)
    }

    func startRegionSelection() {
        showContentPicker = false
        recordingCoordinator.startRegionSelection()
    }

    func cancelContentSelection() {
        showContentPicker = false
        recordingCoordinator.cancelContentSelection()
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
