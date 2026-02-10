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

        logger.info("AppState initialized — \(self.rustGreeting), core v\(self.rustVersion)")
    }

    func startRecording() {
        recordingCoordinator.startRecording()
    }

    func stopRecording() {
        recordingCoordinator.stopRecording()
    }
}
