import Foundation
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "DriveUpload")

actor DriveUploadService {
    enum UploadError: LocalizedError {
        case notAuthenticated
        case fileNotFound
        case initiationFailed(Int)
        case uploadFailed(String)
        case sharingFailed(String)

        var errorDescription: String? {
            switch self {
            case .notAuthenticated: "Not authenticated with Google"
            case .fileNotFound: "Video file not found"
            case .initiationFailed(let code): "Upload initiation failed (HTTP \(code))"
            case .uploadFailed(let msg): "Upload failed: \(msg)"
            case .sharingFailed(let msg): "Sharing failed: \(msg)"
            }
        }
    }

    struct DriveFileResult: Sendable {
        let fileId: String
        let webViewLink: String?
    }

    private let chunkSize = 5 * 1024 * 1024 // 5 MB
    private let maxRetries = 3

    // MARK: - Upload

    func upload(
        filePath: String,
        title: String,
        mimeType: String,
        accessToken: String,
        progress: @escaping @Sendable (Double) -> Void,
        onSessionCreated: (@Sendable (URL, Int64) -> Void)? = nil
    ) async throws -> DriveFileResult {
        let fileURL = URL(fileURLWithPath: filePath)
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw UploadError.fileNotFound
        }

        let fileSize = try FileManager.default.attributesOfItem(atPath: filePath)[.size] as? Int64 ?? 0

        // 1. Initiate resumable upload
        let sessionURI = try await initiateUpload(
            title: title,
            mimeType: mimeType,
            fileSize: fileSize,
            accessToken: accessToken
        )

        // Notify caller of session URI for persistence
        onSessionCreated?(sessionURI, fileSize)

        // 2. Upload file in chunks
        let fileHandle = try FileHandle(forReadingFrom: fileURL)
        defer { try? fileHandle.close() }

        var offset: Int64 = 0

        while offset < fileSize {
            let remaining = fileSize - offset
            let currentChunkSize = min(Int64(chunkSize), remaining)

            fileHandle.seek(toFileOffset: UInt64(offset))
            let chunkData = fileHandle.readData(ofLength: Int(currentChunkSize))

            let (responseData, statusCode) = try await uploadChunk(
                sessionURI: sessionURI,
                data: chunkData,
                offset: offset,
                totalSize: fileSize
            )

            if statusCode == 200 || statusCode == 201 {
                // Upload complete
                progress(1.0)
                return try parseUploadResponse(responseData)
            } else if statusCode == 308 {
                // Chunk accepted, continue
                offset += currentChunkSize
                progress(Double(offset) / Double(fileSize))
            } else {
                throw UploadError.uploadFailed("Unexpected status \(statusCode)")
            }
        }

        throw UploadError.uploadFailed("Upload ended without completion response")
    }

    // MARK: - Share Link

    func createShareLink(fileId: String, accessToken: String) async throws -> String {
        // Set "anyone with link" permission
        let permURL = URL(string: "https://www.googleapis.com/drive/v3/files/\(fileId)/permissions")!
        var permReq = URLRequest(url: permURL)
        permReq.httpMethod = "POST"
        permReq.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        permReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        permReq.httpBody = try JSONSerialization.data(withJSONObject: [
            "role": "reader",
            "type": "anyone"
        ])

        let (_, permResp) = try await URLSession.shared.data(for: permReq)
        guard let httpResp = permResp as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) else {
            throw UploadError.sharingFailed("Failed to set permissions")
        }

        // Get webViewLink
        let fileURL = URL(string: "https://www.googleapis.com/drive/v3/files/\(fileId)?fields=webViewLink")!
        var fileReq = URLRequest(url: fileURL)
        fileReq.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, fileResp) = try await URLSession.shared.data(for: fileReq)
        guard let httpFileResp = fileResp as? HTTPURLResponse, httpFileResp.statusCode == 200 else {
            throw UploadError.sharingFailed("Failed to get share link")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let link = json?["webViewLink"] as? String else {
            throw UploadError.sharingFailed("No webViewLink in response")
        }

        return link
    }

    // MARK: - Delete

    func deleteFile(fileId: String, accessToken: String) async throws {
        let url = URL(string: "https://www.googleapis.com/drive/v3/files/\(fileId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResp = response as? HTTPURLResponse,
              httpResp.statusCode == 204 || httpResp.statusCode == 200 else {
            throw UploadError.uploadFailed("Delete failed")
        }
    }

    // MARK: - Resume Upload

    /// Resume a previously initiated resumable upload by querying how many bytes were received.
    func resumeUpload(
        sessionURI: URL,
        filePath: String,
        totalSize: Int64,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> DriveFileResult {
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw UploadError.fileNotFound
        }

        // Query Google for how much was already uploaded
        var request = URLRequest(url: sessionURI)
        request.httpMethod = "PUT"
        request.setValue("bytes */\(totalSize)", forHTTPHeaderField: "Content-Range")
        request.setValue("0", forHTTPHeaderField: "Content-Length")
        request.httpBody = Data()

        let (_, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        if statusCode == 200 || statusCode == 201 {
            // Already completed
            progress(1.0)
            let (data, _) = try await URLSession.shared.data(for: request)
            return try parseUploadResponse(data)
        }

        var resumeOffset: Int64 = 0
        if statusCode == 308,
           let rangeHeader = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Range"),
           let dashIndex = rangeHeader.firstIndex(of: "-"),
           let lastByte = Int64(rangeHeader[rangeHeader.index(after: dashIndex)...]) {
            resumeOffset = lastByte + 1
        }

        logger.info("Resuming upload from byte \(resumeOffset)/\(totalSize)")
        progress(Double(resumeOffset) / Double(totalSize))

        // Continue uploading from the resume offset
        let fileHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: filePath))
        defer { try? fileHandle.close() }

        var offset = resumeOffset
        while offset < totalSize {
            let remaining = totalSize - offset
            let currentChunkSize = min(Int64(chunkSize), remaining)

            fileHandle.seek(toFileOffset: UInt64(offset))
            let chunkData = fileHandle.readData(ofLength: Int(currentChunkSize))

            let (responseData, chunkStatus) = try await uploadChunk(
                sessionURI: sessionURI,
                data: chunkData,
                offset: offset,
                totalSize: totalSize
            )

            if chunkStatus == 200 || chunkStatus == 201 {
                progress(1.0)
                return try parseUploadResponse(responseData)
            } else if chunkStatus == 308 {
                offset += currentChunkSize
                progress(Double(offset) / Double(totalSize))
            } else {
                throw UploadError.uploadFailed("Unexpected status \(chunkStatus)")
            }
        }

        throw UploadError.uploadFailed("Resume ended without completion response")
    }

    // MARK: - Private

    private func initiateUpload(
        title: String,
        mimeType: String,
        fileSize: Int64,
        accessToken: String
    ) async throws -> URL {
        let url = URL(string: "https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("\(fileSize)", forHTTPHeaderField: "X-Upload-Content-Length")
        request.setValue(mimeType, forHTTPHeaderField: "X-Upload-Content-Type")

        let metadata: [String: Any] = ["name": title, "mimeType": mimeType]
        request.httpBody = try JSONSerialization.data(withJSONObject: metadata)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw UploadError.initiationFailed(code)
        }

        guard let location = httpResp.value(forHTTPHeaderField: "Location"),
              let sessionURI = URL(string: location) else {
            throw UploadError.initiationFailed(0)
        }

        return sessionURI
    }

    private func uploadChunk(
        sessionURI: URL,
        data: Data,
        offset: Int64,
        totalSize: Int64
    ) async throws -> (Data, Int) {
        let endByte = offset + Int64(data.count) - 1

        for attempt in 0..<maxRetries {
            var request = URLRequest(url: sessionURI)
            request.httpMethod = "PUT"
            request.setValue(
                "bytes \(offset)-\(endByte)/\(totalSize)",
                forHTTPHeaderField: "Content-Range"
            )
            request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
            request.httpBody = data

            do {
                let (responseData, response) = try await URLSession.shared.data(for: request)
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

                if statusCode == 429 || (500...599).contains(statusCode) {
                    let delay = Double(1 << attempt)
                    logger.warning("Chunk upload retry \(attempt + 1)/\(self.maxRetries) after \(delay)s (HTTP \(statusCode))")
                    try await Task.sleep(for: .seconds(delay))
                    continue
                }

                return (responseData, statusCode)
            } catch where attempt < maxRetries - 1 {
                let delay = Double(1 << attempt)
                logger.warning("Chunk upload network error, retry \(attempt + 1): \(error.localizedDescription)")
                try await Task.sleep(for: .seconds(delay))
            }
        }

        throw UploadError.uploadFailed("Max retries exceeded")
    }

    private func parseUploadResponse(_ data: Data) throws -> DriveFileResult {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let fileId = json?["id"] as? String else {
            throw UploadError.uploadFailed("No file ID in response")
        }
        let webViewLink = json?["webViewLink"] as? String
        return DriveFileResult(fileId: fileId, webViewLink: webViewLink)
    }
}
