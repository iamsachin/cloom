import Foundation

@MainActor
@Observable
final class AIProcessingTracker {
    static let shared = AIProcessingTracker()

    private(set) var processingVideoIDs: Set<String> = []

    func startProcessing(_ videoID: String) {
        processingVideoIDs.insert(videoID)
    }

    func stopProcessing(_ videoID: String) {
        processingVideoIDs.remove(videoID)
    }

    func isProcessing(_ videoID: String) -> Bool {
        processingVideoIDs.contains(videoID)
    }
}
