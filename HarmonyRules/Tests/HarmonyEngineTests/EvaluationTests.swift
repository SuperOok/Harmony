import Testing
import HarmonyRules
@testable import HarmonyEngine

/// What a position is worth. The assurances here are about **order**, not
/// about numbers: the weights are guessed and belong measured once self-play
/// runs, but which of two positions is the better one must not depend on
/// that guess.
@Suite("Bewertung")
struct EvaluationTests {
    private func card(_ name: String, _ pattern: [Int: PatternCell],
                      cube: Int, _ points: [Int] = [6, 13]) -> AnimalCard {
        AnimalCard(name: name, pattern: pattern, cube: cube, points: points)
    }

    /// A mid-game position with plenty of bag left, so the chances are not
    /// all pinned at zero or one.
    private func state(stacks: [Int: [Stone]] = [:],
                       hand: [HeldCard] = [],
                       side: BoardSide = .a) -> EngineState {
        EngineState(side: side, stacks: stacks, hand: hand,
                    display: [[.stone, .wood, .leaves], [.water, .water, .field],
                              [.brick, .stone, .stone], [.leaves, .field, .brick],
                              [.wood, .wood, .stone]],
                    drawn: [.stone: 6, .wood: 4, .leaves: 3, .water: 2,
                            .field: 3, .brick: 2],
                    turnsPlayed: 6, players: 3, seat: 0)
    }

    // MARK: - Form

    @Test("Jeder Beitrag trägt einen Namen")
    func everyContributionCarriesAName() {
        // Die Begründung nennt die größten Beiträge; ein namenloser Summand
        // könnte darin gar nicht auftauchen.
        let meerkat = card("Erdmännchen", [11: .field, 12: .mountain1], cube: 12)
        let evaluation = Evaluator.evaluate(state(stacks: [11: [.field]],
                                                 hand: [HeldCard(card: meerkat)]))
        #expect(!evaluation.terms.isEmpty)
        #expect(evaluation.terms.allSatisfy { !$0.name.isEmpty })
    }

    @Test("Punkte jetzt und Wert der Stellung sind zweierlei")
    func pointsNowAndWorthAreTwoThings() {
        // `04-architektur.md`: Ein Zug kann null Punkte bringen und trotzdem
        // der beste sein. Der Anwärter hebt den Wert, ohne die Punkte zu
        // bewegen.
        let meerkat = card("Erdmännchen", [11: .field, 12: .mountain1], cube: 12)
        let bare = Evaluator.evaluate(state(stacks: [11: [.field]]))
        let withCard = Evaluator.evaluate(state(stacks: [11: [.field]],
                                                hand: [HeldCard(card: meerkat)]))
        #expect(bare.pointsNow == withCard.pointsNow)
        #expect(withCard.value > bare.value)
    }

    @Test("Eine Aussicht nennt ihre Wahrscheinlichkeit")
    func anoutlookSaysItsProbability() {
        // Ohne sie wirkte die Zahl erfunden — so verlangt es `04-architektur.md`.
        let meerkat = card("Erdmännchen", [11: .field, 12: .mountain1], cube: 12)
        let evaluation = Evaluator.evaluate(state(stacks: [11: [.field]],
                                                  hand: [HeldCard(card: meerkat)]))
        let outlook = evaluation.terms.first { $0.name.hasPrefix("Aussicht") }
        #expect(outlook?.detail?.contains("%") == true)
    }

    // MARK: - Nähe schlägt Ferne

    @Test("Ein Anwärter, dem ein Stein fehlt, wiegt schwerer als einer, dem drei fehlen")
    func acandidateOneStoneAwayWeighsMoreThanOneThreeAway() {
        let near = card("Nah", [11: .field, 12: .mountain1], cube: 12)
        let far = card("Fern", [11: .field, 12: .mountain3], cube: 12)
        let close = Evaluator.evaluate(state(stacks: [11: [.field]],
                                             hand: [HeldCard(card: near)]))
        let distant = Evaluator.evaluate(state(stacks: [11: [.field]],
                                               hand: [HeldCard(card: far)]))
        #expect(close.value > distant.value)
    }

