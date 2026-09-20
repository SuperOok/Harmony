import Testing
import HarmonyRules
@testable import HarmonyEngine

/// The chain from the card data to a suggested turn — the question Phase 6
/// exists to answer. Positions are kept small so the search stays a test and
/// not a benchmark; how it fares on a real board is measured separately.
@Suite("Suche")
struct SearchTests {
    private func card(_ name: String, _ pattern: [Int: PatternCell],
                      cube: Int, _ points: [Int] = [6, 13]) -> AnimalCard {
        AnimalCard(name: name, pattern: pattern, cube: cube, points: points)
    }

    /// Everything but the named spaces filled with water, which nothing
    /// stacks on.
    private func position(empty: Set<Int>, filled: [Int: [Stone]] = [:],
                          hand: [HeldCard] = [], openCards: [AnimalCard] = [],
                          display: [[Stone]], side: BoardSide = .a) -> EngineState {
        var stacks: [Int: [Stone]] = [:]
        for cell in side.board.cells where !empty.contains(cell) && filled[cell] == nil {
            stacks[cell] = [.water]
        }
        for (cell, stack) in filled { stacks[cell] = stack }
        return EngineState(side: side, stacks: stacks, hand: hand,
                           display: display, openCards: openCards,
                           drawn: [.stone: 6, .wood: 4, .leaves: 3, .water: 2,
                                   .field: 3, .brick: 2],
                           turnsPlayed: 6, players: 3, seat: 0)
    }

    // MARK: - Der Durchstich

    @Test("Aus einer Stellung entsteht ein Zugvorschlag mit Begründung")
    func apositionYieldsASuggestionWithItsReasoning() throws {
        // Die Kernfrage der Phase, als Zusicherung: echte Kartendaten,
        // echte Regeln, echter Vorschlag.
        let deck = try AnimalCards.load()
        let meerkat = deck.first { $0.name == "Erdmännchen" }!
        let state = position(empty: [12, 13, 14], filled: [11: [.field]],
                             hand: [HeldCard(card: meerkat)],
                             display: [[.stone, .water, .water]])

        let suggestion = try #require(Search.best(from: state))
        #expect(!suggestion.terms.isEmpty)
        #expect(suggestion.terms.allSatisfy { !$0.name.isEmpty })
        #expect(suggestion.runnerUp != nil)
        #expect((suggestion.margin ?? -1) >= 0)
        #expect(suggestion.move.placements.values.reduce(0) { $0 + $1.count } == 3)
    }

    @Test("Zweimal dieselbe Stellung gibt zweimal denselben Zug")
    func thesamePositionTwiceGivesTheSameTurnTwice() {
        // Die Momentaufnahmen aus `pruefverfahren.md` hängen daran.
        let state = position(empty: [11, 12, 13],
                             hand: [HeldCard(card: card("Prüftier",
                                                        [11: .field, 12: .mountain1],
                                                        cube: 12))],
                             display: [[.stone, .stone, .stone]])
        #expect(Search.best(from: state)?.move == Search.best(from: state)?.move)
    }

    // MARK: - Der vorbereitende Zug

