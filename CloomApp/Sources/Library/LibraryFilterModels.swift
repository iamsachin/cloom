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

// MARK: - Transcript Filter

enum TranscriptFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case hasTranscript = "Has Transcript"
    case noTranscript = "No Transcript"

    var id: String { rawValue }
}
