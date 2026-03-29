import Foundation
import Testing
@testable import Cloom

@Suite("Blur Region Model")
struct BlurRegionModelTests {

    // MARK: - BlurRegion Struct

    @Test func blurRegionDefaultStyle() {
        let region = BlurRegion(
            startMs: 0, endMs: 5000,
            x: 0.1, y: 0.2, width: 0.3, height: 0.4
        )
        #expect(region.style == .gaussian)
        #expect(region.startMs == 0)
        #expect(region.endMs == 5000)
    }

    @Test func blurRegionEquality() {
        let a = BlurRegion(id: "test", startMs: 0, endMs: 1000, x: 0.1, y: 0.2, width: 0.3, height: 0.4)
        let b = BlurRegion(id: "test", startMs: 0, endMs: 1000, x: 0.1, y: 0.2, width: 0.3, height: 0.4)
        #expect(a == b)
    }

    @Test func blurRegionInequality() {
        let a = BlurRegion(id: "a", startMs: 0, endMs: 1000, x: 0.1, y: 0.2, width: 0.3, height: 0.4)
        let b = BlurRegion(id: "b", startMs: 0, endMs: 1000, x: 0.1, y: 0.2, width: 0.3, height: 0.4)
        #expect(a != b)
    }

    // MARK: - BlurStyle

    @Test func blurStyleRawValues() {
        #expect(BlurStyle.gaussian.rawValue == "gaussian")
        #expect(BlurStyle.pixelate.rawValue == "pixelate")
        #expect(BlurStyle.blackBox.rawValue == "blackBox")
    }

    @Test func blurStyleDisplayNames() {
        #expect(BlurStyle.gaussian.displayName == "Gaussian Blur")
        #expect(BlurStyle.pixelate.displayName == "Pixelate")
        #expect(BlurStyle.blackBox.displayName == "Black Box")
    }

    @Test func blurStyleAllCases() {
        #expect(BlurStyle.allCases.count == 3)
    }

    // MARK: - JSON Serialization

    @Test func blurRegionRoundTripsViaJSON() throws {
        let region = BlurRegion(
            startMs: 1000, endMs: 5000,
            x: 0.25, y: 0.3, width: 0.5, height: 0.4,
            style: .pixelate
        )
        let data = try JSONEncoder().encode([region])
        let decoded = try JSONDecoder().decode([BlurRegion].self, from: data)
        #expect(decoded.count == 1)
        #expect(decoded[0].style == .pixelate)
        #expect(decoded[0].x == 0.25)
        #expect(decoded[0].width == 0.5)
    }

    @Test func emptyBlurRegionsJSON() throws {
        let data = try JSONEncoder().encode([BlurRegion]())
        let json = String(data: data, encoding: .utf8)
        #expect(json == "[]")
    }

    // MARK: - EDLSnapshot with BlurRegions

    @Test func edlSnapshotIncludesBlurRegions() {
        let snapshot = EDLSnapshot(
            blurRegions: [
                BlurRegion(startMs: 0, endMs: 1000, x: 0.1, y: 0.1, width: 0.2, height: 0.2),
            ]
        )
        #expect(snapshot.blurRegions.count == 1)
    }

    @Test func edlSnapshotDefaultsToEmptyBlurRegions() {
        let snapshot = EDLSnapshot()
        #expect(snapshot.blurRegions.isEmpty)
    }

    // MARK: - Export Unmodified Check

    @Test func exportUnmodifiedWithBlurRegionsReturnsFalse() {
        let snapshot = EDLSnapshot(
            blurRegions: [
                BlurRegion(startMs: 0, endMs: 1000, x: 0.1, y: 0.1, width: 0.2, height: 0.2),
            ]
        )
        let result = ExportService.isExportUnmodified(snapshot: snapshot, durationMs: 10000)
        #expect(result == false)
    }

    @Test func exportUnmodifiedWithNoBlurRegionsReturnsTrue() {
        let snapshot = EDLSnapshot()
        let result = ExportService.isExportUnmodified(snapshot: snapshot, durationMs: 10000)
        #expect(result == true)
    }
}
