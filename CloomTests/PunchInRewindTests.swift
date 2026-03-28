import Testing
import Foundation
@testable import Cloom

// MARK: - PunchInMarker Tests

@Suite("PunchInMarker")
struct PunchInMarkerTests {

    @Test func encodeDecode() throws {
        let marker = PunchInMarker(timestampMs: 5000)
        let data = try JSONEncoder().encode(marker)
        let decoded = try JSONDecoder().decode(PunchInMarker.self, from: data)
        #expect(decoded.timestampMs == 5000)
        #expect(decoded.id == marker.id)
    }

    @Test func encodeDecodeArray() throws {
        let markers = [
            PunchInMarker(timestampMs: 1000),
            PunchInMarker(timestampMs: 3500),
            PunchInMarker(timestampMs: 8000),
        ]
        let data = try JSONEncoder().encode(markers)
        let decoded = try JSONDecoder().decode([PunchInMarker].self, from: data)
        #expect(decoded.count == 3)
        #expect(decoded[0].timestampMs == 1000)
        #expect(decoded[1].timestampMs == 3500)
        #expect(decoded[2].timestampMs == 8000)
    }

    @Test func uniqueIDs() {
        let a = PunchInMarker(timestampMs: 100)
        let b = PunchInMarker(timestampMs: 100)
        #expect(a.id != b.id)
    }
}

// MARK: - RecordingSegment Tests

@Suite("RecordingSegment")
struct RecordingSegmentTests {

    @Test func creation() {
        let url = URL(fileURLWithPath: "/tmp/test.mp4")
        let segment = RecordingSegment(url: url, index: 0, duration: 10.5)
        #expect(segment.url == url)
        #expect(segment.index == 0)
        #expect(segment.duration == 10.5)
    }

    @Test func durationMutable() {
        let url = URL(fileURLWithPath: "/tmp/test.mp4")
        var segment = RecordingSegment(url: url, index: 1, duration: 0)
        segment.duration = 15.3
        #expect(segment.duration == 15.3)
    }
}

// MARK: - RecordingState Rewinding Tests

@Suite("RecordingState.rewinding")
struct RecordingStateRewindingTests {

    @Test func rewindingIsRewinding() {
        let state = RecordingState.rewinding(startedAt: .now, pausedAt: .now)
        #expect(state.isRewinding == true)
    }

    @Test func rewindingIsNotRecording() {
        let state = RecordingState.rewinding(startedAt: .now, pausedAt: .now)
        #expect(state.isRecording == false)
    }

    @Test func rewindingIsNotPaused() {
        let state = RecordingState.rewinding(startedAt: .now, pausedAt: .now)
        #expect(state.isPaused == false)
    }

    @Test func rewindingIsActiveOrPaused() {
        let state = RecordingState.rewinding(startedAt: .now, pausedAt: .now)
        #expect(state.isActiveOrPaused == true)
    }

    @Test func rewindingIsBusy() {
        let state = RecordingState.rewinding(startedAt: .now, pausedAt: .now)
        #expect(state.isBusy == true)
    }

    @Test func rewindingIsNotIdle() {
        let state = RecordingState.rewinding(startedAt: .now, pausedAt: .now)
        #expect(state.isIdle == false)
    }

    @Test func idleIsNotRewinding() {
        #expect(RecordingState.idle.isRewinding == false)
    }

    @Test func pausedIsNotRewinding() {
        #expect(RecordingState.paused(startedAt: .now, pausedAt: .now).isRewinding == false)
    }

    @Test func recordingIsNotRewinding() {
        #expect(RecordingState.recording(startedAt: .now).isRewinding == false)
    }
}
