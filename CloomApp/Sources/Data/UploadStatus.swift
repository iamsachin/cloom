import Foundation

enum UploadStatus: String, Sendable, CaseIterable {
    case uploading
    case uploaded
    case failed

    init?(_ rawValue: String?) {
        guard let rawValue else { return nil }
        self.init(rawValue: rawValue)
    }
}
