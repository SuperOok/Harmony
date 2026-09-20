import XCTest

/// Storey three from `docs/pruefverfahren.md`: the input path, never the
/// game logic. What is asserted are the two tap budgets for recording
/// another player's turn — at most five taps without taking a card, at
/// most eight with one. Both limits sit on the measured value with no
/// slack, because a tolerated extra tap would swallow exactly the
/// regression the test exists to report.
///
/// The count is the test's own. The dummy displays a counter as well
/// (identifier `taps`), but a target value read back from the program only
/// describes what the program currently does, which `00-methodik.md` rules
/// out. That counter is checked separately, as an assertion about the
/// display rather than about the input path.
final class TapBudgetTests: XCTestCase {
    private var app = XCUIApplication()

    /// Every tap this test makes passes through `tap(_:)` and lands here,
    /// so the budget cannot be undercounted by reaching past the helper.
    private var taps = 0

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        taps = 0
    }

    // MARK: - The budgets

    func testRecordingAnothersTurnWithoutACardCostsAtMostFiveTaps() {
        startOnAnothersTurn()

        tap(app.buttons["field-0"])
        tap(app.buttons["palette-S"])
        tap(app.buttons["palette-H"])
        tap(app.buttons["palette-L"])
        tap(app.buttons["record"])

        assertTurnWasRecorded(handingOverTo: "Bernd")
        XCTAssertLessThanOrEqual(
            taps, 5,
            "A turn without a card is budgeted at five taps: the display "
            + "space, three stones drawn for it, and recording the turn.")
    }

    func testRecordingAnothersTurnWithACardCostsAtMostEightTaps() {
        startOnAnothersTurn()

        tap(app.buttons["field-0"])
        tap(app.buttons["palette-S"])
        tap(app.buttons["palette-H"])
        tap(app.buttons["palette-L"])
        tap(firstElement(withIdentifierPrefix: "card-"))
        tap(app.buttons["drawn"])
        tap(firstElement(withIdentifierPrefix: "pick-"))
        tap(app.buttons["record"])

        assertTurnWasRecorded(handingOverTo: "Bernd")
        XCTAssertLessThanOrEqual(
            taps, 8,
            "Taking a card adds three taps to the five: the card taken, the "
            + "picker for the one that moved up, and the card chosen in it.")
    }

    // MARK: - The counter on screen

    /// Not part of the budget. The app shows what it thinks the turn cost,
    /// and this checks that display against what was actually tapped — the
    /// other direction from the assertions above, which take the test's own
    /// count as the truth.
    func testTheDisplayedCounterAgreesWithWhatWasTapped() {
        startOnAnothersTurn()

        tap(app.buttons["field-0"])
        tap(app.buttons["palette-S"])
        tap(app.buttons["palette-H"])
        tap(app.buttons["palette-L"])

        XCTAssertEqual(app.buttons["taps"].label, "\(taps) ×",
                       "The counter in the toolbar counts the taps of the "
                       + "turn being entered, and the turn is not recorded yet.")
    }

    // MARK: - Getting to a foreign turn

    /// The dummy opens on the setup unless told otherwise. `-harmonyTurn`
    /// starts it on Harmony's screen with the sample position; confirming
    /// her move hands the turn to the first opponent, which is where a
    /// foreign turn begins.
    ///
    /// That confirmation is arranging the position, not entering the turn,
    /// and is therefore not counted — the app does not count it either.
    private func startOnAnothersTurn() {
        app.launchArguments = ["-harmonyTurn"]
        app.launch()

        let confirmHarmonysMove = app.buttons["harmony-done"]
        XCTAssertTrue(confirmHarmonysMove.waitForExistence(timeout: 30),
                      "-harmonyTurn should open on Harmony's screen.")
        confirmHarmonysMove.tap()

        XCTAssertTrue(app.buttons["field-0"].waitForExistence(timeout: 10),
                      "After Harmony's move it is an opponent's turn.")
    }

    // MARK: - Helpers

    private func tap(_ element: XCUIElement,
                     file: StaticString = #filePath, line: UInt = #line) {
        bringIntoView(element, file: file, line: line)
        element.tap()
        taps += 1
    }

    /// Scrolling is a drag, not a tap. `05-ui.md` keeps dragging out of the
    /// budget, so this happens outside the count.
    private func bringIntoView(_ element: XCUIElement,
                               file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 10),
                      "No element \(element.identifier) on screen.",
                      file: file, line: line)
        var swipes = 0
        while !element.isHittable && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(element.isHittable,
                      "\(element.identifier) never came into reach.",
                      file: file, line: line)
    }

    /// The card names are sample data and are not spelled out here; what
    /// matters is that one of them can be picked.
    private func firstElement(withIdentifierPrefix prefix: String) -> XCUIElement {
        app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
            .firstMatch
    }

    /// The transcript line under the board names whoever is to move. After
    /// a recorded turn it holds the next player and nothing else, which
    /// shows both that the turn went in and that the seating moved on — a
    /// budget met by tapping nothing would fail here.
    private func assertTurnWasRecorded(handingOverTo player: String,
                                       file: StaticString = #filePath,
                                       line: UInt = #line) {
        let notation = app.staticTexts["notation"]
        XCTAssertTrue(notation.waitForExistence(timeout: 10),
                      "The transcript line is always on screen.",
                      file: file, line: line)
        XCTAssertEqual(notation.label, player,
                       "With the turn recorded and nothing entered yet, the "
                       + "line is the next player's name on its own.",
                       file: file, line: line)
    }
}
