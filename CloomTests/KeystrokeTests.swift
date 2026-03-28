import XCTest
@testable import Cloom

final class KeystrokeEventTests: XCTestCase {

    // MARK: - KeystrokeEvent opacity

    func testOpacityFullDuringDisplayPeriod() {
        let event = KeystrokeEvent(label: "⌘S", startTime: 100, displayDuration: 1.5, fadeDuration: 0.5)
        XCTAssertEqual(event.opacity(at: 100), 1.0)
        XCTAssertEqual(event.opacity(at: 100.5), 1.0)
        XCTAssertEqual(event.opacity(at: 101.49), 1.0)
    }

    func testOpacityFadesDuringFadePeriod() {
        let event = KeystrokeEvent(label: "A", startTime: 100, displayDuration: 1.0, fadeDuration: 1.0)
        // At start of fade
        XCTAssertEqual(event.opacity(at: 101.0), 1.0, accuracy: 0.01)
        // Midway through fade
        XCTAssertEqual(event.opacity(at: 101.5), 0.5, accuracy: 0.01)
        // End of fade
        XCTAssertEqual(event.opacity(at: 102.0), 0.0, accuracy: 0.01)
    }

    func testOpacityZeroAfterTotalDuration() {
        let event = KeystrokeEvent(label: "X", startTime: 50, displayDuration: 1.5, fadeDuration: 0.5)
        XCTAssertEqual(event.opacity(at: 52.1), 0.0)
    }

    func testOpacityBeforeStartTime() {
        let event = KeystrokeEvent(label: "Z", startTime: 100, displayDuration: 1.0, fadeDuration: 0.5)
        XCTAssertEqual(event.opacity(at: 99.0), 1.0)
    }

    func testTotalDuration() {
        let event = KeystrokeEvent(label: "⌘C", startTime: 0, displayDuration: 2.0, fadeDuration: 0.5)
        XCTAssertEqual(event.totalDuration, 2.5)
    }

    // MARK: - KeystrokePosition

    func testAllPositionCases() {
        let cases = KeystrokePosition.allCases
        XCTAssertEqual(cases.count, 4)
        XCTAssertTrue(cases.contains(.bottomLeft))
        XCTAssertTrue(cases.contains(.bottomRight))
        XCTAssertTrue(cases.contains(.topLeft))
        XCTAssertTrue(cases.contains(.topRight))
    }

    func testPositionRawValueRoundTrip() {
        for position in KeystrokePosition.allCases {
            XCTAssertEqual(KeystrokePosition(rawValue: position.rawValue), position)
        }
    }

    // MARK: - KeystrokeDisplayMode

    func testDisplayModeCases() {
        let cases = KeystrokeDisplayMode.allCases
        XCTAssertEqual(cases.count, 2)
        XCTAssertTrue(cases.contains(.allKeys))
        XCTAssertTrue(cases.contains(.modifierCombosOnly))
    }

    func testDisplayModeRawValueRoundTrip() {
        for mode in KeystrokeDisplayMode.allCases {
            XCTAssertEqual(KeystrokeDisplayMode(rawValue: mode.rawValue), mode)
        }
    }

    // MARK: - KeystrokeState defaults

    func testKeystrokeStateDefaults() {
        let state = KeystrokeState()
        XCTAssertFalse(state.isEnabled)
        XCTAssertTrue(state.events.isEmpty)
        XCTAssertEqual(state.position, .bottomLeft)
        XCTAssertEqual(state.displayMode, .allKeys)
    }

    // MARK: - AnnotationStore keystroke methods

    func testAddAndPruneKeystrokes() {
        let store = AnnotationStore()
        store.setKeystrokeEnabled(true)

        let event1 = KeystrokeEvent(label: "⌘S", startTime: 100, displayDuration: 1.0, fadeDuration: 0.5)
        let event2 = KeystrokeEvent(label: "⌘C", startTime: 101, displayDuration: 1.0, fadeDuration: 0.5)
        store.addKeystroke(event1)
        store.addKeystroke(event2)

        var snap = store.snapshot()
        XCTAssertTrue(snap.keystroke.isEnabled)
        XCTAssertEqual(snap.keystroke.events.count, 2)

        // Prune at time 101.6 — event1 (started at 100, total 1.5) should be pruned
        store.pruneExpiredKeystrokes(currentTime: 101.6)
        snap = store.snapshot()
        XCTAssertEqual(snap.keystroke.events.count, 1)
        XCTAssertEqual(snap.keystroke.events.first?.label, "⌘C")
    }

    func testSetKeystrokePosition() {
        let store = AnnotationStore()
        store.setKeystrokePosition(.topRight)
        let snap = store.snapshot()
        XCTAssertEqual(snap.keystroke.position, .topRight)
    }

    func testSetKeystrokeDisplayMode() {
        let store = AnnotationStore()
        store.setKeystrokeDisplayMode(.modifierCombosOnly)
        let snap = store.snapshot()
        XCTAssertEqual(snap.keystroke.displayMode, .modifierCombosOnly)
    }

    func testSetKeystrokeEnabled() {
        let store = AnnotationStore()
        XCTAssertFalse(store.snapshot().keystroke.isEnabled)
        store.setKeystrokeEnabled(true)
        XCTAssertTrue(store.snapshot().keystroke.isEnabled)
        store.setKeystrokeEnabled(false)
        XCTAssertFalse(store.snapshot().keystroke.isEnabled)
    }
}
