import XCTest
@testable import Cloom

final class UpdateCheckerTests: XCTestCase {

    // MARK: - Version Comparison

    func testNewerPatchVersion() {
        XCTAssertTrue(UpdateChecker.isNewer("0.1.1", than: "0.1.0"))
    }

    func testNewerMinorVersion() {
        XCTAssertTrue(UpdateChecker.isNewer("0.2.0", than: "0.1.0"))
    }

    func testNewerMajorVersion() {
        XCTAssertTrue(UpdateChecker.isNewer("1.0.0", than: "0.9.9"))
    }

    func testSameVersion() {
        XCTAssertFalse(UpdateChecker.isNewer("0.1.0", than: "0.1.0"))
    }

    func testOlderVersion() {
        XCTAssertFalse(UpdateChecker.isNewer("0.0.9", than: "0.1.0"))
    }

    func testOlderMajorVersion() {
        XCTAssertFalse(UpdateChecker.isNewer("0.9.9", than: "1.0.0"))
    }

    func testDifferentLengthVersions() {
        XCTAssertTrue(UpdateChecker.isNewer("1.0.0.1", than: "1.0.0"))
        XCTAssertFalse(UpdateChecker.isNewer("1.0.0", than: "1.0.0.1"))
    }

    func testTwoPartVersion() {
        XCTAssertTrue(UpdateChecker.isNewer("1.1", than: "1.0"))
        XCTAssertFalse(UpdateChecker.isNewer("1.0", than: "1.1"))
    }

    func testSinglePartVersion() {
        XCTAssertTrue(UpdateChecker.isNewer("2", than: "1"))
        XCTAssertFalse(UpdateChecker.isNewer("1", than: "2"))
    }

    func testLargeVersionNumbers() {
        XCTAssertTrue(UpdateChecker.isNewer("10.20.30", than: "10.20.29"))
        XCTAssertFalse(UpdateChecker.isNewer("10.20.29", than: "10.20.30"))
    }
}
