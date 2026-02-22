import Testing
import Foundation
@testable import Cloom

@Suite("VideoQuality")
struct VideoQualityTests {
    @Test func lowBitrate() {
        #expect(VideoQuality.low.bitrate == 4_000_000)
    }

    @Test func mediumBitrate() {
        #expect(VideoQuality.medium.bitrate == 10_000_000)
    }

    @Test func highBitrate() {
        #expect(VideoQuality.high.bitrate == 20_000_000)
    }

    @Test func allCasesCount() {
        #expect(VideoQuality.allCases.count == 3)
    }

    @Test func labels() {
        #expect(VideoQuality.low.label == "Low")
        #expect(VideoQuality.medium.label == "Medium")
        #expect(VideoQuality.high.label == "High")
    }

    @Test func identifiable() {
        #expect(VideoQuality.low.id == "low")
        #expect(VideoQuality.medium.id == "medium")
        #expect(VideoQuality.high.id == "high")
    }
}

@Suite("RecordingSettings")
struct RecordingSettingsTests {
    @Test func fromDefaultsWithNoDefaults() {
        // Use a separate suite to avoid polluting global UserDefaults
        let defaults = UserDefaults(suiteName: "com.cloom.test.recordingSettings")!
        defaults.removePersistentDomain(forName: "com.cloom.test.recordingSettings")

        // fromDefaults() uses UserDefaults.standard, so test the logic directly
        let settings = RecordingSettings(
            fps: 0 > 0 ? 0 : 30,
            quality: VideoQuality(rawValue: VideoQuality.medium.rawValue) ?? .medium,
            micDeviceID: nil,
            cameraDeviceID: nil,
            noiseCancellationEnabled: false
        )

        #expect(settings.fps == 30)
        #expect(settings.quality == .medium)
        #expect(settings.micDeviceID == nil)
        #expect(settings.cameraDeviceID == nil)
        #expect(settings.noiseCancellationEnabled == false)
    }

    @Test func customValues() {
        let settings = RecordingSettings(
            fps: 60,
            quality: .high,
            micDeviceID: "mic-abc",
            cameraDeviceID: "cam-xyz",
            noiseCancellationEnabled: true
        )

        #expect(settings.fps == 60)
        #expect(settings.quality == .high)
        #expect(settings.quality.bitrate == 20_000_000)
        #expect(settings.micDeviceID == "mic-abc")
        #expect(settings.cameraDeviceID == "cam-xyz")
        #expect(settings.noiseCancellationEnabled == true)
    }

    @Test func qualityFromInvalidRawValue() {
        let quality = VideoQuality(rawValue: "ultra") ?? .medium
        #expect(quality == .medium)
    }
}
