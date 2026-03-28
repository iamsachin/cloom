import Foundation

struct PunchInMarker: Codable, Sendable, Identifiable {
    var id: String = UUID().uuidString
    var timestampMs: Int64
}
