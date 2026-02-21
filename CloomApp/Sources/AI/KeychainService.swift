import Foundation

enum KeychainService {
    private static var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Cloom", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("api_key")
    }

    static func saveAPIKey(_ key: String) {
        guard let data = key.data(using: .utf8) else { return }
        try? data.write(to: storageURL, options: [.atomic, .completeFileProtection])
        // Restrict file permissions to owner only (read/write)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: storageURL.path
        )
    }

    static func loadAPIKey() -> String? {
        guard let data = try? Data(contentsOf: storageURL),
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty
        else {
            return nil
        }
        return key
    }

    static func deleteAPIKey() {
        try? FileManager.default.removeItem(at: storageURL)
    }
}
