import Foundation
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "PendingUploadStore")

/// Persists in-progress Google Drive uploads so they can resume after app quit.
/// Google's resumable upload session URIs are valid for ~1 week.
enum PendingUploadStore {

    struct PendingUpload: Codable {
        let videoID: String
        let filePath: String
        let title: String
        let sessionURI: String
        let totalBytes: Int64
        let startedAt: Date
    }

    private static let storeURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Cloom", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("pending_uploads.json")
    }()

    static func save(_ upload: PendingUpload) {
        var uploads = loadAll()
        uploads.removeAll { $0.videoID == upload.videoID }
        uploads.append(upload)
        write(uploads)
    }

    static func remove(videoID: String) {
        var uploads = loadAll()
        uploads.removeAll { $0.videoID == videoID }
        write(uploads)
    }

    static func loadAll() -> [PendingUpload] {
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: storeURL)
            let uploads = try JSONDecoder().decode([PendingUpload].self, from: data)
            // Filter out uploads older than 6 days (session URIs expire after ~1 week)
            let cutoff = Date.now.addingTimeInterval(-6 * 24 * 3600)
            return uploads.filter { $0.startedAt > cutoff }
        } catch {
            logger.error("Failed to load pending uploads: \(error)")
            return []
        }
    }

    private static func write(_ uploads: [PendingUpload]) {
        do {
            let data = try JSONEncoder().encode(uploads)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            logger.error("Failed to save pending uploads: \(error)")
        }
    }
}
