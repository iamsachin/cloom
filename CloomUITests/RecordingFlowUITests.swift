import XCTest

@MainActor
final class RecordingFlowUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments.append("--uitesting")
        app.launch()
    }

    func testMenuBarExtraExists() throws {
        // The menu bar extra should appear on launch
        let menuBarItem = app.menuBarItems["Cloom"]
        XCTAssertTrue(menuBarItem.waitForExistence(timeout: 5))
    }

    func testOpenLibrary() throws {
        let menuBarItem = app.menuBarItems["Cloom"]
        guard menuBarItem.waitForExistence(timeout: 5) else {
            XCTFail("Menu bar item not found")
            return
        }
        menuBarItem.click()

        let openLibrary = app.menuItems["Open Library"]
        XCTAssertTrue(openLibrary.waitForExistence(timeout: 3))
    }

    func testSettingsMenuItem() throws {
        let menuBarItem = app.menuBarItems["Cloom"]
        guard menuBarItem.waitForExistence(timeout: 5) else {
            XCTFail("Menu bar item not found")
            return
        }
        menuBarItem.click()

        let settings = app.menuItems["Settings..."]
        XCTAssertTrue(settings.waitForExistence(timeout: 3))
    }

    func testStartRecordingMenuExists() throws {
        let menuBarItem = app.menuBarItems["Cloom"]
        guard menuBarItem.waitForExistence(timeout: 5) else {
            XCTFail("Menu bar item not found")
            return
        }
        menuBarItem.click()

        let startRecording = app.menuItems["Start Recording"]
        XCTAssertTrue(startRecording.waitForExistence(timeout: 3))
    }
}
