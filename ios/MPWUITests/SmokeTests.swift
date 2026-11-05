import XCTest

final class SmokeTests: XCTestCase {
    /// Launches the app with an empty config folder and unlocks it with the reference vector.
    @MainActor
    private func launchAndUnlock() -> XCUIApplication {
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
        return app
    }

    @MainActor
    private func search(_ app: XCUIApplication, for text: String) {
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText(text)
    }

    /// Unlock with the reference vector and read the password of a site that is not saved.
    @MainActor
    func testUnlockAndGeneratePassword() throws {
        let app = launchAndUnlock()
        search(app, for: "masterpasswordapp.com")
        app.buttons["oneOff"].tap()
        app.buttons["show"].tap()

        XCTAssertTrue(app.staticTexts["Jejr5[RepuSosp"].waitForExistence(timeout: 5))
    }

    /// Add a site, open it, then edit its counter: the shown password follows the edit.
    @MainActor
    func testPasswordFollowsEdit() throws {
        let app = launchAndUnlock()
        search(app, for: "masterpasswordapp.com")
        app.buttons["addSearched"].tap()
        let save = app.buttons["save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()

        let site = app.buttons["site:masterpasswordapp.com"]
        XCTAssertTrue(site.waitForExistence(timeout: 5))
        site.tap()
        app.buttons["show"].tap()
        XCTAssertTrue(app.staticTexts["Jejr5[RepuSosp"].waitForExistence(timeout: 5))

        app.buttons["edit"].tap()
        let counter = app.steppers["counter"]
        XCTAssertTrue(counter.waitForExistence(timeout: 5))
        counter.buttons["counter-Increment"].tap()
        app.buttons["save"].tap()

        // Long, counter 2, from internal/mpw/testdata/golden.json.
        XCTAssertTrue(app.staticTexts["GornJuci5/Zafs"].waitForExistence(timeout: 5))
    }
}