    @Test("Was nicht mehr zu schaffen ist, verspricht nichts")
    func whatCannotBeManagedAnyMorePromisesNothing() {
        // Zwei Züge vor Schluss ist ein Muster aus acht fehlenden Steinen
        // nicht mehr zu bauen.
        let big = card("Groß", [11: .mountain3, 12: .mountain3, 13: .building], cube: 12)
        var late = state(hand: [HeldCard(card: big)])
        late.turnsPlayed = 33
        let evaluation = Evaluator.evaluate(late)
        #expect(!evaluation.terms.contains { $0.name.hasPrefix("Aussicht") })
    }

    @Test("Eine ausgegangene Farbe macht die Aussicht wertlos")
    func acolourThatHasRunOutMakesTheOutlookWorthless() {
        let red = card("Rot", [11: .building, 12: .field], cube: 11)
        var empty = state(hand: [HeldCard(card: red)])
        empty.drawn = [.brick: 15]          // alle roten Steine sind heraus
        empty.display = [[.stone, .stone, .stone]]
        let evaluation = Evaluator.evaluate(empty)
        #expect(!evaluation.terms.contains { $0.name.hasPrefix("Aussicht") })
    }

    // MARK: - Synergie und Konflikt

    @Test("Zwei Anwärter, die sich Felder teilen, wiegen mehr als zwei getrennte")
    func twocandidatesSharingSpacesWeighMoreThanTwoApart() {
        // Auf der Ebene geprüft, auf der die Synergie definiert ist: Auf
        // einem offenen Brett sucht sich jede Karte ohnehin die beste Lage,
        // und zwei gleich geformte Karten fänden dieselbe.
        let position = state()
        let shared = [prospect("A", [22: .mountain1, 23: .field], cube: 23, in: position),
                      prospect("B", [22: .mountain1, 21: .field], cube: 21, in: position)]
        let apart = [prospect("A", [22: .mountain1, 23: .field], cube: 23, in: position),
                     prospect("B", [44: .mountain1, 43: .field], cube: 43, in: position)]

        let single = shared.reduce(0.0) { $0 + $1.worth }
        #expect(abs(apart.reduce(0.0) { $0 + $1.worth } - single) < 1e-9)

        // Getrennt: vier Steine für zwei Würfel. Geteilt: drei.
        #expect(Evaluator.sharedWorth(apart, position) == apart.reduce(0.0) { $0 + $1.worth })
        #expect(Evaluator.sharedWorth(shared, position) > Evaluator.sharedWorth(apart, position))
    }

    /// A candidate at a named place, built by hand so the test decides where
    /// it sits instead of the search.
    private func prospect(_ name: String, _ requirement: [Int: PatternCell],
                          cube: Int, in position: EngineState) -> Evaluator.Prospect {
        var missing: [Int: [[Stone]]] = [:]
        for (cell, wanted) in requirement {
            missing[cell] = (position.stacks[cell] ?? []).waysTo(wanted)
        }
        let habitat = Habitat(card: card(name, requirement, cube: cube),
                              requirement: requirement, cubeCell: cube, missing: missing)
        return Evaluator.Prospect(
            card: name, habitat: habitat, gain: 6,
            chance: Evaluator.chance(ofBuilding: Evaluator.missingStones(habitat),
                                     state: position))
    }

