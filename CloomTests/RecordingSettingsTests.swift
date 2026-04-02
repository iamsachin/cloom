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
    @Test func fromDefaultsReturnsValidSettings() {
        let settings = RecordingSettings.fromDefaults()

        #expect(settings.fps > 0)
        #expect(VideoQuality.allCases.contains(settings.quality))
        #expect(settings.micSensitivity > 0)
    }

    @Test func customValues() {
        let settings = RecordingSettings(
            fps: 60,
            quality: .high,
            micDeviceID: "mic-abc",
            cameraDeviceID: "cam-xyz",
            micSensitivity: 150,
            creatorModeEnabled: false
        )

        #expect(settings.fps == 60)
        #expect(settings.quality == .high)
        #expect(settings.quality.bitrate == 20_000_000)
        #expect(settings.micDeviceID == "mic-abc")
        #expect(settings.cameraDeviceID == "cam-xyz")
        #expect(settings.micSensitivity == 150)
    }

    @Test func qualityFromInvalidRawValue() {
        let quality = VideoQuality(rawValue: "ultra") ?? .medium
        #expect(quality == .medium)
    }
}
