import Testing
import HarmonyRules
@testable import Harmony

/// The game being played, as the screen holds it: events in, position out.
@Suite("Sitzung")
struct GameSessionTests {
    private func session(restored: [GameEvent] = [],
                         onChange: @escaping ([GameEvent]) -> Void = { _ in }) -> GameSession {
        GameSession(start: .initial(), restored: restored, onChange: onChange)
    }

    @Test("Ein Ereignis rückt die Sitzordnung vor und meldet sich")
    func anEventAdvancesTheSeatingAndSaysSo() {
        var saved: [Int] = []
        let session = session(onChange: { saved.append($0.count) })
        #expect(session.state.currentPlayer == "Anke")

        session.append(GameLogTests.opponentTurn())
        #expect(session.state.currentPlayer == "Bernd")
        #expect(session.turnCount == 1)
        #expect(saved == [1])
    }

    @Test("Zurücknehmen stellt die Stellung vor dem Ereignis wieder her")
    func undoRestoresThePositionBeforeTheEvent() {
        var saved: [Int] = []
        let session = session(onChange: { saved.append($0.count) })
        let before = session.state.display.map(\.notation)

        session.append(GameLogTests.opponentTurn(taken: 0, refill: [.brick, .brick, .brick]))
        #expect(session.state.display.map(\.notation) != before)

        session.undoLast()
        #expect(session.state.display.map(\.notation) == before)
        #expect(session.state.currentPlayer == "Anke")
        #expect(saved == [1, 0])
    }

    @Test("Zurücknehmen ohne Ereignis tut nichts und speichert nichts")
    func undoWithoutAnEventDoesNothing() {
        var saved = 0
        let session = session(onChange: { _ in saved += 1 })
        session.undoLast()
        #expect(saved == 0)
        #expect(session.events.isEmpty)
    }

    @Test("Eine wiederhergestellte Partie hat ihre Stellung sofort")
    func aRestoredGameHasItsPositionAtOnce() {
        let session = session(restored: [GameLogTests.opponentTurn(), GameLogTests.opponentTurn()])
        #expect(session.state.currentPlayer == "Harmony")
        #expect(session.state.isHarmonysTurn)
        #expect(session.turnCount == 2)
    }

    @Test("Eine Berichtigung ist kein Zug, ändert aber die Positionsmarke")
    func aCorrectionIsNoTurnButChangesThePositionKey() {
        let session = session()
        let before = session.positionKey
        session.append(.correction(BoardCorrection(changes: [])))
        #expect(session.turnCount == 0)
        #expect(session.state.currentPlayer == "Anke")
        #expect(session.positionKey != before)
    }

    @Test("Der Beutel ist nach fünfunddreißig Zügen leer, nicht vorher")
    func theBagIsEmptyAfterThirtyFiveTurns() {
        let session = session()
        for _ in 0..<34 { session.append(GameLogTests.opponentTurn()) }
        #expect(!session.bagEmpty)
        session.append(GameLogTests.opponentTurn())
        #expect(session.bagEmpty)
    }

    @Test("Das Spielende wird gemeldet, sobald der Beutel es auslöst")
    func theEndIsAnnouncedOnceTheBagTriggersIt() {
        let session = session()
        for _ in 0..<35 { session.append(GameLogTests.opponentTurn()) }
        #expect(session.end.reason == "Der Beutel ist leer.")
        // The round is played out: three players, so 36 turns.
        #expect(session.end.endsAfter == 36)
        #expect(!session.end.isOver)
        session.append(GameLogTests.opponentTurn(refill: []))
        #expect(session.end.isOver)
    }

    @Test("Der Verlauf hat eine Zeile je Ereignis")
    func theHistoryHasALinePerEvent() {
        let session = session()
        session.append(GameLogTests.opponentTurn())
        session.append(.correction(BoardCorrection(changes: [])))
        #expect(session.history.count == 2)
    }
}
