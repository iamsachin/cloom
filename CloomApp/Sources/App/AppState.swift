import SwiftUI
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "AppState")

@MainActor
final class AppState: ObservableObject {
    let modelContainer: ModelContainer

    /// Greeting from Rust FFI — verifies the bridge works.
    @Published var rustGreeting: String
    @Published var rustVersion: String

    init() {
        // Initialize SwiftData container
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

        // Verify Rust FFI round-trip
        self.rustGreeting = helloFromRust(name: "Cloom")
        self.rustVersion = cloomCoreVersion()

        logger.info("SwiftData container initialized")
        logger.info("\(self.rustGreeting)")
        logger.info("cloom-core version: \(self.rustVersion)")
    }
}
