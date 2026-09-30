import Testing
import HarmonyRules
import HarmonyEngine
@testable import Harmony

/// The step from what the app recorded to what the engine reasons about.
/// What goes wrong here is quiet: a wrong count makes no error, only a
/// slightly wrong chance in every turn after it.
@Suite("Brücke zur Engine")
struct EngineBridgeTests {
    private func start(display: Stone) -> GameState {
        var state = GameState.initial()
        state.display = Array(repeating: DisplayField(stones: [display, display, display]), count: 5)
        return state
    }

    @Test("Gezogen ist die Auslage, wie sie eingegeben wurde — nicht die Attrappe")
    func drawnStartsFromTheSetupDisplay() {
        let drawn = GameState.stonesDrawn(start: start(display: .field), events: [])
        #expect(drawn == [.field: 15])
    }

    @Test("Die Nachfüllung nach Harmonys eigenem Zug zählt mit")
    func harmonysOwnRefillCounts() {
        let events: [GameEvent] = [
            GameLogTests.opponentTurn(refill: [.brick, .brick, .brick]),
            GameLogTests.harmonyTurn(refill: [.leaves, .leaves, .wood]),
        ]
        let drawn = GameState.stonesDrawn(start: start(display: .water), events: events)
        #expect(drawn[.water] == 15)
        #expect(drawn[.brick] == 3)
        #expect(drawn[.leaves] == 2)
        #expect(drawn[.wood] == 1)
        #expect(drawn.values.reduce(0, +) == 21)
    }

    @Test("Eine Berichtigung nimmt nichts aus dem Beutel")
    func aCorrectionDrawsNothing() {
        let correction = GameEvent.correction(BoardCorrection(changes: []))
        let drawn = GameState.stonesDrawn(start: start(display: .stone), events: [correction])
        #expect(drawn.values.reduce(0, +) == 15)
    }

    @Test("Die Engine bekommt den Beutel aus dieser Zählung")
    func theEngineGetsTheBagFromThatCount() throws {
        let begin = start(display: .water)
        let events = [GameLogTests.opponentTurn(refill: [.brick, .brick, .brick])]
        let engine = try #require(events.state(from: begin)
            .engineState(events: events, start: begin))
        #expect(engine.bag.remaining(.water) == BagKnowledge.total[.water]! - 15)
        #expect(engine.bag.remaining(.brick) == BagKnowledge.total[.brick]! - 3)
        #expect(engine.bag.count == 120 - 18)
    }

    @Test("Harmonys Platz ist der in der Sitzordnung")
    func harmonysSeatIsHerPlaceInTheSeating() throws {
        let state = GameState.initial()
        let engine = try #require(state.engineState(events: [], start: state))
        #expect(engine.seat == state.seating.firstIndex(of: "Harmony"))
        #expect(engine.players == state.seating.count)
    }

    @Test("Eine Karte, die es nicht gibt, ergibt keine Stellung")
    func anUnknownCardGivesNoPosition() {
        var state = GameState.initial()
        state.openCards[0] = "Einhorn"
        #expect(state.engineState(events: [], start: state) == nil)
    }
}
