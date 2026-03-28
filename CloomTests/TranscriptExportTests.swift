import Testing
import Foundation
@testable import Cloom

// MARK: - Transcript Export Tests

@Suite("TranscriptExportService")
struct TranscriptExportTests {

    @Test("formatTimestamp formats correctly")
    func formatTimestamp() {
        #expect(TranscriptExportService.formatTimestamp(ms: 0) == "0:00")
        #expect(TranscriptExportService.formatTimestamp(ms: 5000) == "0:05")
        #expect(TranscriptExportService.formatTimestamp(ms: 65000) == "1:05")
        #expect(TranscriptExportService.formatTimestamp(ms: 3661000) == "61:01")
    }
}

// MARK: - PendingUploadStore Tests

@Suite("PendingUploadStore")
struct PendingUploadStoreTests {

    @Test("PendingUpload model encodes and decodes")
    func pendingUploadCodable() throws {
        let upload = PendingUploadStore.PendingUpload(
            videoID: "test-id",
            filePath: "/tmp/test.mp4",
            title: "Test Video",
            sessionURI: "https://example.com/session",
            totalBytes: 1024,
            startedAt: Date(timeIntervalSince1970: 1700000000)
        )

        let data = try JSONEncoder().encode(upload)
        let decoded = try JSONDecoder().decode(PendingUploadStore.PendingUpload.self, from: data)

        #expect(decoded.videoID == "test-id")
        #expect(decoded.filePath == "/tmp/test.mp4")
        #expect(decoded.title == "Test Video")
        #expect(decoded.sessionURI == "https://example.com/session")
        #expect(decoded.totalBytes == 1024)
    }

    @Test("PendingUpload array encodes and decodes")
    func pendingUploadArrayCodable() throws {
        let uploads = [
            PendingUploadStore.PendingUpload(
                videoID: "a", filePath: "/tmp/a.mp4", title: "A",
                sessionURI: "https://a.com", totalBytes: 100, startedAt: .now
            ),
            PendingUploadStore.PendingUpload(
                videoID: "b", filePath: "/tmp/b.mp4", title: "B",
                sessionURI: "https://b.com", totalBytes: 200, startedAt: .now
            ),
        ]

        let data = try JSONEncoder().encode(uploads)
        let decoded = try JSONDecoder().decode([PendingUploadStore.PendingUpload].self, from: data)

        #expect(decoded.count == 2)
        #expect(decoded[0].videoID == "a")
        #expect(decoded[1].videoID == "b")
    }
}
