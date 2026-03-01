import Testing
import AVFoundation
import CoreMedia
@testable import Cloom

// MARK: - Task 162: Editor Composition BuildTimeRanges Tests

@Suite("EditorCompositionBuilder.buildTimeRanges")
struct BuildTimeRangesTests {

    private func rangeMs(_ range: CMTimeRange) -> (start: Int64, duration: Int64) {
        let startMs = Int64(CMTimeGetSeconds(range.start) * 1000)
        let durationMs = Int64(CMTimeGetSeconds(range.duration) * 1000)
        return (startMs, durationMs)
    }

    @Test func noCutsFullRange() {
        let edl = EDLSnapshot(trimStartMs: 0, trimEndMs: 0)
        let ranges = EditorCompositionBuilder.buildTimeRanges(edl: edl, totalDurationMs: 10000)
        #expect(ranges.count == 1)
        let r = rangeMs(ranges[0])
        #expect(r.start == 0)
        #expect(r.duration == 10000)
    }

    @Test func trimStartOnly() {
        let edl = EDLSnapshot(trimStartMs: 2000, trimEndMs: 0)
        let ranges = EditorCompositionBuilder.buildTimeRanges(edl: edl, totalDurationMs: 10000)
        #expect(ranges.count == 1)
        let r = rangeMs(ranges[0])
        #expect(r.start == 2000)
        #expect(r.duration == 8000)
    }

    @Test func trimBothEnds() {
        let edl = EDLSnapshot(trimStartMs: 1000, trimEndMs: 8000)
        let ranges = EditorCompositionBuilder.buildTimeRanges(edl: edl, totalDurationMs: 10000)
        #expect(ranges.count == 1)
        let r = rangeMs(ranges[0])
        #expect(r.start == 1000)
        #expect(r.duration == 7000)
    }

    @Test func singleCutInMiddle() {
        let edl = EDLSnapshot(
            trimStartMs: 0,
            trimEndMs: 10000,
            cuts: [CutRange(startMs: 3000, endMs: 5000)]
        )
        let ranges = EditorCompositionBuilder.buildTimeRanges(edl: edl, totalDurationMs: 10000)
        #expect(ranges.count == 2)
        let r0 = rangeMs(ranges[0])
        let r1 = rangeMs(ranges[1])
        #expect(r0.start == 0)
        #expect(r0.duration == 3000)
        #expect(r1.start == 5000)
        #expect(r1.duration == 5000)
    }

    @Test func multipleCuts() {
        let edl = EDLSnapshot(
            trimStartMs: 0,
            trimEndMs: 10000,
            cuts: [
                CutRange(startMs: 1000, endMs: 2000),
                CutRange(startMs: 5000, endMs: 6000),
            ]
        )
        let ranges = EditorCompositionBuilder.buildTimeRanges(edl: edl, totalDurationMs: 10000)
        #expect(ranges.count == 3)
        #expect(rangeMs(ranges[0]).start == 0)
        #expect(rangeMs(ranges[0]).duration == 1000)
        #expect(rangeMs(ranges[1]).start == 2000)
        #expect(rangeMs(ranges[1]).duration == 3000)
        #expect(rangeMs(ranges[2]).start == 6000)
        #expect(rangeMs(ranges[2]).duration == 4000)
    }

    @Test func cutAtStart() {
        let edl = EDLSnapshot(
            trimStartMs: 0,
            trimEndMs: 10000,
            cuts: [CutRange(startMs: 0, endMs: 2000)]
        )
        let ranges = EditorCompositionBuilder.buildTimeRanges(edl: edl, totalDurationMs: 10000)
        #expect(ranges.count == 1)
        #expect(rangeMs(ranges[0]).start == 2000)
        #expect(rangeMs(ranges[0]).duration == 8000)
    }

    @Test func cutAtEnd() {
        let edl = EDLSnapshot(
            trimStartMs: 0,
            trimEndMs: 10000,
            cuts: [CutRange(startMs: 8000, endMs: 10000)]
        )
        let ranges = EditorCompositionBuilder.buildTimeRanges(edl: edl, totalDurationMs: 10000)
        #expect(ranges.count == 1)
        #expect(rangeMs(ranges[0]).start == 0)
        #expect(rangeMs(ranges[0]).duration == 8000)
    }

    @Test func cutOutsideTrimIgnored() {
        let edl = EDLSnapshot(
            trimStartMs: 2000,
            trimEndMs: 8000,
            cuts: [CutRange(startMs: 0, endMs: 1000)] // before trim
        )
        let ranges = EditorCompositionBuilder.buildTimeRanges(edl: edl, totalDurationMs: 10000)
        #expect(ranges.count == 1)
        #expect(rangeMs(ranges[0]).start == 2000)
        #expect(rangeMs(ranges[0]).duration == 6000)
    }

    @Test func cutClampedToTrim() {
        // Cut extends beyond trim → clamped
        let edl = EDLSnapshot(
            trimStartMs: 2000,
            trimEndMs: 8000,
            cuts: [CutRange(startMs: 5000, endMs: 9000)]
        )
        let ranges = EditorCompositionBuilder.buildTimeRanges(edl: edl, totalDurationMs: 10000)
        #expect(ranges.count == 1)
        #expect(rangeMs(ranges[0]).start == 2000)
        #expect(rangeMs(ranges[0]).duration == 3000)
    }

    @Test func unsortedCutsHandled() {
        // Cuts given in reverse order → should still work (internally sorted)
        let edl = EDLSnapshot(
            trimStartMs: 0,
            trimEndMs: 10000,
            cuts: [
                CutRange(startMs: 5000, endMs: 6000),
                CutRange(startMs: 1000, endMs: 2000),
            ]
        )
        let ranges = EditorCompositionBuilder.buildTimeRanges(edl: edl, totalDurationMs: 10000)
        #expect(ranges.count == 3)
    }

    @Test func trimEndZeroUsesTotalDuration() {
        let edl = EDLSnapshot(trimStartMs: 0, trimEndMs: 0)
        let ranges = EditorCompositionBuilder.buildTimeRanges(edl: edl, totalDurationMs: 5000)
        #expect(ranges.count == 1)
        #expect(rangeMs(ranges[0]).duration == 5000)
    }
}
