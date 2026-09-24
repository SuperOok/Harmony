import Testing
import HarmonyRules
@testable import HarmonyEngine

/// The price of a card space: a card cannot be thrown away, so taking a weak
/// one costs the space it blocks. `docs/06-durchstich.md`, *Der Preis eines
/// Kartenplatzes*, has the reasoning and the measurement.
@Suite("Kartenplätze")
struct CardSlotTests {
    private func card(_ name: String, _ pattern: [Int: PatternCell],
                      cube: Int, _ points: [Int]) -> AnimalCard {
        AnimalCard(name: name, pattern: pattern, cube: cube, points: points)
    }

    /// A card whose pattern needs nine stones: held, unfinished, and far
    /// from anything this position could finish. It fills a space and
    /// otherwise stays out of the way.
    private func dead(_ name: String) -> HeldCard {
        HeldCard(card: card(name, [11: .tree3, 12: .tree3, 13: .tree3], cube: 12, [5, 12]))
    }

    /// Worth a single point for a pattern the stones on offer do not serve.
    private var weak: AnimalCard {
        card("Schwach", [12: .field, 13: .field], cube: 13, [1, 2])
    }

    /// Twelve free spaces, the rest water, three grey stones on offer — room
    /// for several more turns, so the price is not cut by the clock.
    private func position(hand: [HeldCard]) -> EngineState {
        let side = BoardSide.a
        let free = Set(side.board.cells.prefix(12))
        var stacks: [Int: [Stone]] = [:]
        for cell in side.board.cells where !free.contains(cell) { stacks[cell] = [.water] }
        return EngineState(side: side, stacks: stacks, hand: hand,
                           display: [[.stone, .stone, .stone]],
                           openCards: [weak],
                           drawn: [.stone: 6, .wood: 4, .leaves: 3, .water: 2,
                                   .field: 3, .brick: 2],
                           turnsPlayed: 6, players: 3, seat: 0)
    }

    /// No price at all — how she weighed before the price was measured.
    private var unpriced: Weights {
        var weights = Weights()
        weights.freeSlots = [0, 0, 0, 0]
        return weights
    }

    /// The graded price, at full worth from the first turn on.
    private var priced: Weights {
        var weights = Weights()
        weights.freeSlots = [4, 2.4, 1, 0]
        weights.freeSlotsFullFrom = 1
        return weights
    }

    @Test("Ohne Preis bleibt die Bewertung, wie sie war")
    func withoutAPriceNothingChanges() {
        let state = position(hand: [])
        #expect(Evaluator.freeSlotTerm(state, weights: unpriced) == nil)
        #expect(!Evaluator.evaluate(state, weights: unpriced).terms
            .contains { $0.name == "Freie Kartenplätze" })
    }

    @Test("Ohne Preis wird auch eine schwache Karte genommen")
    func withoutAPriceAWeakCardIsTaken() {
        let state = position(hand: [dead("Tot1"), dead("Tot2"), dead("Tot3")])
        #expect(Search.best(from: state, weights: unpriced)?.move.cardTaken == "Schwach")
    }

    @Test("Der gemessene Preis gilt von selbst")
    func theMeasuredPriceIsTheDefault() {
        // Without being asked for, so the app plays with it.
        let state = position(hand: [dead("Tot1"), dead("Tot2"), dead("Tot3")])
        #expect(Weights().freeSlots == [10, 6, 2.5, 0])
        #expect(Search.best(from: state)?.move.cardTaken == nil)
    }

    @Test("Eine schwache Karte, die die Hand schließen würde, bleibt liegen")
    func aWeakCardThatWouldCloseTheHandIsLeft() {
        let state = position(hand: [dead("Tot1"), dead("Tot2"), dead("Tot3")])
        let suggestion = Search.best(from: state, weights: priced)
        #expect(suggestion != nil)
        #expect(suggestion?.move.cardTaken == nil)
    }

    @Test("Aus leerer Hand wird auch mit Preis genommen")
    func fromAnEmptyHandACardIsStillTaken() {
        // The first space costs nothing: three are left for better cards.
        // A flat price would leave her empty-handed here.
        let state = position(hand: [])
        #expect(Search.best(from: state, weights: priced)?.move.cardTaken == "Schwach")
    }

    @Test("Am Ende ist ein freier Platz nichts mehr wert")
    func atTheEndAFreeSpaceIsWorthNothing() {
        var weights = priced
        weights.freeSlotsFullFrom = 6
        var state = position(hand: [])
        let early = Evaluator.freeSlotTerm(state, weights: weights)?.points ?? 0
        state.endsAfter = state.turnsPlayed
        let late = Evaluator.freeSlotTerm(state, weights: weights)?.points ?? -1
        #expect(early > 0)
        #expect(late == 0)
    }

    @Test("Der Preis ist gestaffelt: der letzte freie Platz kostet am meisten")
    func thePriceIsGraded() {
        let term = { (held: Int) -> Double in
            let hand = (0..<held).map { dead("Tot\($0)") }
            return Evaluator.freeSlotTerm(position(hand: hand), weights: priced)?.points ?? 0
        }
        // Worth of the free spaces with 0, 1, 2, 3 cards held.
        let lost = [term(0) - term(1), term(1) - term(2), term(2) - term(3), term(3)]
        let expected = [0, 1, 2.4, 4]
        #expect(zip(lost, expected).allSatisfy { abs($0 - $1) < 1e-9 }, "\(lost)")
    }
}
