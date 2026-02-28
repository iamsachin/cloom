import Foundation

struct GoogleAuthConfig {
    static let scopes = ["https://www.googleapis.com/auth/drive.file"]

    static var clientID: String {
        Secrets.googleClientID
    }

    static var isConfigured: Bool {
        !clientID.isEmpty
    }

    /// Reversed client ID used for OAuth URL callback scheme
    static var reversedClientID: String {
        clientID.components(separatedBy: ".").reversed().joined(separator: ".")
    }
}
