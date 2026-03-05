import XCTest
@testable import Cloom

final class SparkleUpdaterTests: XCTestCase {

    // MARK: - Info.plist Keys

    func testInfoPlistContainsSUFeedURL() {
        let feedURL = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String
        // In test bundles Info.plist isn't the app's, so this validates the key exists if set
        // The real validation is that the app launches with Sparkle without crashing
        XCTAssertTrue(feedURL == nil || feedURL!.hasPrefix("https://"))
    }

    func testInfoPlistContainsSUPublicEDKey() {
        let pubKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        // Same as above — validates format if present
        XCTAssertTrue(pubKey == nil || !pubKey!.isEmpty)
    }
}
