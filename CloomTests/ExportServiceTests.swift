import Testing
import AVFoundation
@testable import Cloom

// MARK: - Task 157: Export Pipeline Tests

@Suite("ExportService.isExportUnmodified")
struct ExportUnmodifiedTests {

    private func defaultSnapshot(
        trimStartMs: Int64 = 0,
        trimEndMs: Int64 = 0,
        cuts: [CutRange] = [],
        stitchVideoIDs: [String] = [],
        speedMultiplier: Double = 1.0
    ) -> EDLSnapshot {
        EDLSnapshot(
            trimStartMs: trimStartMs,
            trimEndMs: trimEndMs,
            cuts: cuts,
            stitchVideoIDs: stitchVideoIDs,
            speedMultiplier: speedMultiplier
        )
    }

    @Test func fullyUnmodified() {
        let snapshot = defaultSnapshot()
        #expect(ExportService.isExportUnmodified(
            snapshot: snapshot, durationMs: 10000
        ) == true)
    }

    @Test func trimEndEqualsDuration() {
        let snapshot = defaultSnapshot(trimEndMs: 10000)
        #expect(ExportService.isExportUnmodified(
            snapshot: snapshot, durationMs: 10000
        ) == true)
    }

    @Test func trimEndExceedsDuration() {
        let snapshot = defaultSnapshot(trimEndMs: 15000)
        #expect(ExportService.isExportUnmodified(
            snapshot: snapshot, durationMs: 10000
        ) == true)
    }

    @Test func trimStartModified() {
        let snapshot = defaultSnapshot(trimStartMs: 1000)
        #expect(ExportService.isExportUnmodified(
            snapshot: snapshot, durationMs: 10000
        ) == false)
    }

    @Test func trimEndModified() {
        let snapshot = defaultSnapshot(trimEndMs: 5000)
        #expect(ExportService.isExportUnmodified(
            snapshot: snapshot, durationMs: 10000
        ) == false)
    }

    @Test func cutsPresent() {
        let snapshot = defaultSnapshot(cuts: [CutRange(startMs: 1000, endMs: 2000)])
        #expect(ExportService.isExportUnmodified(
            snapshot: snapshot, durationMs: 10000
        ) == false)
    }

    @Test func speedModified() {
        let snapshot = defaultSnapshot(speedMultiplier: 2.0)
        #expect(ExportService.isExportUnmodified(
            snapshot: snapshot, durationMs: 10000
        ) == false)
    }

    @Test func stitchPresent() {
        let snapshot = defaultSnapshot(stitchVideoIDs: ["video-2"])
        #expect(ExportService.isExportUnmodified(
            snapshot: snapshot, durationMs: 10000
        ) == false)
    }

    @Test func multipleModifications() {
        let snapshot = defaultSnapshot(trimStartMs: 500, speedMultiplier: 0.5)
        #expect(ExportService.isExportUnmodified(
            snapshot: snapshot, durationMs: 10000
        ) == false)
    }
}

@Suite("ExportService.presetForQuality")
struct PresetForQualityTests {

    @Test func lowQuality() {
        #expect(ExportService.presetForQuality(.low) == AVAssetExportPresetMediumQuality)
    }

    @Test func mediumQuality() {
        #expect(ExportService.presetForQuality(.medium) == AVAssetExportPreset1920x1080)
    }

    @Test func highQuality() {
        #expect(ExportService.presetForQuality(.high) == AVAssetExportPresetHighestQuality)
    }
}
