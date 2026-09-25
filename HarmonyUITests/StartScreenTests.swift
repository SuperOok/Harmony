import XCTest

/// The start screen: the way into a game, and the settings that reach the
/// engine. `-showStart` brings it back, which the other hooks skip.
final class StartScreenTests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() { continueAfterFailure = false }

    func testANewGameStartsFromTheStartScreen() {
        app.launchArguments = ["-forgetGame", "-sampleMove", "-showStart"]
        app.launch()

        let newGame = app.buttons["start-new-game"]
        XCTAssertTrue(newGame.waitForExistence(timeout: 10),
                      "Nach dem Start kommt der Start-Bildschirm.")
        XCTAssertFalse(app.buttons["start-continue"].exists,
                       "Ohne angefangene Partie gibt es nichts fortzusetzen.")
        newGame.tap()
        XCTAssertTrue(app.buttons["choose-players"].waitForExistence(timeout: 10),
                      "Eine neue Partie beginnt mit dem Aufbau.")
    }

    func testTheSettingsAreKeptAndCanBeReset() {
        app.launchArguments = ["-forgetGame", "-sampleMove", "-showStart"]
        app.launch()

        open("start-settings")
        let price = app.switches["settings-card-spaces"]
        XCTAssertTrue(price.waitForExistence(timeout: 10))
        // Aus einem früheren Lauf könnte noch etwas verstellt sein.
        reset()
        XCTAssertEqual(price.value as? String, "1", "Standard: Kartenplätze werden bewertet.")
        price.switches.firstMatch.tap()
        XCTAssertEqual(price.value as? String, "0")

        // Neu gestartet: Die Einstellung ist geblieben.
        app.terminate()
        app.launch()
        open("start-settings")
        XCTAssertTrue(price.waitForExistence(timeout: 10))
        XCTAssertEqual(price.value as? String, "0", "Die Einstellung überdauert den Neustart.")

        reset()
        XCTAssertEqual(price.value as? String, "1", "Zurückgesetzt gilt wieder der Standard.")
    }

    func testAboutShowsTheVersion() {
        app.launchArguments = ["-forgetGame", "-sampleMove", "-showStart"]
        app.launch()
        open("start-about")
        let version = app.staticTexts["about-version"]
        XCTAssertTrue(version.waitForExistence(timeout: 10))
        XCTAssertTrue(version.label.hasPrefix("Version "), version.label)
    }

    // MARK: - Helfer

    private func open(_ identifier: String) {
        let link = app.buttons[identifier]
        XCTAssertTrue(link.waitForExistence(timeout: 10), "Kein \(identifier).")
        link.tap()
    }

    /// Scrolls to the reset button, uses it if anything differs from the
    /// standard, and scrolls back to the top.
    private func reset() {
        let button = app.buttons["settings-reset"]
        var swipes = 0
        while !button.isHittable && swipes < 6 { app.swipeUp(); swipes += 1 }
        if button.isEnabled { button.tap() }
        let price = app.switches["settings-card-spaces"]
        swipes = 0
        while !price.isHittable && swipes < 6 { app.swipeDown(); swipes += 1 }
    }
}
