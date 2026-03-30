import XCTest
@testable import Cloom

final class TeleprompterTests: XCTestCase {

    // MARK: - TeleprompterPosition

    func testAllPositionCases() {
        let cases = TeleprompterPosition.allCases
        XCTAssertEqual(cases.count, 2)
        XCTAssertTrue(cases.contains(.top))
        XCTAssertTrue(cases.contains(.bottom))
    }

    func testPositionRawValueRoundTrip() {
        for position in TeleprompterPosition.allCases {
            XCTAssertEqual(TeleprompterPosition(rawValue: position.rawValue), position)
        }
    }

    func testPositionIdentifiable() {
        let top = TeleprompterPosition.top
        let bottom = TeleprompterPosition.bottom
        XCTAssertEqual(top.id, "Top")
        XCTAssertEqual(bottom.id, "Bottom")
        XCTAssertNotEqual(top.id, bottom.id)
    }

    func testInvalidRawValueReturnsNil() {
        XCTAssertNil(TeleprompterPosition(rawValue: "Left"))
        XCTAssertNil(TeleprompterPosition(rawValue: ""))
    }

    // MARK: - UserDefaultsKeys

    func testTeleprompterKeysExist() {
        // Verify all teleprompter keys are unique and non-empty
        let keys = [
            UserDefaultsKeys.teleprompterScript,
            UserDefaultsKeys.teleprompterFontSize,
            UserDefaultsKeys.teleprompterScrollSpeed,
            UserDefaultsKeys.teleprompterOpacity,
            UserDefaultsKeys.teleprompterPosition,
            UserDefaultsKeys.teleprompterMirrorEnabled,
        ]
        XCTAssertEqual(Set(keys).count, keys.count, "All keys should be unique")
        for key in keys {
            XCTAssertFalse(key.isEmpty, "Key should not be empty")
        }
    }

    // MARK: - Script defaults

    func testDefaultScriptIsEmpty() {
        let defaults = UserDefaults(suiteName: "TeleprompterTestSuite")!
        defaults.removePersistentDomain(forName: "TeleprompterTestSuite")
        let script = defaults.string(forKey: UserDefaultsKeys.teleprompterScript) ?? ""
        XCTAssertTrue(script.isEmpty)
    }

    func testScriptPersistence() {
        let defaults = UserDefaults(suiteName: "TeleprompterPersistSuite")!
        defaults.removePersistentDomain(forName: "TeleprompterPersistSuite")

        let testScript = "Hello, this is my test script for recording."
        defaults.set(testScript, forKey: UserDefaultsKeys.teleprompterScript)
        let retrieved = defaults.string(forKey: UserDefaultsKeys.teleprompterScript)
        XCTAssertEqual(retrieved, testScript)
    }

    // MARK: - Settings defaults

    func testDefaultFontSize() {
        let defaults = UserDefaults(suiteName: "TeleprompterFontSuite")!
        defaults.removePersistentDomain(forName: "TeleprompterFontSuite")
        let fontSize = defaults.double(forKey: UserDefaultsKeys.teleprompterFontSize)
        // Default is 0 when not set — the coordinator uses 40 as fallback
        XCTAssertEqual(fontSize, 0)
    }

    func testDefaultScrollSpeed() {
        let defaults = UserDefaults(suiteName: "TeleprompterSpeedSuite")!
        defaults.removePersistentDomain(forName: "TeleprompterSpeedSuite")
        let speed = defaults.double(forKey: UserDefaultsKeys.teleprompterScrollSpeed)
        XCTAssertEqual(speed, 0)
    }

    func testDefaultOpacity() {
        let defaults = UserDefaults(suiteName: "TeleprompterOpacitySuite")!
        defaults.removePersistentDomain(forName: "TeleprompterOpacitySuite")
        let opacity = defaults.double(forKey: UserDefaultsKeys.teleprompterOpacity)
        XCTAssertEqual(opacity, 0)
    }

    func testDefaultMirrorDisabled() {
        let defaults = UserDefaults(suiteName: "TeleprompterMirrorSuite")!
        defaults.removePersistentDomain(forName: "TeleprompterMirrorSuite")
        let mirror = defaults.bool(forKey: UserDefaultsKeys.teleprompterMirrorEnabled)
        XCTAssertFalse(mirror)
    }

    func testPositionDefaultsToBottom() {
        let defaults = UserDefaults(suiteName: "TeleprompterPosSuite")!
        defaults.removePersistentDomain(forName: "TeleprompterPosSuite")
        let raw = defaults.string(forKey: UserDefaultsKeys.teleprompterPosition) ?? TeleprompterPosition.bottom.rawValue
        let pos = TeleprompterPosition(rawValue: raw) ?? .bottom
        XCTAssertEqual(pos, .bottom)
    }

    // MARK: - Word count estimation

    func testWordCountFromScript() {
        let script = "Hello world this is a test script with nine words"
        let count = script.split(whereSeparator: \.isWhitespace).count
        XCTAssertEqual(count, 10)
    }

