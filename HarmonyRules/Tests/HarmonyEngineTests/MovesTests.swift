import Testing
import HarmonyRules
@testable import HarmonyEngine

/// The turns the engine offers. What matters is that none is missing, none
/// is offered twice, and none is offered that the rules forbid.
@Suite("Zuggenerierung")
struct MovesTests {
    private func card(_ name: String, _ pattern: [Int: PatternCell],
                      cube: Int, _ points: [Int] = [4, 9]) -> AnimalCard {
        AnimalCard(name: name, pattern: pattern, cube: cube, points: points)
    }

    /// A board with only a few spaces left open, so a test can count by
    /// hand. Everything not named is filled with water, which nothing stacks
    /// on; `filled` puts something definite on a space instead.
    private func position(empty: Set<Int>, filled: [Int: [Stone]] = [:],
                          side: BoardSide = .a) -> [Int: [Stone]] {
        var stacks: [Int: [Stone]] = [:]
        for cell in side.board.cells where !empty.contains(cell) && filled[cell] == nil {
            stacks[cell] = [.water]
        }
        for (cell, stack) in filled { stacks[cell] = stack }
        return stacks
    }

    // MARK: - Die Steine

    @Test("Drei Steine auf zwei freie Felder: jede erreichbare Stellung genau einmal")
    func threeStonesOntoTwoFreeSpacesEachReachableTableExactlyOnce() {
        // Frei sind 11 und 12. Die drei Steine sind Grau, Grau, Grau — auf
        // ein Feld passen höchstens drei, also: 3+0, 2+1, 1+2, 0+3.
        let state = EngineState(stacks: position(empty: [11, 12]),
                                display: [[.stone, .stone, .stone]])
        let boards = Moves.boards(placing: [.stone, .stone, .stone], on: state)
        #expect(boards.count == 4)
        let shapes = boards.map { ($0.added[11]?.count ?? 0, $0.added[12]?.count ?? 0) }
        #expect(Set(shapes.map { "\($0.0)/\($0.1)" }) == ["3/0", "2/1", "1/2", "0/3"])
    }

    @Test("Was die Stapelregeln verbieten, wird nicht angeboten")
    func whatTheStackRulesForbidIsNotOffered() {
        // Drei braune Steine übereinander gibt es nicht, also fehlt 3/0.
        let state = EngineState(stacks: position(empty: [11, 12]),
                                display: [[.wood, .wood, .wood]])
        let boards = Moves.boards(placing: [.wood, .wood, .wood], on: state)
        #expect(!boards.contains { $0.added[11]?.count == 3 })
        #expect(!boards.contains { $0.added[12]?.count == 3 })
    }

    @Test("Auf ein Feld mit Würfel wird nichts gelegt")
    func nothingGoesOnASpaceWithACube() {
        let state = EngineState(stacks: position(empty: [11], filled: [12: [.stone]]),
                                cubes: [12: "Prüftier"],
                                hand: [HeldCard(card: card("Prüftier", [11: .field, 12: .mountain1],
                                                           cube: 12), cubesPlaced: 1)],
                                display: [[.stone, .stone, .stone]])
        let boards = Moves.boards(placing: [.stone, .stone, .stone], on: state)
        #expect(boards.allSatisfy { $0.added[12] == nil })
    }

    @Test("Gleiche Auslagenfelder sind ein Zug, nicht zwei")
    func identicalDisplaySpacesAreOneMoveNotTwo() {
        // Die Auslage ist eine Mehrfachmenge; zwei gleiche Felder sind
        // austauschbar, siehe `04-architektur.md`.
        let twice = EngineState(stacks: position(empty: [11, 12]),
                                display: [[.stone, .stone, .stone], [.stone, .stone, .stone]])
        let once = EngineState(stacks: position(empty: [11, 12]),
                               display: [[.stone, .stone, .stone]])
        #expect(Moves.all(from: twice).count == Moves.all(from: once).count)
        #expect(Moves.all(from: twice).allSatisfy { $0.space == 0 })
    }

    @Test("Verschiedene Auslagenfelder sind verschiedene Züge")
    func differentDisplaySpacesAreDifferentMoves() {
        // Drei Wassersteine brauchen drei freie Felder — auf Blau wird nie
        // gestapelt.
        let state = EngineState(stacks: position(empty: [11, 12, 13]),
                                display: [[.stone, .stone, .stone], [.water, .water, .water]])
        #expect(Set(Moves.all(from: state).map(\.space)) == [0, 1])
    }

    @Test("Kein Zug wird zweimal angeboten")
    func nomoveIsOfferedTwice() {
        let state = EngineState(stacks: position(empty: [11, 12, 13]),
                                display: [[.stone, .wood, .leaves]])
        let moves = Moves.all(from: state)
        #expect(Set(moves).count == moves.count)
    }

    // MARK: - Die Karte

    @Test("Eine Karte nehmen oder keine")
    func takeACardOrNone() {
        let state = EngineState(stacks: position(empty: [11, 12]),
                                display: [[.stone, .stone, .stone]],
                                openCards: [card("Otter", [11: .field, 12: .field], cube: 12),
                                            card("Hase", [11: .field, 12: .field], cube: 12)])
        let moves = Moves.all(from: state)
        #expect(Set(moves.map { $0.cardTaken ?? "—" }) == ["—", "Otter", "Hase"])
    }

    @Test("Bei vier unabgeschlossenen Karten wird keine fünfte genommen")
    func nofifthCardIsTakenWhileFourAreUnfinished() {
        let open = (1...4).map {
            HeldCard(card: card("Offen\($0)", [11: .field, 12: .field], cube: 12), cubesPlaced: 0)
        }
        let state = EngineState(stacks: position(empty: [11, 12]),
                                hand: open,
                                display: [[.stone, .stone, .stone]],
                                openCards: [card("Fünfte", [11: .field, 12: .field], cube: 12)])
        #expect(Moves.all(from: state).allSatisfy { $0.cardTaken == nil })
    }

