import Foundation

/// Centralized UserDefaults key constants to avoid scattered raw string literals.
enum UserDefaultsKeys {
    // MARK: - App
    static let appearanceMode = "appearanceMode"
    static let libraryViewStyle = "libraryViewStyle"
    static let notificationsEnabled = "notificationsEnabled"

    // MARK: - AI
    static let aiAutoTranscribe = "aiAutoTranscribe"

    // MARK: - Recording
    static let recordingFPS = "recordingFPS"
    static let recordingQuality = "recordingQuality"
    static let recordingMicDeviceID = "recordingMicDeviceID"
    static let recordingCameraDeviceID = "recordingCameraDeviceID"
    static let micSensitivity = "micSensitivity"
    static let systemAudioEnabled = "systemAudioEnabled"
    static let countdownDuration = "countdownDuration"
    static let defaultSaveLocation = "defaultSaveLocation"
    static let silenceThresholdDb = "silenceThresholdDb"
    static let silenceMinDurationMs = "silenceMinDurationMs"

    // MARK: - Webcam
    static let webcamShape = "webcamShape"
    static let webcamFrame = "webcamFrame"
    static let webcamBrightness = "webcamBrightness"
    static let webcamContrast = "webcamContrast"
    static let webcamSaturation = "webcamSaturation"
    static let webcamHighlights = "webcamHighlights"
    static let webcamShadows = "webcamShadows"
    static let webcamTemperature = "webcamTemperature"
    static let webcamTint = "webcamTint"
    static let webcamMirrorEnabled = "webcamMirrorEnabled"
}
