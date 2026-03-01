import Testing
@testable import Cloom

// MARK: - Task 165: AIProcessingTracker Tests

@Suite("AIProcessingTracker")
struct AIProcessingTrackerTests {

    @Test @MainActor func startProcessing() {
        let tracker = AIProcessingTracker()
        tracker.startProcessing("video-1")
        #expect(tracker.isProcessing("video-1") == true)
    }

    @Test @MainActor func stopProcessing() {
        let tracker = AIProcessingTracker()
        tracker.startProcessing("video-1")
        tracker.stopProcessing("video-1")
        #expect(tracker.isProcessing("video-1") == false)
    }

    @Test @MainActor func isProcessingUnknownID() {
        let tracker = AIProcessingTracker()
        #expect(tracker.isProcessing("nonexistent") == false)
    }

    @Test @MainActor func multipleVideosIndependent() {
        let tracker = AIProcessingTracker()
        tracker.startProcessing("video-1")
        tracker.startProcessing("video-2")
        #expect(tracker.isProcessing("video-1") == true)
        #expect(tracker.isProcessing("video-2") == true)

        tracker.stopProcessing("video-1")
        #expect(tracker.isProcessing("video-1") == false)
        #expect(tracker.isProcessing("video-2") == true)
    }

    @Test @MainActor func doubleStartIdempotent() {
        let tracker = AIProcessingTracker()
        tracker.startProcessing("video-1")
        tracker.startProcessing("video-1") // no-op
        #expect(tracker.isProcessing("video-1") == true)
    }

    @Test @MainActor func doubleStopIdempotent() {
        let tracker = AIProcessingTracker()
        tracker.startProcessing("video-1")
        tracker.stopProcessing("video-1")
        tracker.stopProcessing("video-1") // no-op
        #expect(tracker.isProcessing("video-1") == false)
    }

    @Test @MainActor func stopWithoutStartSafe() {
        let tracker = AIProcessingTracker()
        tracker.stopProcessing("video-1") // shouldn't crash
        #expect(tracker.isProcessing("video-1") == false)
    }
}
