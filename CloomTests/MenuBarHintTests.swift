import Testing
import Foundation
@testable import Cloom

@Suite("Menu Bar Hint")
struct MenuBarHintTests {

    @Test func defaultsKeyExists() {
        #expect(UserDefaultsKeys.hasSeenMenuBarHint == "hasSeenMenuBarHint")
    }

    @Test func defaultsKeyStartsFalse() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: UserDefaultsKeys.hasSeenMenuBarHint)
        #expect(defaults.bool(forKey: UserDefaultsKeys.hasSeenMenuBarHint) == false)
    }

    @Test func togglePersistsToUserDefaults() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: UserDefaultsKeys.hasSeenMenuBarHint)
        #expect(defaults.bool(forKey: UserDefaultsKeys.hasSeenMenuBarHint) == false)

        defaults.set(true, forKey: UserDefaultsKeys.hasSeenMenuBarHint)
        #expect(defaults.bool(forKey: UserDefaultsKeys.hasSeenMenuBarHint) == true)

        defaults.removeObject(forKey: UserDefaultsKeys.hasSeenMenuBarHint)
    }
}
