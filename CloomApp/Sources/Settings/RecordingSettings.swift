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
    let micSensitivity: Int

    static func fromDefaults() -> RecordingSettings {
        let defaults = UserDefaults.standard
        let fps = defaults.integer(forKey: UserDefaultsKeys.recordingFPS)
        let qualityRaw = defaults.string(forKey: UserDefaultsKeys.recordingQuality) ?? VideoQuality.medium.rawValue
        let micID = defaults.string(forKey: UserDefaultsKeys.recordingMicDeviceID)
        let cameraID = defaults.string(forKey: UserDefaultsKeys.recordingCameraDeviceID)
        let sensitivity = defaults.integer(forKey: UserDefaultsKeys.micSensitivity)

        return RecordingSettings(
            fps: fps > 0 ? fps : 30,
            quality: VideoQuality(rawValue: qualityRaw) ?? .medium,
            micDeviceID: micID,
            cameraDeviceID: cameraID,
            micSensitivity: sensitivity > 0 ? sensitivity : 100
        )
    }
}
