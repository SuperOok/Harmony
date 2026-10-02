import Testing
import HarmonyRules
@testable import Harmony

/// The event log and the position replayed from it — the part of the app
/// that decides what Harmony is told about the table.
@Suite("Ereignisverlauf")
struct GameLogTests {
    static func rationale() -> MoveRationale {
        MoveRationale(immediate: 1, value: 2, terms: [ScoreTerm(name: "Test", points: 1)],
                      runnerUp: "—", runnerUpImmediate: 0, runnerUpValue: 1,
                      gapExplanation: "")
    }

    static func harmonyTurn(space: Int = 0, refill: [Stone] = [.water, .water, .water]) -> GameEvent {
        .harmonyTurn(HarmonyMove(space: space, placements: [], cubes: [],
                                 rationale: rationale(), refill: refill))
    }

    static func opponentTurn(taken: Int = 0, refill: [Stone] = [.water, .water, .water]) -> GameEvent {
        .opponentTurn(OpponentTurn(taken: taken, refill: refill))
    }

    // MARK: - The display

    @Test("Ein Zug mit Nachfüllung ersetzt das genommene Feld")
    func aRefillReplacesTheTakenSpace() {
        var state = GameState.initial()
        state.apply(Self.opponentTurn(taken: 1, refill: [.brick, .brick, .brick]))
        #expect(state.display.count == 5)
        #expect(state.display[1].stones == [.brick, .brick, .brick])
    }

    @Test("Bei leerem Beutel verschwindet das genommene Feld, es bleibt kein Phantom")
    func anEmptyBagRemovesTheTakenSpace() {
        var state = GameState.initial()
        let others = state.display.enumerated().filter { $0.offset != 1 }.map(\.element.notation)
        state.apply(Self.opponentTurn(taken: 1, refill: []))
        #expect(state.display.count == 4)
        #expect(state.display.map(\.notation) == others)
    }

    @Test("Harmonys Zug bei leerem Beutel nimmt das Feld ebenso heraus")
    func harmonysTurnWithAnEmptyBagRemovesTheSpace() {
        var state = GameState.initial(seat: 2)
        state.apply(Self.harmonyTurn(space: 4, refill: []))
        #expect(state.display.count == 4)
    }

    @Test("Auch die Engine sieht nur die Felder, die es noch gibt")
    func theEngineSeesOnlyTheSpacesThatExist() {
        let start = GameState.initial()
        let events = [Self.opponentTurn(taken: 0, refill: [])]
        let state = events.state(from: start)
        #expect(state.knowledge.display.count == 4)
    }

    // MARK: - What a saved game may contain

    @Test("Ein Ereignis, das auf ein nicht vorhandenes Feld zeigt, wird nicht angenommen")
    func aTurnOnAMissingSpaceIsNotAccepted() {
        let state = GameState.initial()
        #expect(state.accepts(Self.opponentTurn(taken: 4)))
        #expect(!state.accepts(Self.opponentTurn(taken: 5)))
        #expect(!state.accepts(Self.harmonyTurn(space: 9)))
    }

    @Test("Eine Nachfüllung ist ganz oder gar nicht")
    func aRefillIsWholeOrNone() {
        let state = GameState.initial()
        #expect(state.accepts(Self.opponentTurn(refill: [])))
        #expect(!state.accepts(Self.opponentTurn(refill: [.water])))
        #expect(!state.accepts(Self.opponentTurn(refill: Array(repeating: .water, count: 4))))
    }

    @Test("Ein Platz außerhalb der Sitzordnung ist keine zeigbare Stellung")
    func aSeatOutsideTheSeatingIsNotShowable() {
        var state = GameState.initial()
        #expect(state.isConsistent)
        state.seatIndex = 3
        #expect(!state.isConsistent)
    }

    @Test("Eine Sitzordnung ohne Harmony ist keine zeigbare Stellung")
    func aSeatingWithoutHarmonyIsNotShowable() {
        var state = GameState.initial()
        state.seating = state.seating.map { $0 == GameState.harmonyName ? "Anke" : $0 }
        #expect(!state.isConsistent)
    }

    // MARK: - The transcript

    @Test("Die Zeilen des Verlaufs behalten ihre Nummer, wenn er neu berechnet wird")
    func transcriptEntriesKeepTheirIdentity() {
        let start = GameState.initial()
        let events = [Self.opponentTurn(), Self.opponentTurn(), Self.harmonyTurn()]
        let first = events.entries(from: start).map(\.id)
        let second = events.entries(from: start).map(\.id)
        #expect(first == [0, 1, 2])
        #expect(first == second)
    }
}
