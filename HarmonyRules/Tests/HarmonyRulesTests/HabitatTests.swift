import Testing
@testable import HarmonyRules

/// Where a pattern lies, where it could still come to lie, and whether two
/// such places get along. Small positions, each aimed at one rule, the way
/// `pruefverfahren.md` asks for storey one.
@Suite("Lebensräume")
struct HabitatTests {
    private let board = BoardSide.a.board

    /// A made-up card. The real ones are checked elsewhere; here what matters
    /// is the shape of the question, not which animal asks it.
    private func card(_ pattern: [Int: PatternCell], cube: Int,
                      named name: String = "Prüftier") -> AnimalCard {
        AnimalCard(name: name, pattern: pattern, cube: cube, points: [3, 7])
    }

    /// A placement built by hand, for the cases about two of them at once.
    /// What is still missing comes from `waysTo`, so the fixture does not
    /// carry its own copy of that reasoning.
    private func placement(_ requirement: [Int: PatternCell], cube: Int,
                           on stacks: [Int: [Stone]] = [:]) -> Habitat {
        var missing: [Int: [[Stone]]] = [:]
        for (cell, wanted) in requirement {
            let stack = stacks[cell] ?? []
            if !wanted.stacks.contains(stack) { missing[cell] = stack.waysTo(wanted) }
        }
        return Habitat(card: card(requirement, cube: cube),
                       requirement: requirement, cubeCell: cube, missing: missing)
    }

    // MARK: - Was eine Landschaft verlangt

    @Test("Jede Landschaft außer dem Gebäude verlangt genau einen Stapel")
    func everyLandscapeButTheBuildingWantsExactlyOneStack() {
        for cell in PatternCell.allCases where cell != .building {
            #expect(cell.stacks.count == 1, "\(cell.rawValue): \(cell.stacks)")
        }
    }

    @Test("Das Gebäude nimmt Rot, Braun oder Grau als Unterbau")
    func theBuildingTakesRedBrownOrGreyUnderneath() {
        // `kartennotation.md`: welcher Stein unten liegt, ist dem Muster
        // gleichgültig — die drei zulässigen Zweierstapel mit Rot oben.
        #expect(PatternCell.building.stacks.count == 3)
        for stack in PatternCell.building.stacks {
            #expect(stack.count == 2 && stack.last == .brick)
        }
    }

    @Test("Ein Stapel kann nur wachsen, und nur auf bestimmten Wegen")
    func aStackOnlyGrowsAndOnlyAlongCertainWays() {
        #expect([Stone]().waysTo(.tree3) == [[.wood, .wood, .leaves]])
        #expect([Stone.wood].waysTo(.tree3) == [[.wood, .leaves]])
        #expect([Stone.wood, .wood].waysTo(.tree3) == [[.leaves]])
        // Grau wird kein Baum mehr, und auf Blau kommt gar nichts.
        #expect([Stone.stone].waysTo(.tree3).isEmpty)
        #expect([Stone.water].waysTo(.mountain1).isEmpty)
        // Zu hoch gebaut ist ebenso endgültig.
        #expect([Stone.stone, .stone].waysTo(.mountain1).isEmpty)
    }

    // MARK: - Fundstellen

    @Test("Ein fertiges Muster wird gefunden")
    func afinishedPatternIsFound() {
        let pair = card([11: .field, 12: .mountain1], cube: 12)
        let found = Habitat.complete(of: pair, on: [11: [.field], 12: [.stone]], board: board)
        #expect(found.count == 1)
        #expect(found.first?.cubeCell == 12)
    }

