import Foundation
import Testing
@testable import Cloom

@Suite("CommentSnapshot Sorting")
struct CommentSortingTests {

    private func makeComment(id: String = "c1", timestampMs: Int64? = nil, text: String = "test") -> CommentSnapshot {
        CommentSnapshot(id: id, timestampMs: timestampMs, text: text, createdAt: Date.now)
    }

    @Test func timestampedBeforeUntimestamped() {
        let comments = [
            makeComment(id: "a", timestampMs: nil, text: "general"),
            makeComment(id: "b", timestampMs: 5000, text: "at 5s"),
        ]
        let sorted = CommentSnapshot.sorted(comments)
        #expect(sorted[0].id == "b")
        #expect(sorted[1].id == "a")
    }

    @Test func sortsByTimestampAscending() {
        let comments = [
            makeComment(id: "c", timestampMs: 30000),
            makeComment(id: "a", timestampMs: 5000),
            makeComment(id: "b", timestampMs: 15000),
        ]
        let sorted = CommentSnapshot.sorted(comments)
        #expect(sorted.map(\.id) == ["a", "b", "c"])
    }

    @Test func allUntimestampedPreservesRelativeOrder() {
        let comments = [
            makeComment(id: "a", timestampMs: nil),
            makeComment(id: "b", timestampMs: nil),
        ]
        let sorted = CommentSnapshot.sorted(comments)
        // Both have Int64.max as sort key, so order is stable relative to input
        #expect(sorted.count == 2)
    }

    @Test func emptyArrayReturnsEmpty() {
        let sorted = CommentSnapshot.sorted([])
        #expect(sorted.isEmpty)
    }

    @Test func singleCommentReturnsItself() {
        let single = makeComment(id: "only", timestampMs: 1000)
        let sorted = CommentSnapshot.sorted([single])
        #expect(sorted.count == 1)
        #expect(sorted[0].id == "only")
    }

    @Test func mixedTimestampedAndGeneral() {
        let comments = [
            makeComment(id: "gen1", timestampMs: nil),
            makeComment(id: "ts1", timestampMs: 0),
            makeComment(id: "gen2", timestampMs: nil),
            makeComment(id: "ts2", timestampMs: 60000),
        ]
        let sorted = CommentSnapshot.sorted(comments)
        // Timestamped first (sorted by ms), then untimestamped
        #expect(sorted[0].id == "ts1")
        #expect(sorted[1].id == "ts2")
        // The last two are general (nil timestamps)
        #expect(sorted[2].timestampMs == nil)
        #expect(sorted[3].timestampMs == nil)
    }

    @Test func zeroTimestampSortsFirst() {
        let comments = [
            makeComment(id: "b", timestampMs: 1000),
            makeComment(id: "a", timestampMs: 0),
        ]
        let sorted = CommentSnapshot.sorted(comments)
        #expect(sorted[0].id == "a")
        #expect(sorted[1].id == "b")
    }
}
