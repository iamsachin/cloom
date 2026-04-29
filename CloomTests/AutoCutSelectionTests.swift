import Testing
import Foundation
@testable import Cloom

@Suite("EditorState.filterSelectedRanges")
struct AutoCutSelectionTests {

    private func makeRanges(_ specs: [(Int64, Int64)]) -> [PreviewCutRange] {
        specs.map { PreviewCutRange(startMs: $0.0, endMs: $0.1) }
    }

    @Test func allSelectedReturnsAll() {
        let ranges = makeRanges([(0, 100), (200, 300), (500, 700)])
        let selected = Set(ranges.map(\.id))

        let result = EditorState.filterSelectedRanges(ranges, selectedIDs: selected)

        #expect(result.count == 3)
        #expect(result[0].startMs == 0 && result[0].endMs == 100)
        #expect(result[1].startMs == 200 && result[1].endMs == 300)
        #expect(result[2].startMs == 500 && result[2].endMs == 700)
    }

    @Test func noneSelectedReturnsEmpty() {
        let ranges = makeRanges([(0, 100), (200, 300)])

        let result = EditorState.filterSelectedRanges(ranges, selectedIDs: [])

        #expect(result.isEmpty)
    }

    @Test func partialSelectionReturnsOnlyMatching() {
        let ranges = makeRanges([(0, 100), (200, 300), (500, 700)])
        let selected: Set<UUID> = [ranges[0].id, ranges[2].id]

        let result = EditorState.filterSelectedRanges(ranges, selectedIDs: selected)

        #expect(result.count == 2)
        #expect(result[0].startMs == 0)
        #expect(result[1].startMs == 500)
    }

    @Test func emptyRangesReturnsEmpty() {
        let result = EditorState.filterSelectedRanges([], selectedIDs: [UUID()])
        #expect(result.isEmpty)
    }

    @Test func unknownIDsAreIgnored() {
        let ranges = makeRanges([(0, 100)])
        let stale: Set<UUID> = [UUID(), UUID()]

        let result = EditorState.filterSelectedRanges(ranges, selectedIDs: stale)

        #expect(result.isEmpty)
    }

    @Test func preservesInputOrder() {
        let ranges = makeRanges([(900, 1000), (100, 200), (500, 600)])
        let selected = Set(ranges.map(\.id))

        let result = EditorState.filterSelectedRanges(ranges, selectedIDs: selected)

        // filter preserves original order — sorting happens later in addCuts()
        #expect(result.map(\.startMs) == [900, 100, 500])
    }
}

@Suite("PreviewCutRange")
struct PreviewCutRangeTests {

    @Test func defaultIDIsUnique() {
        let a = PreviewCutRange(startMs: 0, endMs: 100)
        let b = PreviewCutRange(startMs: 0, endMs: 100)
        #expect(a.id != b.id)
    }

    @Test func explicitIDIsRespected() {
        let id = UUID()
        let range = PreviewCutRange(id: id, startMs: 50, endMs: 150)
        #expect(range.id == id)
    }
}