    @Test("Jedes Nachbarpaar des Spielplans trägt das Muster in einer der sechs Lagen")
    func everyNeighbouringPairCarriesThePatternInOneOfSixOrientations() {
        // Die schärfste Aussage über die Drehungen, die sich billig machen
        // lässt: Zwei benachbarte Felder stehen in genau einer der sechs
        // Richtungen zueinander, also muss das Muster überall genau einmal
        // passen — sonst fehlt eine Drehung oder es gibt eine zu viel.
        let pair = card([11: .field, 12: .mountain1], cube: 12)
        for cell in board.cells {
            for neighbour in board.neighbours(cell) {
                let stacks: [Int: [Stone]] = [cell: [.field], neighbour: [.stone]]
                let found = Habitat.complete(of: pair, on: stacks, board: board)
                #expect(found.count == 1,
                        "\(cellName(cell)) / \(cellName(neighbour)): \(found.count) Fundstellen")
                #expect(found.first?.cubeCell == neighbour)
            }
        }
    }

    @Test("Ein Stein kann zu mehreren Lebensräumen gehören")
    func oneStoneCanBelongToSeveralHabitats() {
        // `regeln-basisspiel.md` sagt es ausdrücklich; hier dient derselbe
        // Berg zwei Karten, die sich nur im zweiten Feld unterscheiden.
        let stacks: [Int: [Stone]] = [12: [.stone], 11: [.field], 13: [.water]]
        let withField = card([11: .field, 12: .mountain1], cube: 12, named: "Feldtier")
        let withWater = card([11: .water, 12: .mountain1], cube: 12, named: "Wassertier")
        #expect(Habitat.complete(of: withField, on: stacks, board: board).count == 1)
        #expect(Habitat.complete(of: withWater, on: stacks, board: board).count == 1)
    }

    // MARK: - Anwärter

    @Test("Einem Anwärter fehlt ein Stein, und er sagt welchen")
    func acandidateIsMissingOneStoneAndSaysWhich() {
        let pair = card([11: .field, 12: .mountain1], cube: 12)
        let all = Habitat.all(of: pair, on: [11: [.field]], board: board)
        let onTheField = all.filter { $0.requirement[11] == .field && $0.requirement[12] == .mountain1 }
        #expect(onTheField.count == 1)
        #expect(onTheField.first?.isComplete == false)
        #expect(onTheField.first?.missing[12] == [[.stone]])
        #expect(onTheField.first?.missingStoneCount == 1)
    }

    @Test("Wo Wasser liegt, wird kein Berg mehr")
    func nothingBecomesAMountainWhereWaterLies() {
        let pair = card([11: .field, 12: .mountain1], cube: 12)
        let all = Habitat.all(of: pair, on: [12: [.water]], board: board)
        #expect(!all.contains { $0.requirement[12] == .mountain1 })
        // Als Wasserfeld eines anderen Musters taugt dieselbe Zelle sehr wohl.
        let wet = card([11: .water, 12: .mountain1], cube: 12)
        #expect(Habitat.all(of: wet, on: [12: [.water]], board: board)
                    .contains { $0.requirement[12] == .water })
    }

    @Test("Ein Würfel friert sein Feld ein")
    func acubeFreezesItsSpace() {
        // Nichts kommt auf einen Stein, der einen Tierwürfel trägt. Ein
        // Anwärter, der dieses Feld höher haben will, ist damit tot.
        let taller = card([11: .field, 12: .mountain2], cube: 11)
        let free = Habitat.all(of: taller, on: [12: [.stone]], cubes: [], board: board)
        let frozen = Habitat.all(of: taller, on: [12: [.stone]], cubes: [12], board: board)
        #expect(free.contains { $0.requirement[12] == .mountain2 })
        #expect(!frozen.contains { $0.requirement[12] == .mountain2 })
    }

    @Test("Auf ein besetztes Zielfeld kommt kein zweiter Würfel")
    func nosecondCubeGoesOnAnOccupiedTarget() {
        let pair = card([11: .field, 12: .mountain1], cube: 12)
        let stacks: [Int: [Stone]] = [11: [.field], 12: [.stone]]
        #expect(Habitat.complete(of: pair, on: stacks, board: board).count == 1)
        #expect(Habitat.complete(of: pair, on: stacks, cubes: [12], board: board).isEmpty)
    }

    // MARK: - Verträglichkeit

    @Test("Nur Berge gehen ineinander über, und der Berg ins Gebäude")
    func onlyMountainsRunIntoEachOtherAndIntoTheBuilding() {
        var pairs: [String] = []
        for a in PatternCell.allCases {
            for b in PatternCell.allCases where a.canPrecede(b) {
                pairs.append("\(a.rawValue)<\(b.rawValue)")
            }
        }
        #expect(Set(pairs) == ["Berg1<Berg2", "Berg1<Berg3", "Berg2<Berg3", "Berg1<Gebäude"],
                "\(pairs.sorted())")
    }

    @Test("Berg1 und Berg2 auf demselben Feld vertragen sich, in dieser Reihenfolge")
    func mountainsOfOneAndTwoGetAlongInThatOrder() {
        // Der erste Würfel liegt auf einem anderen Feld des Musters, das Feld
        // bleibt also frei zum Weiterbauen. Das erste Habitat geht dabei
        // kaputt — sein Würfel liegt längst und wird nie zurückgenommen.
        let small = placement([22: .mountain1, 23: .field], cube: 23)
        let large = placement([22: .mountain2, 21: .field], cube: 21)
        #expect(Habitat.compatibility(small, large) == .ordered(.aFirst))
        #expect(Habitat.compatibility(large, small) == .ordered(.bFirst))
    }

    @Test("Liegt der erste Würfel auf dem Berg selbst, vertragen sie sich nicht")
    func theyDoNotGetAlongIfTheFirstCubeSitsOnTheMountainItself() {
        let small = placement([22: .mountain1, 23: .field], cube: 22)
        let large = placement([22: .mountain2, 21: .field], cube: 21)
        #expect(Habitat.compatibility(small, large) == .conflict)
    }

    @Test("Zwei Bäume verschiedener Höhe schließen einander aus")
    func twoTreesOfDifferentHeightExcludeEachOther() {
        // `Baum1` ist ein grüner Stein auf nichts, `Baum2` will einen braunen
        // darunter — der lässt sich nicht mehr unterschieben.
        let low = placement([22: .tree1, 23: .field], cube: 23)
        let high = placement([22: .tree2, 21: .field], cube: 21)
        #expect(Habitat.compatibility(low, high) == .conflict)
    }

    @Test("Wasser verträgt sich mit nichts anderem")
    func waterGetsAlongWithNothingElse() {
        let wet = placement([22: .water, 23: .field], cube: 23)
        for other in PatternCell.allCases where other != .water {
            let dry = placement([22: other, 21: .field], cube: 21)
            #expect(Habitat.compatibility(wet, dry) == .conflict, "\(other.rawValue)")
        }
    }

    @Test("Gleiche Forderung auf geteiltem Feld ist verträglich ohne Reihenfolge")
    func thesameDemandOnASharedSpaceNeedsNoOrder() {
        let one = placement([22: .mountain1, 23: .field], cube: 23)
        let two = placement([22: .mountain1, 21: .water], cube: 21)
        #expect(Habitat.compatibility(one, two) == .compatible)
    }

    @Test("Ohne geteiltes Feld gibt es nichts zu regeln")
    func withoutASharedSpaceThereIsNothingToSettle() {
        let here = placement([11: .field, 12: .mountain1], cube: 12)
        let there = placement([54: .water, 55: .field], cube: 55)
        #expect(Habitat.compatibility(here, there) == .compatible)
    }

    // MARK: - Synergie

    @Test("Geteilte Felder werden einmal bezahlt, nicht zweimal")
    func sharedSpacesArePaidOnceNotTwice() {
        let a = placement([33: .mountain1, 34: .field], cube: 34)
        let b = placement([33: .mountain1, 23: .field], cube: 23)
        #expect(a.missingStoneCount == 2)
        #expect(b.missingStoneCount == 2)
        // Der Berg steht in beiden Mustern und kostet trotzdem nur einmal.
        #expect(Habitat.missingStoneCount(for: [a, b], on: [:]) == 3)
    }

    @Test("Ein wachsendes Feld wird auf seine volle Höhe bezahlt, nicht doppelt")
    func agrowingSpaceIsPaidToItsFullHeightAndNotTwice() {
        let small = placement([22: .mountain1, 23: .field], cube: 23)
        let large = placement([22: .mountain2, 21: .field], cube: 21)
        // Zusammen: zwei Steine für den Berg der Höhe 2, dazu zwei Felder.
        #expect(Habitat.missingStoneCount(for: [small, large], on: [:]) == 4)
        // Einzeln gerechnet wären es fünf.
        #expect(small.missingStoneCount + large.missingStoneCount == 5)
    }

    @Test("Eine unverträgliche Menge hat keine Kosten, sondern gar keinen Wert")
    func anincompatibleSetHasNoCostButNoValueEither() {
        let low = placement([22: .tree1, 23: .field], cube: 23)
        let high = placement([22: .tree2, 21: .field], cube: 21)
        #expect(Habitat.missingStoneCount(for: [low, high], on: [:]) == nil)
        #expect(Habitat.combinedRequirement([low, high]) == nil)
    }

    // MARK: - An den echten Karten

    @Test("Auf leerem Brett hat jede der zweiunddreißig Karten Anwärter")
    func onanEmptyBoardEveryOneOfTheThirtyTwoHasCandidates() throws {
        for card in try AnimalCards.load() {
            let all = Habitat.all(of: card, on: [:], board: board)
            #expect(!all.isEmpty, "\(card.name)")
            #expect(all.allSatisfy { !$0.isComplete }, "\(card.name): fertig auf leerem Brett")
        }
    }

    @Test("Zweimal dieselbe Frage gibt zweimal dieselbe Antwort")
    func thesameQuestionTwiceGivesTheSameAnswerTwice() throws {
        // Determinismus, den die Momentaufnahmen aus `pruefverfahren.md`
        // brauchen: gleiche Stellung, gleiche Reihenfolge der Fundstellen.
        let card = try AnimalCards.load().first { $0.name == "Erdmännchen" }!
        let stacks: [Int: [Stone]] = [11: [.field], 22: [.stone], 33: [.field]]
        let once = Habitat.all(of: card, on: stacks, board: board)
        let again = Habitat.all(of: card, on: stacks, board: board)
        #expect(once == again)
        #expect(once.map(\.cubeCell) == again.map(\.cubeCell))
    }
}
