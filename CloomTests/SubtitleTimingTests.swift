import Testing
@testable import Cloom

// MARK: - Task 158: Subtitle Timing Tests

@Suite("SubtitleExportService.mapToCompositionTime")
struct MapToCompositionTimeTests {

    @Test func simpleOffset() {
        // sourceMs=3000, trimStart=1000 → offset=2000
        let result = SubtitleExportService.mapToCompositionTime(
            sourceMs: 3000, trimStart: 1000, cuts: [], speed: 1.0
        )
        #expect(result == 2000)
    }

    @Test func withSingleCut() {
        // source=5000, trim=0, cut 1000-2000 (1s cut before source)
        // offset = 5000 - 0 - (2000-1000) = 4000
        let cuts = [CutRange(startMs: 1000, endMs: 2000)]
        let result = SubtitleExportService.mapToCompositionTime(
            sourceMs: 5000, trimStart: 0, cuts: cuts, speed: 1.0
        )
        #expect(result == 4000)
    }

    @Test func withMultipleCuts() {
        // source=8000, trim=0, cuts: 1000-2000 (1s), 4000-5000 (1s) → offset = 8000 - 2000 = 6000
        let cuts = [
            CutRange(startMs: 1000, endMs: 2000),
            CutRange(startMs: 4000, endMs: 5000),
        ]
        let result = SubtitleExportService.mapToCompositionTime(
            sourceMs: 8000, trimStart: 0, cuts: cuts, speed: 1.0
        )
        #expect(result == 6000)
    }

    @Test func cutAfterSourceIgnored() {
        // Cut at 8000-9000 shouldn't affect source at 5000
        let cuts = [CutRange(startMs: 8000, endMs: 9000)]
        let result = SubtitleExportService.mapToCompositionTime(
            sourceMs: 5000, trimStart: 0, cuts: cuts, speed: 1.0
        )
        #expect(result == 5000)
    }

    @Test func withTrimAndCut() {
        // source=6000, trim=2000, cut 3000-4000
        // offset = 6000 - 2000 = 4000
        // cut 3000-4000 is before source, cutStart = max(3000, 2000) = 3000, effectiveEnd = min(4000, 6000) = 4000
        // offset -= 1000 → 3000
        let cuts = [CutRange(startMs: 3000, endMs: 4000)]
        let result = SubtitleExportService.mapToCompositionTime(
            sourceMs: 6000, trimStart: 2000, cuts: cuts, speed: 1.0
        )
        #expect(result == 3000)
    }

    @Test func withSpeed2x() {
        // source=4000, trim=0, no cuts → offset=4000 / 2.0 = 2000
        let result = SubtitleExportService.mapToCompositionTime(
            sourceMs: 4000, trimStart: 0, cuts: [], speed: 2.0
        )
        #expect(result == 2000)
    }

    @Test func withSpeedHalf() {
        // source=4000, trim=0, no cuts → offset=4000 / 0.5 = 8000
        let result = SubtitleExportService.mapToCompositionTime(
            sourceMs: 4000, trimStart: 0, cuts: [], speed: 0.5
        )
        #expect(result == 8000)
    }

    @Test func speedWithCutsAndTrim() {
        // source=6000, trim=1000, cut 2000-3000 (1s), speed=2x
        // offset = 6000 - 1000 = 5000
        // cut: cutStart=max(2000,1000)=2000, effectiveEnd=min(3000,6000)=3000 → subtract 1000
        // offset = 4000 / 2.0 = 2000
        let cuts = [CutRange(startMs: 2000, endMs: 3000)]
        let result = SubtitleExportService.mapToCompositionTime(
            sourceMs: 6000, trimStart: 1000, cuts: cuts, speed: 2.0
        )
        #expect(result == 2000)
    }

    @Test func neverNegative() {
        // source at trim start → offset = 0
        let result = SubtitleExportService.mapToCompositionTime(
            sourceMs: 1000, trimStart: 1000, cuts: [], speed: 1.0
        )
        #expect(result == 0)
    }

    @Test func sourceBeforeTrimClampsToZero() {
        // source before trim → negative → clamped to 0
        let result = SubtitleExportService.mapToCompositionTime(
            sourceMs: 500, trimStart: 1000, cuts: [], speed: 1.0
        )
        #expect(result == 0)
    }

    @Test func cutPartiallyOverlappingSource() {
        // source=3000, cut 2000-5000 → effectiveEnd = min(5000, 3000) = 3000
        // offset = 3000 - 0 - (3000-2000) = 2000
        let cuts = [CutRange(startMs: 2000, endMs: 5000)]
        let result = SubtitleExportService.mapToCompositionTime(
            sourceMs: 3000, trimStart: 0, cuts: cuts, speed: 1.0
        )
        #expect(result == 2000)
    }
}
