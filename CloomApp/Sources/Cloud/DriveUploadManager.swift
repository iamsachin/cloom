import Foundation
import SwiftData
import AppKit
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "DriveUploadManager")

@MainActor
@Observable
final class DriveUploadManager {
    static let shared = DriveUploadManager()

    private(set) var activeUploads: [String: Double] = [:]
    private let uploadService = DriveUploadService()

    private init() {}

    // MARK: - Queries

    func isUploading(_ videoID: String) -> Bool {
        activeUploads[videoID] != nil
    }

    func uploadProgress(_ videoID: String) -> Double {
        activeUploads[videoID] ?? 0
    }

    // MARK: - Upload

    /// Upload the raw recording file to Google Drive.
    func uploadVideo(videoRecord: VideoRecord, modelContext: ModelContext) async {
        await performUpload(
            filePath: videoRecord.filePath,
            cleanupAfter: false,
            videoRecord: videoRecord,
            modelContext: modelContext
        )
    }

    /// Upload an exported (processed) file to Google Drive, then delete the temp file.
    func uploadExportedFile(filePath: String, videoRecord: VideoRecord, modelContext: ModelContext) async {
        await performUpload(
            filePath: filePath,
            cleanupAfter: true,
            videoRecord: videoRecord,
            modelContext: modelContext
        )
    }

    // MARK: - Shared Upload Logic

    private func performUpload(
        filePath: String,
        cleanupAfter: Bool,
        videoRecord: VideoRecord,
        modelContext: ModelContext
    ) async {
        let videoID = videoRecord.id

        guard !isUploading(videoID) else {
            logger.warning("Upload already in progress for \(videoID)")
            return
        }

        guard let accessToken = await GoogleAuthService.shared.refreshTokenIfNeeded() else {
            videoRecord.uploadStatus = UploadStatus.failed.rawValue
            try? modelContext.save()
            logger.error("No access token available for upload")
            return
        }

        defer {
            if cleanupAfter {
                try? FileManager.default.removeItem(atPath: filePath)
                logger.debug("Cleaned up temp file: \(filePath)")
            }
        }

        // Mark as uploading
        videoRecord.uploadStatus = UploadStatus.uploading.rawValue
        try? modelContext.save()
        activeUploads[videoID] = 0

        do {
            let title = videoRecord.title + ".mp4"

            let result = try await uploadService.upload(
                filePath: filePath,
                title: title,
                mimeType: "video/mp4",
                accessToken: accessToken,
                progress: { [weak self] fraction in
                    Task { @MainActor in
                        self?.activeUploads[videoID] = fraction
                    }
                }
            )

            // Create share link
            let shareLink = try await uploadService.createShareLink(
                fileId: result.fileId,
                accessToken: accessToken
            )

            // Persist success
            videoRecord.driveFileId = result.fileId
            videoRecord.shareUrl = shareLink
            videoRecord.uploadStatus = UploadStatus.uploaded.rawValue
            videoRecord.uploadedAt = .now
            try? modelContext.save()

            activeUploads.removeValue(forKey: videoID)

            // Copy to clipboard
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(shareLink, forType: .string)

            logger.info("Upload complete for \(videoID): \(shareLink)")
        } catch {
            videoRecord.uploadStatus = UploadStatus.failed.rawValue
            try? modelContext.save()
            activeUploads.removeValue(forKey: videoID)
            logger.error("Upload failed for \(videoID): \(error.localizedDescription)")
        }
    }

    // MARK: - Re-upload

    func reuploadVideo(videoRecord: VideoRecord, modelContext: ModelContext) async {
        // Delete old file if exists
        if let oldFileId = videoRecord.driveFileId,
           let token = await GoogleAuthService.shared.refreshTokenIfNeeded() {
            try? await uploadService.deleteFile(fileId: oldFileId, accessToken: token)
        }

        // Reset cloud fields
        videoRecord.driveFileId = nil
        videoRecord.shareUrl = nil
        videoRecord.uploadStatus = nil
        videoRecord.uploadedAt = nil
        try? modelContext.save()

        await uploadVideo(videoRecord: videoRecord, modelContext: modelContext)
    }
}
