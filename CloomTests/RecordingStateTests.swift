import Testing
import Foundation
@testable import Cloom

// MARK: - Task 161: RecordingState Tests

@Suite("RecordingState")
struct RecordingStateTests {

    // MARK: - isRecording

    @Test func idleIsNotRecording() {
        #expect(RecordingState.idle.isRecording == false)
    }

    @Test func recordingIsRecording() {
        #expect(RecordingState.recording(startedAt: .now).isRecording == true)
    }

    @Test func pausedIsNotRecording() {
        #expect(RecordingState.paused(startedAt: .now, pausedAt: .now).isRecording == false)
    }

    // MARK: - isPaused

    @Test func pausedIsPaused() {
        #expect(RecordingState.paused(startedAt: .now, pausedAt: .now).isPaused == true)
    }

    @Test func recordingIsNotPaused() {
        #expect(RecordingState.recording(startedAt: .now).isPaused == false)
    }

    @Test func idleIsNotPaused() {
        #expect(RecordingState.idle.isPaused == false)
    }

    // MARK: - isActiveOrPaused

    @Test func recordingIsActiveOrPaused() {
        #expect(RecordingState.recording(startedAt: .now).isActiveOrPaused == true)
    }

    @Test func pausedIsActiveOrPaused() {
        #expect(RecordingState.paused(startedAt: .now, pausedAt: .now).isActiveOrPaused == true)
    }

    @Test func idleIsNotActiveOrPaused() {
        #expect(RecordingState.idle.isActiveOrPaused == false)
    }

    @Test func countdownIsNotActiveOrPaused() {
        #expect(RecordingState.countdown(3).isActiveOrPaused == false)
    }

    // MARK: - isIdle

    @Test func idleIsIdle() {
        #expect(RecordingState.idle.isIdle == true)
    }

    @Test func recordingIsNotIdle() {
        #expect(RecordingState.recording(startedAt: .now).isIdle == false)
    }

    @Test func stoppingIsNotIdle() {
        #expect(RecordingState.stopping.isIdle == false)
    }

    // MARK: - isReady

    @Test func readyIsReady() {
        #expect(RecordingState.ready.isReady == true)
    }

    @Test func idleIsNotReady() {
        #expect(RecordingState.idle.isReady == false)
    }

    @Test func recordingIsNotReady() {
        #expect(RecordingState.recording(startedAt: .now).isReady == false)
    }

    // MARK: - isSelectingContent

    @Test func selectingContentIsSelectingContent() {
        #expect(RecordingState.selectingContent.isSelectingContent == true)
    }

    @Test func idleIsNotSelectingContent() {
        #expect(RecordingState.idle.isSelectingContent == false)
    }

    // MARK: - isBusy

    @Test func idleIsNotBusy() {
        #expect(RecordingState.idle.isBusy == false)
    }

    @Test func recordingIsBusy() {
        #expect(RecordingState.recording(startedAt: .now).isBusy == true)
    }

    @Test func readyIsBusy() {
        #expect(RecordingState.ready.isBusy == true)
    }

    @Test func countdownIsBusy() {
        #expect(RecordingState.countdown(3).isBusy == true)
    }

    @Test func pausedIsBusy() {
        #expect(RecordingState.paused(startedAt: .now, pausedAt: .now).isBusy == true)
    }

    @Test func stoppingIsBusy() {
        #expect(RecordingState.stopping.isBusy == true)
    }

    @Test func selectingContentIsBusy() {
        #expect(RecordingState.selectingContent.isBusy == true)
    }

    // MARK: - Equatable

    @Test func sameIdleEqual() {
        #expect(RecordingState.idle == RecordingState.idle)
    }

    @Test func differentStatesNotEqual() {
        #expect(RecordingState.idle != RecordingState.ready)
    }
}
