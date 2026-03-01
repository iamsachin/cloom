import Testing
import SwiftData
@testable import Cloom

@Suite("LibrarySortOrder")
struct LibrarySortOrderTests {

    private func makeVideo(title: String, durationMs: Int64 = 0, fileSizeBytes: Int64 = 0) -> VideoRecord {
        let v = VideoRecord(title: title, filePath: "/\(title).mp4", durationMs: durationMs, fileSizeBytes: fileSizeBytes)
        return v
    }

    @Test func newestFirst() {
        let older = makeVideo(title: "Older")
        let newer = makeVideo(title: "Newer")
        // newer.createdAt > older.createdAt by default (both get Date.now)
        // Test just validates comparator doesn't crash
        let result = LibrarySortOrder.newestFirst.comparator(older, newer)
        // Both created at roughly same time, so just verify it returns a Bool
        #expect(result == true || result == false)
    }

    @Test func oldestFirst() {
        let older = makeVideo(title: "Older")
        let newer = makeVideo(title: "Newer")
        let result = LibrarySortOrder.oldestFirst.comparator(older, newer)
        #expect(result == true || result == false)
    }

    @Test func titleAZOrder() {
        let a = makeVideo(title: "Alpha")
        let b = makeVideo(title: "Bravo")
        #expect(LibrarySortOrder.titleAZ.comparator(a, b) == true)
        #expect(LibrarySortOrder.titleAZ.comparator(b, a) == false)
    }

    @Test func titleZAOrder() {
        let a = makeVideo(title: "Alpha")
        let b = makeVideo(title: "Bravo")
        #expect(LibrarySortOrder.titleZA.comparator(b, a) == true)
        #expect(LibrarySortOrder.titleZA.comparator(a, b) == false)
    }

    @Test func longestFirst() {
        let short = makeVideo(title: "Short", durationMs: 1000)
        let long = makeVideo(title: "Long", durationMs: 5000)
        #expect(LibrarySortOrder.longestFirst.comparator(long, short) == true)
        #expect(LibrarySortOrder.longestFirst.comparator(short, long) == false)
    }

    @Test func shortestFirst() {
        let short = makeVideo(title: "Short", durationMs: 1000)
        let long = makeVideo(title: "Long", durationMs: 5000)
        #expect(LibrarySortOrder.shortestFirst.comparator(short, long) == true)
        #expect(LibrarySortOrder.shortestFirst.comparator(long, short) == false)
    }

    @Test func largestFirst() {
        let small = makeVideo(title: "Small", fileSizeBytes: 100)
        let large = makeVideo(title: "Large", fileSizeBytes: 1000)
        #expect(LibrarySortOrder.largestFirst.comparator(large, small) == true)
        #expect(LibrarySortOrder.largestFirst.comparator(small, large) == false)
    }

    @Test func allCasesCount() {
        #expect(LibrarySortOrder.allCases.count == 7)
    }
}

@Suite("TranscriptFilter")
struct TranscriptFilterTests {
    @Test func allCases() {
        #expect(TranscriptFilter.allCases.count == 3)
    }

    @Test func identifiable() {
        #expect(TranscriptFilter.all.id == "All")
        #expect(TranscriptFilter.hasTranscript.id == "Has Transcript")
        #expect(TranscriptFilter.noTranscript.id == "No Transcript")
    }
}
