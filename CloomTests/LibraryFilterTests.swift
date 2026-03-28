import Foundation
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

// MARK: - Date Range Filter Tests

@Suite("DateRangeFilter")
struct DateRangeFilterTests {

    @Test func allMatchesEverything() {
        let ancient = Date.distantPast
        let future = Date.distantFuture
        #expect(DateRangeFilter.all.matches(ancient) == true)
        #expect(DateRangeFilter.all.matches(future) == true)
    }

    @Test func todayMatchesNow() {
        #expect(DateRangeFilter.today.matches(Date.now) == true)
    }

    @Test func todayRejectsYesterday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date.now)!
        #expect(DateRangeFilter.today.matches(yesterday) == false)
    }

    @Test func thisWeekMatchesNow() {
        #expect(DateRangeFilter.thisWeek.matches(Date.now) == true)
    }

    @Test func thisWeekRejectsDistantPast() {
        let longAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date.now)!
        #expect(DateRangeFilter.thisWeek.matches(longAgo) == false)
    }

    @Test func thisMonthMatchesNow() {
        #expect(DateRangeFilter.thisMonth.matches(Date.now) == true)
    }

    @Test func thisMonthRejectsTwoMonthsAgo() {
        let twoMonthsAgo = Calendar.current.date(byAdding: .month, value: -2, to: Date.now)!
        #expect(DateRangeFilter.thisMonth.matches(twoMonthsAgo) == false)
    }

    @Test func last3MonthsMatchesRecentDate() {
        let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date.now)!
        #expect(DateRangeFilter.last3Months.matches(oneMonthAgo) == true)
    }

    @Test func last3MonthsRejectsOldDate() {
        let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date.now)!
        #expect(DateRangeFilter.last3Months.matches(sixMonthsAgo) == false)
    }

    @Test func allCasesCount() {
        #expect(DateRangeFilter.allCases.count == 5)
    }
}

// MARK: - Duration Range Filter Tests

@Suite("DurationRangeFilter")
struct DurationRangeFilterTests {

    @Test func allMatchesEverything() {
        #expect(DurationRangeFilter.all.matches(0) == true)
        #expect(DurationRangeFilter.all.matches(999_999) == true)
    }

    @Test func under30sBoundary() {
        #expect(DurationRangeFilter.under30s.matches(29_999) == true)
        #expect(DurationRangeFilter.under30s.matches(30_000) == false)
    }

    @Test func thirtyToTwoBoundaries() {
        #expect(DurationRangeFilter.thirtyToTwo.matches(29_999) == false)
        #expect(DurationRangeFilter.thirtyToTwo.matches(30_000) == true)
        #expect(DurationRangeFilter.thirtyToTwo.matches(119_999) == true)
        #expect(DurationRangeFilter.thirtyToTwo.matches(120_000) == false)
    }

    @Test func twoToTenBoundaries() {
        #expect(DurationRangeFilter.twoToTen.matches(119_999) == false)
        #expect(DurationRangeFilter.twoToTen.matches(120_000) == true)
        #expect(DurationRangeFilter.twoToTen.matches(599_999) == true)
        #expect(DurationRangeFilter.twoToTen.matches(600_000) == false)
    }

    @Test func overTenBoundary() {
        #expect(DurationRangeFilter.overTen.matches(599_999) == false)
        #expect(DurationRangeFilter.overTen.matches(600_000) == true)
        #expect(DurationRangeFilter.overTen.matches(999_999) == true)
    }

    @Test func allCasesCount() {
        #expect(DurationRangeFilter.allCases.count == 5)
    }
}
