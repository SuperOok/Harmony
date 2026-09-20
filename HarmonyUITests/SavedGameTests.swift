import XCTest

/// A game survives the app being put away. `04-architektur.md` asks for the
/// event sequence to be written after every event, and gives the reason: a
/// game lasts an evening, and an evening includes a phone call.
///
/// This is the one assurance that cannot be had cheaply. Losing a game is a
/// silent failure — the app comes back looking perfectly fine, only empty —
/// and a turn takes minutes to compute, so a lost game is a lost evening.
final class SavedGameTests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() { continueAfterFailure = false }

    func testAgameSurvivesTheAppBeingClosed() {
        // `-forgetGame` starts from a clean table, `-sampleMove` keeps the
        // engine out: what is tested here is the writing and the reading,
        // not the search.
        app.launchArguments = ["-forgetGame", "-sampleMove"]
        app.launch()

        setUpAGame()
        XCTAssertTrue(app.buttons["field-0"].waitForExistence(timeout: 15),
                      "Nach dem Aufbau ist die Mitspielerin am Zug.")
        recordOneTurn()

        // Ein Zug ist erfasst, also ist Harmony an der Reihe. Daran lässt
        // sich der Stand ablesen, ohne den Verlauf zu öffnen.
        XCTAssertTrue(app.buttons["harmony-done"].waitForExistence(timeout: 15),
                      "Nach dem Zug der Mitspielerin ist Harmony dran.")

        // Weggelegt und zurück, ohne den Vergessen-Haken.
        app.terminate()
        app.launchArguments = ["-sampleMove"]
        app.launch()

        XCTAssertTrue(app.buttons["harmony-done"].waitForExistence(timeout: 20),
                      "Die Partie kommt zurück, mitsamt dem gespielten Zug.")
        XCTAssertFalse(app.buttons["choose-players"].exists,
                       "Der Aufbau wird nicht noch einmal gefragt.")
    }

    func testThrowingTheGameAwayReturnsToTheSetup() {
        app.launchArguments = ["-forgetGame", "-sampleMove"]
        app.launch()
        setUpAGame()
        recordOneTurn()

        XCTAssertTrue(app.buttons["taps"].waitForExistence(timeout: 15))
        app.buttons["taps"].tap()
        let discard = app.buttons["new-game"]
        XCTAssertTrue(discard.waitForExistence(timeout: 5))
        discard.tap()

        XCTAssertTrue(app.buttons["choose-players"].waitForExistence(timeout: 10),
                      "Ohne diesen Weg käme man aus der letzten Partie nie heraus.")
    }

    // MARK: - Die Partie aufbauen

    /// Players, fifteen stones, five cards. Arranging the position, not a
    /// budget — the tap counts that are assured live in `TapBudgetTests`.
    private func setUpAGame() {
        tap("choose-players")
        tapFirst(withPrefix: "pick-")
        tap("done")
        tap("next")

        // Fünf Felder zu drei Steinen. Die Farben sind gleichgültig,
        // solange es fünfzehn sind.
        let palette = ["W", "S", "H", "L", "F"]
        for round in 0..<3 {
            for stone in palette {
                tap("palette-\(stone == "W" && round == 2 ? "Z" : stone)")
            }
        }

        tap("choose-cards")
        // Fünf **verschiedene** Karten. Eine gewählte bleibt in der Liste
        // stehen und würde beim zweiten Antippen wieder abgewählt.
        let picks = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "pick-"))
        XCTAssertTrue(picks.firstMatch.waitForExistence(timeout: 15))
        for index in 0..<5 { picks.element(boundBy: index).tap() }
        tap("start")
    }

    /// One opponent turn, so there is something to lose.
    private func recordOneTurn() {
        tap("field-0")
        for stone in ["W", "S", "H"] { tap("palette-\(stone)") }
        tap("record")
    }

    // MARK: - Helfer

    private func tap(_ identifier: String,
                     file: StaticString = #filePath, line: UInt = #line) {
        let element = app.descendants(matching: .any)[identifier]
        XCTAssertTrue(element.waitForExistence(timeout: 15),
                      "Kein Element \(identifier).", file: file, line: line)
        var swipes = 0
        while !element.isHittable && swipes < 6 { app.swipeUp(); swipes += 1 }
        element.tap()
    }

    private func tapFirst(withPrefix prefix: String,
                          file: StaticString = #filePath, line: UInt = #line) {
        let element = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
            .firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 15),
                      "Nichts mit \(prefix).", file: file, line: line)
        element.tap()
    }
}