    @Test("Ist nichts zu vollenden, wird trotzdem auf einen Anwärter hin gelegt")
    func withNothingToFinishTheStonesStillGoTowardsACandidate() {
        // Das Muster braucht vier Steine, der Zug hat drei — es kann in
        // diesem Zug nicht fertig werden. Auf 55 könnte es nie liegen: Die
        // Ecke hat nur zwei Nachbarn, und beide sind Wasser.
        let far = card("Weit", [11: .mountain3, 12: .mountain1], cube: 12)
        let state = position(empty: [11, 12, 55],
                             hand: [HeldCard(card: far)],
                             display: [[.stone, .stone, .stone]])

        let suggestion = Search.best(from: state)
        #expect(suggestion?.move.cubes.isEmpty == true, "nichts zu vollenden")
        #expect(suggestion?.move.placements[55] == nil,
                "ein Stein in der toten Ecke statt am Muster")
        #expect(suggestion?.move.placements.keys.allSatisfy { [11, 12].contains($0) } == true)
    }

    @Test("Ein Zug, der kein Muster vollendet, hebt trotzdem den Wert")
    func aturnFinishingNoPatternStillRaisesTheWorth() {
        // Das Muster bleibt nach dem Zug unfertig, es wird also kein Würfel
        // gesetzt. Trotzdem steht die Stellung danach besser da: Was vorher
        // vier Steine entfernt war, ist es danach nur noch einen.
        let far = card("Weit", [11: .mountain3, 12: .mountain1], cube: 12)
        let state = position(empty: [11, 12, 55],
                             hand: [HeldCard(card: far)],
                             display: [[.stone, .stone, .stone]])
        let before = Evaluator.evaluate(state).value
        let suggestion = Search.best(from: state)
        #expect(suggestion?.move.cubes.isEmpty == true, "nichts zu vollenden")
        #expect((suggestion?.value ?? 0) > before, "der vorbereitende Zug hebt den Wert")
    }

    // MARK: - Kein liegengelassener Würfel

    @Test("Ein Würfel, der gesetzt werden kann, wird gesetzt")
    func acubeThatCanBeLaidIsLaid() {
        // Offene Frage 4 aus `03-funktionsumfang.md` schlägt genau das als
        // Abnahmekriterium für v1 vor.
        let meerkat = card("Erdmännchen", [11: .field, 12: .mountain1], cube: 12)
        let state = position(empty: [12, 13, 14], filled: [11: [.field]],
                             hand: [HeldCard(card: meerkat)],
                             display: [[.stone, .water, .water]])
        let suggestion = Search.best(from: state)
        #expect(suggestion?.move.cubes[12] == "Erdmännchen")
        #expect(suggestion?.pointsNow ?? 0 > 0)
    }

    @Test("Eine Karte, die sich sofort bedienen lässt, wird genommen")
    func acardThatCanBeServedAtOnceIsTaken() {
        let meerkat = card("Erdmännchen", [11: .field, 12: .mountain1], cube: 12)
        let state = position(empty: [12, 13, 14], filled: [11: [.field]],
                             openCards: [meerkat],
                             display: [[.stone, .water, .water]])
        let suggestion = Search.best(from: state)
        #expect(suggestion?.move.cardTaken == "Erdmännchen")
        #expect(suggestion?.move.cubes[12] == "Erdmännchen")
    }

    // MARK: - Die Zufallsschicht

    @Test("Die Zufallsschicht wird zusammengefasst, nicht aufgezählt")
    func thechanceLayerIsSummarisedAndNotEnumerated() {
        // Was nach dem Zug in der Auslage zu erwarten ist: die vier übrigen
        // Felder, gezählt, plus drei Steine aus dem Beutel nach ihrem Anteil.
        let state = position(empty: [11, 12, 13],
                             display: [[.stone, .stone, .stone],
                                       [.water, .water, .water]])
        let available = Search.availability(after: 0, of: state)
        #expect((available.perColour[.water] ?? 0) > 3, "drei liegen, dazu die Erwartung")
        #expect(abs(available.total - 6) < 1e-9, "drei übrige plus drei nachgezogene")
        // Und der genommene Stapel ist heraus.
        let other = Search.availability(after: 1, of: state)
        #expect((other.perColour[.stone] ?? 0) > 3)
    }

    @Test("Eine knappe Farbe senkt die Erwartung")
    func ascarceColourLowersTheExpectation() {
        var state = position(empty: [11, 12, 13],
                             display: [[.stone, .stone, .stone]])
        state.drawn = [.brick: 15]              // kein roter Stein mehr im Beutel
        let available = Search.availability(after: 0, of: state)
        #expect((available.perColour[.brick] ?? 0) == 0)
    }

    // MARK: - Der Zustand nach dem Zug

    @Test("Ein ausgeführter Zug führt den Zustand richtig nach")
    func aplayedTurnCarriesTheStateForward() {
        let meerkat = card("Erdmännchen", [11: .field, 12: .mountain1], cube: 12)
        let state = position(empty: [12, 13, 14], filled: [11: [.field]],
                             hand: [HeldCard(card: meerkat)],
                             display: [[.stone, .water, .water]])
        let move = Move(space: 0, placements: [12: [.stone], 13: [.water], 14: [.water]],
                        cubes: [12: "Erdmännchen"])
        let after = state.applying(move)

        #expect(after.stacks[12] == [.stone])
        #expect(after.cubes[12] == "Erdmännchen")
        #expect(after.hand.first?.cubesPlaced == 1)
        #expect(after.hand.first?.score == 6)
        #expect(after.display.isEmpty, "das geleerte Feld ist heraus")
        #expect(after.turnsPlayed == 7)
        #expect(after.inconsistencies.isEmpty, "\(after.inconsistencies)")
    }
}