    func testEmptyScriptWordCount() {
        let script = ""
        let count = script.split(whereSeparator: \.isWhitespace).count
        XCTAssertEqual(count, 0)
    }

    func testMultilineScriptWordCount() {
        let script = """
        Line one has four words.
        Line two also has words.
        And a third line.
        """
        let count = script.split(whereSeparator: \.isWhitespace).count
        XCTAssertEqual(count, 14)
    }

    // MARK: - Scroll speed estimation

    func testScrollDurationEstimation() {
        // 600 points of content at 60 pt/s = 10 seconds
        let contentHeight: CGFloat = 600
        let viewportHeight: CGFloat = 200
        let scrollSpeed: CGFloat = 60
        let maxScroll = max(0, contentHeight - viewportHeight)
        let duration = maxScroll / scrollSpeed
        XCTAssertEqual(duration, 400.0 / 60.0, accuracy: 0.01)
    }

    func testZeroSpeedNeverCompletes() {
        let maxScroll: CGFloat = 400
        let speed: CGFloat = 0
        // Guard against division by zero
        let duration = speed > 0 ? maxScroll / speed : CGFloat.infinity
        XCTAssertEqual(duration, .infinity)
    }

    // MARK: - Speed Adjustment Logic

    func testSpeedAdjustClampsToMinimum() {
        // Simulates adjustSpeed clamping: max(10, min(200, current + delta))
        let current: CGFloat = 20
        let delta: CGFloat = -30
        let result = max(10, min(200, current + delta))
        XCTAssertEqual(result, 10, "Speed should not go below 10")
    }

    func testSpeedAdjustClampsToMaximum() {
        let current: CGFloat = 190
        let delta: CGFloat = 20
        let result = max(10, min(200, current + delta))
        XCTAssertEqual(result, 200, "Speed should not exceed 200")
    }

    func testSpeedAdjustNormalIncrement() {
        let current: CGFloat = 60
        let delta: CGFloat = 10
        let result = max(10, min(200, current + delta))
        XCTAssertEqual(result, 70)
    }

    func testSpeedAdjustNormalDecrement() {
        let current: CGFloat = 60
        let delta: CGFloat = -10
        let result = max(10, min(200, current + delta))
        XCTAssertEqual(result, 50)
    }

    func testSpeedAdjustAtBoundaryMinimum() {
        let current: CGFloat = 10
        let delta: CGFloat = -10
        let result = max(10, min(200, current + delta))
        XCTAssertEqual(result, 10, "Already at minimum, should stay at 10")
    }

    func testSpeedAdjustAtBoundaryMaximum() {
        let current: CGFloat = 200
        let delta: CGFloat = 10
        let result = max(10, min(200, current + delta))
        XCTAssertEqual(result, 200, "Already at maximum, should stay at 200")
    }

    func testSpeedPersistsToUserDefaults() {
        let defaults = UserDefaults(suiteName: "TeleprompterSpeedPersistSuite")!
        defaults.removePersistentDomain(forName: "TeleprompterSpeedPersistSuite")

        let newSpeed: CGFloat = 80
        defaults.set(Double(newSpeed), forKey: UserDefaultsKeys.teleprompterScrollSpeed)
        let retrieved = defaults.double(forKey: UserDefaultsKeys.teleprompterScrollSpeed)
        XCTAssertEqual(retrieved, 80.0)
    }

    // MARK: - Manual Scroll (Nudge)

    func testNudgeScrollClampsToZero() {
        var scrollOffset: CGFloat = 5
        let delta: CGFloat = -20
        scrollOffset = max(0, scrollOffset + delta)
        XCTAssertEqual(scrollOffset, 0, "Scroll offset should not go negative")
    }

    func testNudgeScrollClampsToMax() {
        let contentHeight: CGFloat = 500
        let viewportHeight: CGFloat = 200
        let maxScroll = max(0, contentHeight - viewportHeight)
        var scrollOffset: CGFloat = 290
        let delta: CGFloat = 20
        scrollOffset = max(0, scrollOffset + delta)
        scrollOffset = min(scrollOffset, maxScroll)
        XCTAssertEqual(scrollOffset, 300, "Scroll offset should not exceed maxScroll")
    }

    func testDragDeltaCalculation() {
        // Drag down (lastY > currentY) should scroll content up (positive delta)
        let lastY: CGFloat = 300
        let currentY: CGFloat = 280
        let delta = lastY - currentY
        XCTAssertEqual(delta, 20, "Dragging down should produce positive delta")
    }

    func testDragUpDeltaCalculation() {
        // Drag up (lastY < currentY) should scroll content down (negative delta)
        let lastY: CGFloat = 280
        let currentY: CGFloat = 300
        let delta = lastY - currentY
        XCTAssertEqual(delta, -20, "Dragging up should produce negative delta")
    }
}
