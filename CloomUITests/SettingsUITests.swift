import XCTest

@MainActor
final class SettingsUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments.append("--uitesting")
        app.launch()
    }

    func testOpenSettings() throws {
        let menuBarItem = app.menuBarItems["Cloom"]
        guard menuBarItem.waitForExistence(timeout: 5) else {
            XCTFail("Menu bar item not found")
            return
        }
        menuBarItem.click()

        let settings = app.menuItems["Settings..."]
        guard settings.waitForExistence(timeout: 3) else {
            XCTFail("Settings menu item not found")
            return
        }
        settings.click()

        // Settings window should appear
        let settingsWindow = app.windows.firstMatch
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 5))
    }
}
