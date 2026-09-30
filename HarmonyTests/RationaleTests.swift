import Testing
import Foundation
import HarmonyRules
@testable import HarmonyEngine
@testable import Harmony

/// What the engine tells the screen about a turn, and what the screen then
/// shows as the reason. A wrong label here is a quiet lie: the numbers are
/// all real, only what they claim to be is not.
@Suite("Begründung")
struct RationaleTests {
    /// A small real position, searched for real.
    private func suggestion() throws -> Suggestion {
        let meerkat = try #require(AnimalCards.all.first { $0.name == "Erdmännchen" })
        // Nearly full of water, so that the river is done and the card's
        // prospect is among the largest terms the suggestion names.
        var stacks: [Int: [Stone]] = [11: [.field]]
        for cell in BoardSide.a.board.cells where ![11, 12, 13, 14].contains(cell) {
            stacks[cell] = [.water]
        }
        let state = EngineState(side: .a, stacks: stacks, hand: [HeldCard(card: meerkat)],
                                display: [[.stone, .water, .water]],
                                drawn: [.stone: 6, .wood: 4, .leaves: 3, .water: 2,
                                        .field: 3, .brick: 2],
                                turnsPlayed: 6, players: 3, seat: 0)
        return try #require(Search.best(from: state, cores: 1))
    }

    /// A suggestion put together by hand, with one term of every kind the
    /// engine has — the search names only the three largest, and which those
    /// are depends on the position.
    private func handMade() -> Suggestion {
        let move = Move(space: 0, placements: [12: [.stone]])
        return Suggestion(
            move: move, value: 20, pointsNow: 9,
            terms: [
                Term(name: "Landschaften", points: 9, kind: .points),
                Term(name: "Aussicht Erdmännchen", points: 2.38, kind: .prospect,
                     gain: 7, chance: 0.4, detail: "7 Punkte × 40 %"),
                Term(name: "Berge", points: 1.2, kind: .prospect,
                     detail: "1 Berg ohne Bergnachbarn"),
                Term(name: "Freie Kartenplätze", points: 6, kind: .steering,
                     detail: "3 frei, 9 Züge Rest"),
            ],
            runnerUp: Move(space: 0, placements: [13: [.stone]]),
            runnerUpValue: 19, runnerUpPointsNow: 4, weighed: 2, complete: true)
    }

    @Test("Punkte bleiben Punkte, Erwartungen bleiben Erwartungen")
    func pointsStayPointsAndExpectationsStayExpectations() {
        let kinds = Dictionary(uniqueKeysWithValues:
            handMade().asRationale.terms.map { ($0.name, $0.kind) })
        #expect(kinds["Landschaften"] == .points)
        #expect(kinds["Aussicht Erdmännchen"] == .prospect)
        #expect(kinds["Berge"] == .prospect)
        #expect(kinds["Freie Kartenplätze"] == .steering)
    }

    @Test("Eine Aussicht trägt ihren Gewinn und ihre Wahrscheinlichkeit als Zahlen")
    func anOutlookCarriesItsGainAndChanceAsNumbers() throws {
        let terms = handMade().asRationale.terms
        let outlook = try #require(terms.first { $0.name == "Aussicht Erdmännchen" })
        #expect(outlook.gain == 7)
        #expect(outlook.probability == 0.4)
        // What came of it stays what the engine counted — not counted twice.
        #expect(outlook.points == 2)

        let sleeping = try #require(terms.first { $0.name == "Berge" })
        #expect(sleeping.gain == nil)
        #expect(sleeping.probability == nil)
    }

    @Test("Die Alternative nennt ihre eigenen Punkte, nicht null")
    func theAlternativeNamesItsOwnPoints() throws {
        let suggestion = try suggestion()
        let rationale = suggestion.asRationale
        #expect(suggestion.runnerUp != nil)
        #expect(rationale.runnerUpImmediate == suggestion.runnerUpPointsNow)
        #expect(rationale.immediate == suggestion.pointsNow)
    }

    // MARK: - On disk

    @Test("Art und Gewinn überstehen das Speichern")
    func kindAndGainSurviveSaving() throws {
        let term = ScoreTerm(name: "Aussicht X", points: 2, kind: .prospect,
                             gain: 7, probability: 0.4)
        let rationale = MoveRationale(immediate: 1, value: 2, terms: [term],
                                      runnerUp: "—", runnerUpImmediate: 3,
                                      runnerUpValue: 1, gapExplanation: "")
        let saved = SavedRationale(rationale)
        let data = try JSONEncoder().encode(saved)
        let restored = try JSONDecoder().decode(SavedRationale.self, from: data).restored

        #expect(restored.terms.first?.kind == .prospect)
        #expect(restored.terms.first?.gain == 7)
        #expect(restored.terms.first?.probability == 0.4)
        #expect(restored.runnerUpImmediate == 3)
    }

    @Test("Ein älterer Spielstand ohne Art wird nach seinem Aussichts-Merkmal gelesen")
    func anOlderFileWithoutAKindIsReadByItsProspectFlag() throws {
        let json = #"{"name":"Fluss","points":3,"prospect":true,"probability":0.5}"#
        let term = try JSONDecoder().decode(SavedTerm.self, from: Data(json.utf8))
        let restored = SavedRationale(immediate: 0, value: 0, terms: [term], probabilityNote: nil,
                                      runnerUp: "", runnerUpImmediate: 0, runnerUpValue: 0,
                                      gapExplanation: "").restored
        #expect(restored.terms.first?.kind == .prospect)
        #expect(restored.terms.first?.gain == nil)
    }
}
