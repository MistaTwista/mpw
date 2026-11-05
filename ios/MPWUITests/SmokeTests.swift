import XCTest

final class SmokeTests: XCTestCase {
    /// Unlock with the reference vector and read the password of a site that is not saved.
    @MainActor
    func testUnlockAndGeneratePassword() throws {
        let app = XCUIApplication()
        let configDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        app.launchEnvironment["MPW_CONFIG_DIR"] = configDir.path
        app.launch()

        let name = app.textFields["fullName"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        name.tap()
        name.typeText("Robert Lee Mitchell")
        let password = app.secureTextFields["masterPassword"]
        password.tap()
        password.typeText("banana colored duckling")
        app.buttons["unlock"].tap()

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("masterpasswordapp.com")
        app.buttons["oneOff"].tap()
        app.buttons["show"].tap()

        XCTAssertTrue(app.staticTexts["Jejr5[RepuSosp"].waitForExistence(timeout: 5))
    }
}
