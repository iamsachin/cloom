import Foundation
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "VideoLibraryService")

enum VideoLibraryService {
    /// Delete videos by ID — removes video file, thumbnail, webcam file, and SwiftData record.
    static func deleteVideos(ids: Set<String>, from videos: [VideoRecord], context: ModelContext) {
        for video in videos where ids.contains(video.id) {
            if !video.filePath.isEmpty {
                try? FileManager.default.removeItem(atPath: video.filePath)
            }
            if !video.thumbnailPath.isEmpty {
                try? FileManager.default.removeItem(atPath: video.thumbnailPath)
            }
            if let webcamPath = video.webcamFilePath, !webcamPath.isEmpty {
                try? FileManager.default.removeItem(atPath: webcamPath)
            }
            context.delete(video)
        }
        do { try context.save() } catch { logger.error("Failed to save after delete: \(error)") }
    }

    /// Move videos to a folder (or nil for root).
    static func moveVideos(ids: Set<String>, toFolder folder: FolderRecord?, from videos: [VideoRecord], context: ModelContext) {
        for video in videos where ids.contains(video.id) {
            video.folder = folder
        }
        do { try context.save() } catch { logger.error("Failed to save after move: \(error)") }
    }
}