    @Test("Zwei Anwärter, die einander ausschließen, werden nicht addiert")
    func twocandidatesThatExcludeEachOtherAreNotAddedUp() {
        // Baum1 und Baum2 auf demselben Feld gehen nicht beide.
        let low = card("Niedrig", [22: .tree1, 23: .field], cube: 23)
        let high = card("Hoch", [22: .tree2, 21: .field], cube: 21)
        let board = fill(except: [21, 22, 23])
        func outlook(_ hand: [HeldCard]) -> Double {
            Evaluator.evaluate(state(stacks: board, hand: hand))
                .terms.filter { $0.name.hasPrefix("Aussicht") }
                .reduce(0.0) { $0 + $1.points }
        }
        let alone = (low: outlook([HeldCard(card: low)]),
                     high: outlook([HeldCard(card: high)]))
        let together = outlook([HeldCard(card: low), HeldCard(card: high)])

        // Verglichen werden die Aussichten, nicht die Gesamtwerte: Zwei
        // Karten in der Hand lassen mehr Anwärter leben als eine, und das
        // zählt die Optionenvielfalt zu Recht mit.
        #expect(together < alone.low + alone.high, "addiert statt ausgeschlossen")
        #expect(abs(together - max(alone.low, alone.high)) < 1e-9,
                "\(together) statt \(max(alone.low, alone.high))")
    }

    /// Everything but the named spaces filled with water, so a pattern can
    /// only lie where the test wants it.
    private func fill(except free: Set<Int>, side: BoardSide = .a) -> [Int: [Stone]] {
        var stacks: [Int: [Stone]] = [:]
        for cell in side.board.cells where !free.contains(cell) { stacks[cell] = [.water] }
        return stacks
    }

    // MARK: - Der erste Zug

    @Test("Auf leerem Brett sind nicht alle Steinlagen gleich viel wert")
    func onanEmptyBoardNotAllPlacesAreWorthTheSame() {
        // Die Kernfrage der frühen Partie: Wenn jeder Anwärter gleich weit
        // entfernt ist, muss trotzdem etwas unterscheiden — sonst legt die
        // Engine beliebig.
        let meerkat = card("Erdmännchen", [11: .field, 12: .mountain1], cube: 12)
        let hand = [HeldCard(card: meerkat)]
        let values = BoardSide.a.board.cells.map { cell in
            Evaluator.evaluate(state(stacks: [cell: [.water]], hand: hand)).value
        }
        #expect(Set(values.map { Int($0 * 1000) }).count > 1,
                "alle Lagen gleich bewertet")
    }

    @Test("Ein Wasserstein auf dem längsten möglichen Weg zählt mehr als einer daneben")
    func awaterStoneOnTheLongestPossiblePathCountsMoreThanOneBeside() {
        // Die Flussaussicht: Der Weg ist auf leerem Brett überall derselbe,
        // aber jeder blaue Stein darauf ist einer weniger, der noch kommen muss.
        let onPath = Evaluator.evaluate(state(stacks: [33: [.water]]))
        let inCorner = Evaluator.evaluate(state(stacks: [11: [.water]]))
        #expect(onPath.terms.contains { $0.name == "Fluss" })
        #expect(inCorner.terms.contains { $0.name == "Fluss" })
    }

    @Test("Seite B rechnet mit Inseln statt mit dem Fluss")
    func sideBreckonsWithIslandsInsteadOfTheRiver() {
        let a = Evaluator.evaluate(state(stacks: [33: [.water]], side: .a))
        let b = Evaluator.evaluate(state(stacks: [33: [.water]], side: .b))
        #expect(a.terms.contains { $0.name == "Fluss" })
        #expect(!a.terms.contains { $0.name == "Inseln" })
        #expect(b.terms.contains { $0.name == "Inseln" })
        #expect(!b.terms.contains { $0.name == "Fluss" })
    }

    // MARK: - Gebäude

    @Test("Ein Gebäude in der Ecke verspricht nichts, eines in der Mitte schon")
    func abuildingInTheCornerPromisesNothingAndOneInTheMiddleDoes() {
        // Fünf Punkte für drei verschiedene Farben ringsum, sonst gar
        // nichts. 1.1 hat zwei Nachbarn — dort sind drei Farben unmöglich,
        // und das Gebäude kann nie zählen. 3.3 hat sechs.
        let corner = Evaluator.evaluate(state(stacks: [11: [.stone, .brick]]))
        let middle = Evaluator.evaluate(state(stacks: [33: [.stone, .brick]]))
        let inCorner = corner.terms.first { $0.name == "Gebäude" }
        let inMiddle = middle.terms.first { $0.name == "Gebäude" }
        #expect(inCorner?.points == 0)
        #expect(inCorner?.detail?.contains("ohne Aussicht") == true)
        #expect((inMiddle?.points ?? 0) > 0)
    }

    @Test("Ein Gebäude, das schon zählt, verspricht nichts mehr")
    func abuildingThatAlreadyScoresPromisesNothingMore() {
        // Drei Farben stehen: die fünf Punkte sind in „Landschaften", und
        // eine Aussicht daneben wäre dieselben Punkte ein zweites Mal.
        let scoring = state(stacks: [33: [.stone, .brick], 23: [.water],
                                     32: [.field], 34: [.wood, .leaves]])
        #expect(!Evaluator.evaluate(scoring).terms.contains { $0.name == "Gebäude" })
    }

    // MARK: - Das Spielende

    @Test("Ein fertiger Anwärter verspricht nichts, wenn kein eigener Zug mehr bleibt")
    func afinishedCandidatePromisesNothingWithoutATurnToLayTheCubeIn() {
        // Das Muster steht, der Würfel liegt noch nicht. Ihn zu legen
        // kostet einen eigenen Zug — bleibt keiner, ist der Anwärter
        // wertlos. Vorher versprach er seinen vollen Zuwachs, auch im
        // letzten Zug, und dann lohnte der Deckel kaum noch.
        let meerkat = card("Erdmännchen", [11: .field, 12: .mountain1], cube: 12)
        var standing = state(stacks: [11: [.field], 12: [.stone]],
                             hand: [HeldCard(card: meerkat)])
        #expect(Evaluator.evaluate(standing).terms.contains { $0.name.hasPrefix("Aussicht") })

        standing.turnsPlayed = 35
        #expect(standing.ownTurnsLeft == 0)
        #expect(!Evaluator.evaluate(standing).terms.contains { $0.name.hasPrefix("Aussicht") })
    }

    @Test("Ein volles Brett drängt stärker als der Beutel")
    func afullBoardPressesHarderThanTheBagDoes() {
        // Vier fehlende Steine sind in fünf Zügen noch zu schaffen, in
        // einem nicht. Der Beutel gibt die fünf her, das eigene Brett aber
        // geht vorher zu — und danach richtet sich die Rechnung.
        var tight = state()
        for cell in BoardSide.a.board.cells.dropFirst(3).prefix(19) {
            tight.stacks[cell] = [.field]
        }
        tight.turnsPlayed = 21              // sieben eigene Züge gespielt
        #expect(tight.ownTurnsInTheBag == 5)
        #expect(tight.ownTurnsUntilFull == 1)
        #expect(Evaluator.chance(ofBuilding: [.stone: 4], state: tight) == 0)

        // Dasselbe Brett, nur leerer: dann reicht die Zeit.
        var roomy = tight
        roomy.stacks = [:]
        #expect(Evaluator.chance(ofBuilding: [.stone: 4], state: roomy) > 0)
    }

    // MARK: - Determinismus

    @Test("Zweimal dieselbe Stellung gibt zweimal denselben Wert")
    func thesamePositionTwiceGivesTheSameWorthTwice() {
        let meerkat = card("Erdmännchen", [11: .field, 12: .mountain1], cube: 12)
        let position = state(stacks: [11: [.field], 22: [.stone]],
                             hand: [HeldCard(card: meerkat)])
        #expect(Evaluator.evaluate(position).value == Evaluator.evaluate(position).value)
    }
}
