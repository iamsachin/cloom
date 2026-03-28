import Foundation

// MARK: - Sort Order

enum LibrarySortOrder: String, CaseIterable, Identifiable {
    case newestFirst = "Newest First"
    case oldestFirst = "Oldest First"
    case titleAZ = "Title (A-Z)"
    case titleZA = "Title (Z-A)"
    case longestFirst = "Longest First"
    case shortestFirst = "Shortest First"
    case largestFirst = "Largest First"

    var id: String { rawValue }

    func comparator(_ a: VideoRecord, _ b: VideoRecord) -> Bool {
        switch self {
        case .newestFirst: return a.createdAt > b.createdAt
        case .oldestFirst: return a.createdAt < b.createdAt
        case .titleAZ: return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        case .titleZA: return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedDescending
        case .longestFirst: return a.durationMs > b.durationMs
        case .shortestFirst: return a.durationMs < b.durationMs
        case .largestFirst: return a.fileSizeBytes > b.fileSizeBytes
        }
    }
}

// MARK: - Date Range Filter

enum DateRangeFilter: String, CaseIterable, Identifiable {
    case all = "All Dates"
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case last3Months = "Last 3 Months"

    var id: String { rawValue }

    func matches(_ date: Date) -> Bool {
        switch self {
        case .all:
            return true
        case .today:
            return Calendar.current.isDateInToday(date)
        case .thisWeek:
            return Calendar.current.isDate(date, equalTo: Date.now, toGranularity: .weekOfYear)
        case .thisMonth:
            return Calendar.current.isDate(date, equalTo: Date.now, toGranularity: .month)
        case .last3Months:
            guard let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date.now) else {
                return true
            }
            return date >= threeMonthsAgo
        }
    }
}

// MARK: - Duration Range Filter

enum DurationRangeFilter: String, CaseIterable, Identifiable {
    case all = "All Durations"
    case under30s = "Under 30s"
    case thirtyToTwo = "30s – 2m"
    case twoToTen = "2m – 10m"
    case overTen = "Over 10m"

    var id: String { rawValue }

    func matches(_ durationMs: Int64) -> Bool {
        switch self {
        case .all:
            return true
        case .under30s:
            return durationMs < 30_000
        case .thirtyToTwo:
            return durationMs >= 30_000 && durationMs < 120_000
        case .twoToTen:
            return durationMs >= 120_000 && durationMs < 600_000
        case .overTen:
            return durationMs >= 600_000
        }
    }
}

// MARK: - Transcript Filter

enum TranscriptFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case hasTranscript = "Has Transcript"
    case noTranscript = "No Transcript"

    var id: String { rawValue }
}
