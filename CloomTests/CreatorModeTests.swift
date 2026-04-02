import Testing
import Foundation
@testable import Cloom

@Suite("Creator Mode")
struct CreatorModeTests {

    // MARK: - UserDefaults Key

    @Test func defaultsKeyExists() {
        #expect(UserDefaultsKeys.creatorModeEnabled == "creatorModeEnabled")
    }

    // MARK: - RecordingSettings

    @Test func fromDefaultsReadsCreatorMode() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: UserDefaultsKeys.creatorModeEnabled)
        let settings = RecordingSettings.fromDefaults()
        #expect(settings.creatorModeEnabled == true)
        defaults.removeObject(forKey: UserDefaultsKeys.creatorModeEnabled)
    }

    @Test func fromDefaultsDefaultsFalse() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: UserDefaultsKeys.creatorModeEnabled)
        let settings = RecordingSettings.fromDefaults()
        #expect(settings.creatorModeEnabled == false)
    }

    @Test func memberiwseInitSetsCreatorMode() {
        let settings = RecordingSettings(
            fps: 30,
            quality: .medium,
            micDeviceID: nil,
            cameraDeviceID: nil,
            micSensitivity: 100,
            creatorModeEnabled: true
        )
        #expect(settings.creatorModeEnabled == true)
    }

    // MARK: - CaptureState

    @Test func captureStateDefaultCreatorModeFalse() {
        let state = CaptureState()
        #expect(state.creatorMode == false)
    }

    @Test func captureStateCreatorModeSettable() {
        var state = CaptureState()
        state.creatorMode = true
        #expect(state.creatorMode == true)
    }

    // MARK: - Toggle persistence round-trip

    @Test func togglePersistsToUserDefaults() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: UserDefaultsKeys.creatorModeEnabled)
        #expect(defaults.bool(forKey: UserDefaultsKeys.creatorModeEnabled) == false)

        defaults.set(true, forKey: UserDefaultsKeys.creatorModeEnabled)
        #expect(defaults.bool(forKey: UserDefaultsKeys.creatorModeEnabled) == true)

        defaults.removeObject(forKey: UserDefaultsKeys.creatorModeEnabled)
    }
}
