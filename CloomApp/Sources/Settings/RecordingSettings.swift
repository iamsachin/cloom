import Foundation

enum VideoQuality: String, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var bitrate: Int {
        switch self {
        case .low: 4_000_000
        case .medium: 10_000_000
        case .high: 20_000_000
        }
    }

    var label: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }
}

struct RecordingSettings {
    let fps: Int
    let quality: VideoQuality
    let micDeviceID: String?
    let cameraDeviceID: String?

    static func fromDefaults() -> RecordingSettings {
        let defaults = UserDefaults.standard
        let fps = defaults.integer(forKey: "recordingFPS")
        let qualityRaw = defaults.string(forKey: "recordingQuality") ?? VideoQuality.medium.rawValue
        let micID = defaults.string(forKey: "recordingMicDeviceID")
        let cameraID = defaults.string(forKey: "recordingCameraDeviceID")

        return RecordingSettings(
            fps: fps > 0 ? fps : 30,
            quality: VideoQuality(rawValue: qualityRaw) ?? .medium,
            micDeviceID: micID,
            cameraDeviceID: cameraID
        )
    }
}
