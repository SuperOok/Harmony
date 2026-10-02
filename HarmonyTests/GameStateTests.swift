import Testing
import HarmonyRules
import HarmonyEngine
@testable import Harmony

/// What Harmony knows — the `EngineState` inside the game's position — and
/// how events change it. What goes wrong here is quiet: a wrong count makes
/// no error, only a slightly wrong chance in every turn after it.
@Suite("Wissen der Partie")
struct GameStateTests {
    private func start(display stone: Stone) -> GameState {
        let base = GameState.initial()
        return GameState(display: Array(repeating: DisplayField(stones: [stone, stone, stone]),
                                        count: 5),
                         openCards: base.openCards, seenCards: base.seenCards, seatIndex: 0,
                         harmonyBoard: [:], harmonyCubes: [:], harmonyCards: [],
                         seating: base.seating, sideB: false)
    }

    // MARK: - The bag

    @Test("Gezogen ist die Auslage, wie sie eingegeben wurde — nicht die Attrappe")
    func drawnStartsFromTheSetupDisplay() {
        #expect(start(display: .field).knowledge.drawn == [.field: 15])
    }

    @Test("Die Nachfüllung nach Harmonys eigenem Zug zählt mit")
    func harmonysOwnRefillCounts() {
        let events: [GameEvent] = [
            GameLogTests.opponentTurn(refill: [.brick, .brick, .brick]),
            GameLogTests.opponentTurn(),
            GameLogTests.harmonyTurn(refill: [.leaves, .leaves, .wood]),
        ]
        let drawn = events.state(from: start(display: .water)).knowledge.drawn
        #expect(drawn[.water] == 18)
        #expect(drawn[.brick] == 3)
        #expect(drawn[.leaves] == 2)
        #expect(drawn[.wood] == 1)
        #expect(drawn.values.reduce(0, +) == 24)
    }

    @Test("Eine Berichtigung nimmt nichts aus dem Beutel")
    func aCorrectionDrawsNothing() {
        let correction = GameEvent.correction(BoardCorrection(changes: []))
        let state = [correction].state(from: start(display: .stone))
        #expect(state.knowledge.drawn.values.reduce(0, +) == 15)
        #expect(state.knowledge.turnsPlayed == 0)
    }

    @Test("Der Beutel der Engine stimmt mit der Zählung überein")
    func theEnginesBagFollowsTheCount() {
        let events = [GameLogTests.opponentTurn(refill: [.brick, .brick, .brick])]
        let bag = events.state(from: start(display: .water)).knowledge.bag
        #expect(bag.remaining(.water) == BagKnowledge.total[.water]! - 15)
        #expect(bag.remaining(.brick) == BagKnowledge.total[.brick]! - 3)
        #expect(bag.count == 120 - 18)
    }

    // MARK: - Who and what

    @Test("Harmonys Platz ist der in der Sitzordnung")
    func harmonysSeatIsHerPlaceInTheSeating() {
        let state = GameState.initial()
        #expect(state.knowledge.seat == state.seating.firstIndex(of: "Harmony"))
        #expect(state.knowledge.players == state.seating.count)
    }

    @Test("Die Karten, die niemand gesehen hat, sind alle übrigen")
    func theUnseenCardsAreAllTheOthers() {
        let state = GameState.initial()
        let known = Set(state.openCards).union(state.harmonyCards.map(\.name))
        #expect(state.knowledge.deck.count == AnimalCards.all.count - known.count)
        #expect(state.knowledge.inconsistencies.isEmpty, "\(state.knowledge.inconsistencies)")
        #expect(state.seenCards.isSuperset(of: known))
    }

    @Test("Eine genommene und eine nachgerückte Karte ändern, was gesehen ist")
    func aTakenAndAMovedUpCardChangeWhatHasBeenSeen() throws {
        let start = start(display: .water)
        let taken = try #require(start.openCards.first)
        let moved = try #require(AnimalCards.all.map(\.name).first { !start.seenCards.contains($0) })
        var state = start
        state.apply(.opponentTurn(OpponentTurn(taken: 0, refill: [.brick, .brick, .brick],
                                               cardTaken: taken, cardDrawn: moved)))
        #expect(!state.openCards.contains(taken))
        #expect(state.openCards.contains(moved))
        #expect(state.seenCards.contains(moved))
        #expect(state.seenCards.contains(taken))
        #expect(state.harmonyCards.isEmpty)
    }

    @Test("Ihre Karte kommt in die Hand, ihr Würfel wird auf der Karte gezählt")
    func herCardGoesInHerHandAndTheCubeIsCounted() throws {
        let start = start(display: .water)
        let card = try #require(start.openCards.first)
        let moved = try #require(AnimalCards.all.map(\.name).first { !start.seenCards.contains($0) })
        var state = start
        state.seatIndex = 2
        let move = HarmonyMove(space: 0,
                               placements: [Placement(stone: .water, cell: 11),
                                            Placement(stone: .water, cell: 12),
                                            Placement(stone: .water, cell: 13)],
                               cubes: [CubePlacement(card: card, cell: 12)],
                               cardTaken: card, rationale: GameLogTests.rationale(),
                               refill: [.brick, .brick, .brick], cardDrawn: moved)
        state.apply(.harmonyTurn(move))
        #expect(state.harmonyCards.map(\.name) == [card])
        #expect(state.knowledge.hand.first?.cubesPlaced == 1)
        #expect(state.harmonyBoard.count == 3)
        #expect(state.harmonyCubes == [12: card])
        #expect(state.knowledge.inconsistencies.isEmpty, "\(state.knowledge.inconsistencies)")
    }

    @Test("Eine Berichtigung setzt das Feld neu und lässt die Sitzordnung stehen")
    func aCorrectionResetsTheSpaceAndLeavesTheSeating() {
        var state = GameState.initial()
        let seat = state.seatIndex
        state.apply(.correction(BoardCorrection(changes: [
            .init(cell: 11, stack: [.stone, .stone], cube: nil)])))
        #expect(state.harmonyBoard[11] == [.stone, .stone])
        #expect(state.seatIndex == seat)
    }
}