    // MARK: - Die Würfel

    @Test("Ein Würfel wird gesetzt, wenn der Zug sein Muster vollendet")
    func acubeGoesDownWhenTheTurnCompletesItsPattern() {
        // Feld auf 11 liegt schon, der Zug legt den Berg auf 12.
        let meerkat = card("Erdmännchen", [11: .field, 12: .mountain1], cube: 12, [2, 5])
        let state = EngineState(stacks: position(empty: [12, 13, 14], filled: [11: [.field]]),
                                hand: [HeldCard(card: meerkat)],
                                display: [[.stone, .water, .water]])
        let moves = Moves.all(from: state)
        #expect(moves.contains { $0.placements[12] == [.stone] && $0.cubes[12] == "Erdmännchen" })
        // Und der Zug ohne Würfel steht daneben: ein Feld einzufrieren kann
        // teurer sein als die Punkte jetzt.
        #expect(moves.contains { $0.placements[12] == [.stone] && $0.cubes.isEmpty })
    }

    @Test("Eine Karte, die dieser Zug nimmt, kann im selben Zug ihren Würfel bekommen")
    func acardTakenThisTurnCanGetItsCubeInTheSameTurn() {
        let meerkat = card("Erdmännchen", [11: .field, 12: .mountain1], cube: 12, [2, 5])
        let state = EngineState(stacks: position(empty: [12, 13, 14], filled: [11: [.field]]),
                                display: [[.stone, .water, .water]],
                                openCards: [meerkat])
        #expect(Moves.all(from: state).contains {
            $0.cardTaken == "Erdmännchen" && $0.cubes[12] == "Erdmännchen"
        })
    }

    @Test("Auf dem Würfelfeld selbst wird nicht weitergebaut")
    func nothingIsBuiltOnTheCubeSpaceItself() {
        // Der Berg der Höhe 1 nimmt den Würfel auf 12 — dann darf 12 in
        // demselben Zug nicht auf Höhe 2 wachsen, der Würfel läge im Weg.
        let meerkat = card("Erdmännchen", [11: .field, 12: .mountain1], cube: 12, [2, 5])
        let state = EngineState(stacks: position(empty: [12, 13, 14], filled: [11: [.field]]),
                                hand: [HeldCard(card: meerkat)],
                                display: [[.stone, .stone, .water]])
        let moves = Moves.all(from: state)
        #expect(!moves.contains { $0.placements[12] == [.stone, .stone] && $0.cubes[12] != nil })
        #expect(moves.contains { $0.placements[12] == [.stone, .stone] && $0.cubes.isEmpty })
    }

    @Test("Der Würfel des kleinen Bergs wird gesetzt, während der Berg im selben Zug weiterwächst")
    func thesmallMountainsCubeGoesDownWhileTheMountainGrowsOn() {
        // Die Feinheit aus `regeln-basisspiel.md`: Stein, Würfel, Stein.
        // Der Würfel des Erdmännchens liegt auf 11, nicht auf dem Berg, also
        // darf 12 danach auf Höhe 2 wachsen und den Adler bedienen.
        let meerkat = card("Erdmännchen", [11: .field, 12: .mountain1], cube: 11, [2, 5])
        let eagle = card("Adler", [13: .field, 12: .mountain2], cube: 13, [5, 11])
        let state = EngineState(stacks: position(empty: [12, 14, 15],
                                                 filled: [11: [.field], 13: [.field]]),
                                hand: [HeldCard(card: meerkat), HeldCard(card: eagle)],
                                display: [[.stone, .stone, .water]])
        let moves = Moves.all(from: state)
        // Beide Würfel in einem Zug, und der Berg steht am Ende auf Höhe 2.
        #expect(moves.contains {
            $0.placements[12] == [.stone, .stone]
                && $0.cubes[11] == "Erdmännchen" && $0.cubes[13] == "Adler"
        })
    }

    @Test("Liegt der Würfel auf dem Berg, geht beides nicht zugleich")
    func iftheCubeSitsOnTheMountainTheTwoDoNotGoTogether() {
        // Dieselbe Stellung, nur liegt der Würfel des Erdmännchens jetzt auf
        // dem Berg selbst. Dann friert er ihn ein.
        let meerkat = card("Erdmännchen", [11: .field, 12: .mountain1], cube: 12, [2, 5])
        let eagle = card("Adler", [13: .field, 12: .mountain2], cube: 13, [5, 11])
        let state = EngineState(stacks: position(empty: [12, 14, 15],
                                                 filled: [11: [.field], 13: [.field]]),
                                hand: [HeldCard(card: meerkat), HeldCard(card: eagle)],
                                display: [[.stone, .stone, .water]])
        let moves = Moves.all(from: state)
        #expect(!moves.contains { $0.cubes[12] != nil && $0.cubes[13] != nil })
        // Eines von beiden geht sehr wohl.
        #expect(moves.contains { $0.cubes[12] == "Erdmännchen" })
        #expect(moves.contains { $0.cubes[13] == "Adler" })
    }

    // MARK: - Determinismus

    @Test("Zweimal dieselbe Stellung gibt zweimal dieselbe Liste")
    func thesamePositionTwiceGivesTheSameListTwice() {
        let state = EngineState(stacks: position(empty: [11, 12, 13]),
                                display: [[.stone, .wood, .leaves]],
                                openCards: [card("Otter", [11: .field, 12: .field], cube: 12)])
        #expect(Moves.all(from: state) == Moves.all(from: state))
    }
}
