import Foundation
import Testing
import HarmonyRules
@testable import HarmonyEngine

/// The chain from the card data to a suggested turn — the question Phase 6
/// exists to answer. Positions are kept small so the search stays a test and
/// not a benchmark; how it fares on a real board is measured separately.

/// Collects what the search says about itself. A plain array would do while
/// the search runs on one core; it works on several, and the reports arrive
/// from all of them.
final class Reports: @unchecked Sendable {
    private let lock = NSLock()
    private var kept: [SearchProgress] = []

    func add(_ progress: SearchProgress) {
        lock.lock(); kept.append(progress); lock.unlock()
    }

    var all: [SearchProgress] {
        lock.lock(); defer { lock.unlock() }
        return kept
    }
}

/// Counts how often the search asked whether to stop, and says yes after a
/// while. Under a lock for the same reason.
final class Patience: @unchecked Sendable {
    private let lock = NSLock()
    private var asked = 0
    let limit: Int

    init(until limit: Int) { self.limit = limit }

    func enough() -> Bool {
        lock.lock(); defer { lock.unlock() }
        asked += 1
        return asked > limit
    }
}

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

    // MARK: - Vorgerechnetes je Legung

    @Test("Vorgerechnetes ändert am Ergebnis nichts")
    func precomputingChangesNothingAboutTheResult() throws {
        // Die ganze Beschleunigung steht und fällt damit: Was einmal je
        // Legung gerechnet wird, muss dasselbe sein, was sonst je Zug
        // herauskäme. Geprüft Term für Term, nicht nur als Summe — ein
        // Vorzeichenfehler in zwei Termen hebt sich in der Summe auf.
        let deck = try AnimalCards.load()
        // Eine Stellung **mit** Flussaussicht: zwei Wasserfelder, die sich
        // über die freien Felder verlängern ließen, ringsum Stein. Die
        // Hilfsfunktion `position` taugt hier nicht — sie füllt mit Wasser,
        // und ein fast voller Fluss hat keine Aussicht mehr.
        var stacks: [Int: [Stone]] = [:]
        for cell in BoardSide.a.board.cells { stacks[cell] = [.stone] }
        for cell in [11, 12] { stacks[cell] = [.water] }
        for cell in [13, 14, 21, 22, 31] { stacks[cell] = nil }

        let state = EngineState(
            side: .a, stacks: stacks,
            hand: [HeldCard(card: deck[0]), HeldCard(card: deck[1])],
            display: [[.stone, .water, .leaves]],
            openCards: Array(deck[2..<5]),
            drawn: [.stone: 6, .wood: 4, .leaves: 3, .water: 2, .field: 3, .brick: 2],
            turnsPlayed: 6, players: 3, seat: 0)

        let anchors = Moves.standingHabitatCells(of: state)
        let available = Search.availability(after: 0, of: state)
        var checked = 0
        var sawLandscape = false

        for laying in Moves.layings(of: state.display[0], on: state).prefix(40) {
            let laid = state.laying(stacks: laying.stacks, space: 0)
            let prepared = Evaluator.prepare(laid, availability: available)

            for move in Moves.turns(space: 0, laying: laying, from: state, anchors: anchors) {
                let after = state.applying(move)
                let plain = Evaluator.evaluate(after, availability: available)
                let quick = Evaluator.evaluate(after, availability: available,
                                               prepared: move.cubes.isEmpty ? prepared : nil)
                #expect(plain.terms == quick.terms, "Zug \(move)")
                #expect(plain.pointsNow == quick.pointsNow)
                if plain.terms.contains(where: { $0.name == "Fluss" && $0.points != 0 }) {
                    sawLandscape = true
                }
                checked += 1
            }
        }
        #expect(checked > 100, "zu wenige Züge geprüft, um etwas zu heißen")
        // Ohne diesen Nachweis wäre die Zusicherung oben auf einer Stellung
        // geprüft, in der die Landschaftsaussicht null ist — und genau dort
        // saß der Fehler, den sie fangen soll: Die vorgerechnete Legung
        // zählte den Zug nicht mit, also stand `ownTurnsLeft` um eins zu
        // hoch und die Flussaussicht um einen Zehntelpunkt daneben.
        #expect(sawLandscape, "die Stellung muss eine Flussaussicht haben, sonst prüft sie nichts")
    }

    @Test("Über einen Würfel hinweg gilt das Vorgerechnete weiter")
    func acrossACubeThePrecomputingStillHolds() throws {
        // Die Landschaft kennt keine Würfel, und die Anwärter werden
        // gefiltert statt neu gesucht: Ein Würfel auf Feld x wirft genau die
        // Anwärter, denen x noch wachsen müsste oder deren Würfelfeld x ist.
        // Diese Zusicherung ist der Nachweis dafür — Term für Term, auf
        // echten Würfelzügen.
        let meerkat = card("Erdmännchen", [11: .field, 12: .mountain1], cube: 12)
        let badger = card("Dachs", [13: .field, 14: .mountain1], cube: 14)
        let state = position(empty: [12, 14, 15, 21, 22],
                             filled: [11: [.field], 13: [.field], 23: [.water]],
                             hand: [HeldCard(card: meerkat), HeldCard(card: badger)],
                             display: [[.stone, .stone, .water]])

        let anchors = Moves.standingHabitatCells(of: state)
        let available = Search.availability(after: 0, of: state)
        var cubeMoves = 0

        // Ein Ausschnitt genügt; die Prüfung soll eine Zusicherung bleiben
        // und kein Messlauf. Teuer ist dabei die Vergleichsseite: `plain`
        // rechnet jede Bewertung ganz.
        layings: for laying in Moves.layings(of: state.display[0], on: state) {
            if cubeMoves >= 60 { break layings }
            let laid = state.laying(stacks: laying.stacks, space: 0)
            let prepared = Evaluator.prepare(laid, availability: available)

            for move in Moves.turns(space: 0, laying: laying, from: state, anchors: anchors)
            where !move.cubes.isEmpty {
                cubeMoves += 1
                let after = state.applying(move)
                let plain = Evaluator.evaluate(after, availability: available)
                let quick = Evaluator.evaluate(after, availability: available,
                                               prepared: prepared)
                #expect(plain.terms == quick.terms, "Würfelzug \(move)")
                #expect(plain.pointsNow == quick.pointsNow)
            }
        }
        // Ohne Würfelzüge prüfte die Zusicherung nichts — derselbe Fehler,
        // den die Flussaussicht oben schon einmal durchgehen ließ.
        #expect(cubeMoves > 20, "die Stellung muss Würfelzüge hergeben, sonst prüft sie nichts")
    }

    @Test("Hervorgewachsene Anwärter sind die neu gesuchten")
    func grownCandidatesAreTheOnesSearchedForAgain() throws {
        // Der Kern des inkrementellen Bewertens: Eine Legung ändert höchstens
        // drei Felder, also werden die Anwärter dort fortgeschrieben statt
        // das Brett erneut abzusuchen. Das gilt nur, weil Steine nie wieder
        // herunterkommen — ein höherer Stapel erreicht weniger Landschaften,
        // nie mehr. Geprüft wird Anwärter für Anwärter, in der Reihenfolge.
        let deck = try AnimalCards.load()
        let state = position(empty: [11, 12, 13, 14, 21, 22, 31],
                             filled: [23: [.water], 32: [.stone]],
                             hand: [HeldCard(card: deck[0]), HeldCard(card: deck[1])],
                             openCards: Array(deck[2..<5]),
                             display: [[.stone, .water, .leaves]])

        let stock = Evaluator.stock(of: state)
        let available = Search.availability(after: 0, of: state)
        var checked = 0, dropped = 0

        for laying in Moves.layings(of: state.display[0], on: state).prefix(60) {
            let laid = state.laying(stacks: laying.stacks, space: 0)
            let fresh = Evaluator.prepare(laid, availability: available)
            let grown = Evaluator.prepare(laid, availability: available,
                                          from: stock, grown: laying.grown)

            #expect(Set(fresh.habitats.keys) == Set(grown.habitats.keys))
            for (name, expected) in fresh.habitats {
                #expect(grown.habitats[name] == expected, "Karte \(name)")
                dropped += (stock.habitats[name]?.count ?? 0) - expected.count
                checked += expected.count
            }
            // Die übrigen Teile dürfen sich davon nicht unterscheiden.
            #expect(fresh.landscapeTerms == grown.landscapeTerms)
            #expect(fresh.sleepers == grown.sleepers)
            #expect(fresh.landscapeNow == grown.landscapeNow)
        }

        #expect(checked > 500, "zu wenige Anwärter geprüft, um etwas zu heißen")
        // Ohne diesen Nachweis liefe die Zusicherung auf Legungen, die gar
        // nichts ausschließen — dann prüfte sie nur, dass nichts passiert.
        #expect(dropped > 0, "die Legungen müssen auch Anwärter ausschließen")
    }

    @Test("Ein Würfel verändert die Anwärter überhaupt")
    func acubeChangesTheCandidatesAtAll() {
        // Die Gegenprobe: Würde ein Würfel die Anwärter gar nicht berühren,
        // wäre das Filtern oben eine Zusicherung über nichts.
        let card = card("Prüftier", [11: .field, 12: .mountain1], cube: 12)
        let state = position(empty: [11, 12, 13],
                             hand: [HeldCard(card: card)],
                             display: [[.stone, .field, .field]])
        let withCube = EngineState(side: .a, stacks: state.stacks, cubes: [12: "Prüftier"],
                                   hand: state.hand, display: state.display,
                                   openCards: state.openCards, drawn: [:],
                                   turnsPlayed: 6, players: 3, seat: 0)

        let free = Evaluator.prepare(state)
        let blocked = Evaluator.prepare(withCube)
        #expect(free.habitats["Prüftier"]?.count != blocked.habitats["Prüftier"]?.count,
                "ein Würfel muss die Anwärter verändern")
    }

    // MARK: - Auf mehreren Kernen

    @Test("Auf acht Kernen kommt heraus, was auf einem herauskommt")
    func oneightCoresTheSameThingComesOutAsOnOne() throws {
        // Die Suche schneidet die Legungen in Stücke und verschmilzt sie in
        // der Reihenfolge der Stücke — nicht in der, in der die Kerne fertig
        // werden. Ohne das entschiede bei gleichwertigen Zügen die
        // Zuteilung, und dieselbe Stellung gäbe zweimal verschiedene Züge.
        let deck = try AnimalCards.load()
        // Groß genug, dass die Suche überhaupt schneidet — unter 64
        // Legungen bleibt sie auf einem Kern —, klein genug, dass die
        // Regelprüfung unter einer Sekunde bleibt.
        let state = position(empty: [11, 12, 13, 14, 21],
                             hand: [HeldCard(card: deck[0])],
                             openCards: Array(deck[2..<4]),
                             display: [[.stone, .water, .leaves], [.wood, .wood, .field]])

        let alone = try #require(Search.best(from: state, cores: 1))
        for cores in [2, 8, 64] {
            let many = try #require(Search.best(from: state, cores: cores))
            #expect(many.move == alone.move, "\(cores) Kerne")
            #expect(many.value == alone.value, "\(cores) Kerne")
            #expect(many.runnerUp == alone.runnerUp, "\(cores) Kerne")
            #expect(many.runnerUpValue == alone.runnerUpValue, "\(cores) Kerne")
            #expect(many.weighed == alone.weighed, "\(cores) Kerne")
            #expect(many.terms == alone.terms, "\(cores) Kerne")
        }
    }

    @Test("Auch nebenläufig zählt die Suche jeden Zug genau einmal")
    func evenInParallelEveryTurnIsCountedExactlyOnce() throws {
        let deck = try AnimalCards.load()
        let state = position(empty: [11, 12, 13, 14, 21],
                             hand: [HeldCard(card: deck[0])],
                             display: [[.stone, .water, .leaves]])
        let all = Moves.all(from: state).count
        let suggestion = try #require(Search.best(from: state, cores: 8))
        #expect(suggestion.weighed == all, "gewogen wird, was es gibt — nicht mehr, nicht weniger")
    }

    // MARK: - Was die Suche über sich sagt

    @Test("Die Suche meldet sich, bevor sie den ersten Zug gewogen hat")
    func thesearchReportsBeforeItHasWeighedAnything() {
        // Ohne diese erste Meldung steht der Bildschirm in der ersten
        // Sekunde leer da — und genau in dieser Sekunde schaut jemand hin.
        let state = position(empty: [11, 12, 13],
                             display: [[.stone, .stone, .stone],
                                       [.water, .water, .water]])
        let collector = Reports()
        _ = Search.best(from: state, progress: { collector.add($0) })

        let reports = collector.all
        let first = reports.first
        #expect(first?.weighed == 0)
        #expect(first?.best == nil)
        #expect(first?.spacesDone == 0)
        #expect(first?.spacesTotal == 2)
    }

    @Test("Der Fortschritt wächst und bleibt innerhalb seiner Grenzen")
    func theprogressGrowsAndStaysWithinItsBounds() {
        let state = position(empty: [11, 12, 13],
                             display: [[.stone, .stone, .stone],
                                       [.water, .water, .water]])
        let collector = Reports()
        let suggestion = Search.best(from: state, progress: { collector.add($0) })

        let reports = collector.all
        #expect(zip(reports, reports.dropFirst()).allSatisfy { $0.weighed <= $1.weighed },
                "ein Zähler, der zurückspringt, wäre keine Auskunft")
        #expect(zip(reports, reports.dropFirst()).allSatisfy { $0.spacesDone <= $1.spacesDone })
        #expect(reports.allSatisfy { $0.spacesDone <= $0.spacesTotal })
        #expect(reports.last?.weighed == suggestion?.weighed,
                "die letzte Meldung nennt dieselbe Zahl wie das Ergebnis")
        #expect(reports.last?.spacesDone == reports.last?.spacesTotal,
                "eine durchgelaufene Suche ist auch gemeldet fertig")
        #expect(reports.last?.best == suggestion?.move,
                "und denselben Zug")
    }

    @Test("Gleiche Auslagefelder zählen als eines")
    func equalDisplaySpacesCountAsOne() {
        // Die Suche überspringt das zweite von zwei gleichen Feldern. Der
        // Nenner muss das schon vorher wissen, sonst zeigt der Bildschirm
        // einen Bruch, der unterwegs kleiner wird.
        let state = position(empty: [11, 12, 13],
                             display: [[.stone, .stone, .stone],
                                       [.stone, .stone, .stone]])
        let collector = Reports()
        _ = Search.best(from: state, progress: { collector.add($0) })
        let reports = collector.all
        #expect(reports.first?.spacesTotal == 1)
        #expect(reports.last?.spacesDone == 1)
    }

    @Test("Eine abgebrochene Suche meldet den Zug, den sie herausgibt")
    func astoppedSearchReportsTheTurnItHandsBack() {
        // Der Knopf „Abkürzen" verspricht den besten bisher gefundenen Zug.
        // Gezeigt wird er vorher, also muss er derselbe sein.
        let state = position(empty: [11, 12, 13, 14],
                             display: [[.stone, .stone, .stone]])
        let collector = Reports()
        let patience = Patience(until: 2)
        // Auf einem Kern, damit »der beste bis hierhin« eindeutig ist: Bei
        // mehreren hört jeder Kern an einer anderen Stelle auf.
        let suggestion = Search.best(from: state,
                                     cancelled: { patience.enough() },
                                     progress: { collector.add($0) },
                                     cores: 1)
        let reports = collector.all
        #expect(suggestion?.complete == false)
        #expect(reports.last?.best == suggestion?.move)
        #expect(reports.last?.spacesDone == 0, "ein Feld, das abbrach, ist nicht fertig")
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
