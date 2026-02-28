import Testing
@testable import Cloom

// MARK: - UploadStatus Tests

@Suite("UploadStatus")
struct UploadStatusTests {
    @Test func rawValueRoundTrip() {
        for status in UploadStatus.allCases {
            let raw = status.rawValue
            let restored = UploadStatus(rawValue: raw)
            #expect(restored == status)
        }
    }

    @Test func rawValues() {
        #expect(UploadStatus.uploading.rawValue == "uploading")
        #expect(UploadStatus.uploaded.rawValue == "uploaded")
        #expect(UploadStatus.failed.rawValue == "failed")
    }

    @Test func initFromOptionalString() {
        #expect(UploadStatus(nil) == nil)
        #expect(UploadStatus("uploaded") == .uploaded)
        #expect(UploadStatus("uploading") == .uploading)
        #expect(UploadStatus("failed") == .failed)
        #expect(UploadStatus("invalid") == nil)
    }
}

// MARK: - GoogleAuthConfig Tests

@Suite("GoogleAuthConfig")
struct GoogleAuthConfigTests {
    @Test func isConfiguredMatchesSecrets() {
        // isConfigured should reflect whether Secrets.googleClientID is non-empty
        if Secrets.googleClientID.isEmpty {
            #expect(GoogleAuthConfig.isConfigured == false)
            #expect(GoogleAuthConfig.clientID.isEmpty)
        } else {
            #expect(GoogleAuthConfig.isConfigured == true)
            #expect(!GoogleAuthConfig.clientID.isEmpty)
        }
    }

    @Test func reversedClientIDFormat() {
        guard !Secrets.googleClientID.isEmpty else { return }
        let parts = GoogleAuthConfig.clientID.components(separatedBy: ".")
        let reversed = parts.reversed().joined(separator: ".")
        #expect(GoogleAuthConfig.reversedClientID == reversed)
    }

    @Test func scopesDriveFile() {
        #expect(GoogleAuthConfig.scopes.contains("https://www.googleapis.com/auth/drive.file"))
    }
}
