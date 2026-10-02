import Testing
import HarmonyRules
@testable import HarmonyEngine

/// Entering what happened: a turn that was played, as opposed to one that is
/// looked at. `HarmonyTableTests` holds these against the table itself.
@Suite("Ereignisse eintragen")
struct RecordTests {
    private let cards = AnimalCards.all

    private func state(hand: [String] = []) -> EngineState {
        let held = Set(hand)
        let open = cards.filter { !held.contains($0.name) }.prefix(5)
        let openNames = Set(open.map(\.name))
        return EngineState(
            hand: cards.filter { held.contains($0.name) }.map { HeldCard(card: $0) },
            display: [[.water, .water, .water], [.stone, .stone, .stone],
                      [.wood, .wood, .wood], [.leaves, .leaves, .leaves],
                      [.field, .field, .field]],
            openCards: Array(open),
            deck: cards.filter { !held.contains($0.name) && !openNames.contains($0.name) },
            drawn: [.water: 3, .stone: 3, .wood: 3, .leaves: 3, .field: 3])
    }

    // MARK: - What everyone learns

    @Test("Das genommene Feld nimmt die gezogenen Steine auf und zählt sie")
    func theTakenSpaceTakesWhatWasDrawnAndCountsIt() {
        var state = state()
        state.recordTurn(space: 1, refill: [.brick, .brick, .wood])
        #expect(state.display.count == 5)
        #expect(state.display[1] == [.brick, .brick, .wood])
        #expect(state.drawn[.brick] == 2)
        #expect(state.drawn[.wood] == 4)
        #expect(state.turnsPlayed == 1)
    }

    @Test("Bei leerem Beutel entfällt das Feld")
    func withAnEmptyBagTheSpaceIsGone() {
        var state = state()
        let others = state.display.enumerated().filter { $0.offset != 2 }.map(\.element)
        state.recordTurn(space: 2, refill: [])
        #expect(state.display == others)
        #expect(state.drawn.values.reduce(0, +) == 15)
        #expect(state.turnsPlayed == 1)
    }

    @Test("Eine genommene Karte macht der nachgerückten Platz, aus den ungesehenen")
    func aTakenCardMakesRoomForTheOneThatMovedUp() throws {
        var state = state()
        let taken = state.openCards[2]
        let moved = try #require(state.deck.first)
        let result = state.recordTurn(space: 0, refill: [.water, .water, .water],
                                      cardTaken: taken.name, cardDrawn: moved.name)
        #expect(result == taken)
        #expect(state.openCards.count == 5)
        #expect(state.openCards[2] == moved)
        #expect(!state.deck.contains(moved))
        #expect(state.deck.count == cards.count - 5 - 1)
    }

    @Test("Ohne nachgerückte Karte, weil der Stapel leer ist, fehlt sie einfach")
    func withoutACardMovingUpTheOpenCardIsJustGone() {
        var state = state()
        let taken = state.openCards[0]
        state.recordTurn(space: 0, refill: [], cardTaken: taken.name)
        #expect(state.openCards.count == 4)
        #expect(!state.openCards.contains(taken))
    }

    @Test("Eine Karte, die nicht offen liegt, wird nicht genommen")
    func aCardThatIsNotOpenIsNotTaken() {
        var state = state()
        let before = state.openCards
        #expect(state.recordTurn(space: 0, refill: [.water, .water, .water],
                                 cardTaken: "Einhorn") == nil)
        #expect(state.openCards == before)
    }

    @Test("Ein Feld, das es nicht gibt, ändert die Auslage nicht")
    func aMissingSpaceLeavesTheDisplayAlone() {
        var state = state()
        let before = state.display
        state.recordTurn(space: 9, refill: [.water, .water, .water])
        #expect(state.display == before)
    }

    // MARK: - Her own turn

    @Test("Ihr Zug legt die Steine, setzt den Würfel und nimmt die Karte in die Hand")
    func herTurnLaysStonesSetsTheCubeAndTakesTheCard() {
        var state = state()
        let card = state.openCards[1]
        state.recordOwnTurn(space: 3,
                            placements: [11: [.leaves], 12: [.wood, .wood]],
                            cubes: [11: card.name],
                            refill: [.brick, .brick, .brick],
                            cardTaken: card.name,
                            cardDrawn: state.deck[0].name)
        #expect(state.stacks[11] == [.leaves])
        #expect(state.stacks[12] == [.wood, .wood])
        #expect(state.hand.map(\.card) == [card])
        #expect(state.hand[0].cubesPlaced == 1)
        #expect(state.cubes == [11: card.name])
    }

    @Test("Mehrere Steine auf einem Feld liegen in der Reihenfolge, in der sie kamen")
    func stonesOnOneSpaceKeepTheirOrder() {
        var state = state()
        state.recordOwnTurn(space: 0, placements: [21: [.wood, .leaves]], cubes: [:],
                            refill: [.water, .water, .water])
        #expect(state.stacks[21] == [.wood, .leaves])
    }

    // MARK: - Corrections

    @Test("Eine Berichtigung setzt das Feld und die Würfel neu und zählt nach")
    func aCorrectionResetsTheSpaceAndRecountsTheCubes() {
        var state = state(hand: ["Erdmännchen", "Lachs"])
        state.stacks = [11: [.field], 12: [.stone]]
        state.cubes = [12: "Lachs"]
        state.recountCubes()
        #expect(state.hand.first { $0.card.name == "Lachs" }?.cubesPlaced == 1)

        // The cube lay on the wrong card.
        state.correct(cell: 12, stack: [.stone], cube: "Erdmännchen")
        #expect(state.hand.first { $0.card.name == "Lachs" }?.cubesPlaced == 0)
        #expect(state.hand.first { $0.card.name == "Erdmännchen" }?.cubesPlaced == 1)

        state.correct(cell: 11, stack: [], cube: nil)
        #expect(state.stacks[11] == nil)
        #expect(state.turnsPlayed == 0, "eine Berichtigung ist kein Zug")
    }

    @Test("Was eingetragen wird, bleibt in sich stimmig")
    func whatIsRecordedStaysConsistent() {
        var state = state(hand: ["Lachs"])
        let card = state.openCards[0]
        state.recordOwnTurn(space: 0, placements: [11: [.stone]], cubes: [:],
                            refill: [.brick, .wood, .leaves],
                            cardTaken: card.name, cardDrawn: state.deck[0].name)
        #expect(state.inconsistencies.isEmpty, "\(state.inconsistencies)")
    }
}
