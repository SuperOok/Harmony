import Testing
@testable import HarmonyRules

/// Storey one from `pruefverfahren.md`: plain functions over data
/// structures. Board in, number out — no interface, no simulator, no app.
///
/// Every position is built by hand and aimed at exactly one rule, written
/// in the board notation of `pruefverfahren.md`: `32=SS` is the second
/// space of the third column, stones bottom first. The expected values are
/// counted by hand, never taken from a program run.
///
/// The worthwhile cases are the ones where the rule surprises — a mountain
/// that scores nothing, a river branch that does not count.
@Suite("Wertung — Stockwerk 1")
struct ScoringTests {
    /// `Felder: 32=SS` on side A.
    private func sideA(_ stacks: [Int: [Stone]]) -> BoardScoring {
        BoardScoring(side: .a, columns: BoardSide.a.columns, stacks: stacks)
    }

    private func sideB(_ stacks: [Int: [Stone]]) -> BoardScoring {
        BoardScoring(side: .b, columns: BoardSide.b.columns, stacks: stacks)
    }

    /// A landscape with no space at all gets no group, which is not the
    /// same as a group scoring zero — see `emptyKindHasNoGroup`.
    private func points(_ scoring: BoardScoring, _ title: String) -> Int {
        scoring.breakdown().first { $0.title.hasPrefix(title) }?.points ?? 0
    }

    private func total(_ scoring: BoardScoring) -> Int {
        scoring.breakdown().reduce(0) { $0 + $1.points }
    }

    // MARK: - Berge

    @Test("Ein Berg ohne Bergnachbarn zählt 0, nicht 7")
    func mountainWithoutNeighbour() {
        // 21=SSS — Höhe 3, aber allein auf weiter Flur.
        let board = sideA([21: [.stone, .stone, .stone]])
        #expect(points(board, "Berge") == 0)
        #expect(board.scoringCells().contains(21) == false)
    }

    @Test("Zwei benachbarte Berge zählen beide")
    func mountainsWithNeighbour() {
        // 31=S (1) und 32=SS (3) — beide haben einen Bergnachbarn.
        let board = sideA([31: [.stone], 32: [.stone, .stone]])
        #expect(points(board, "Berge") == 1 + 3)
    }

    @Test("Ein Gebäude ist kein Bergnachbar")
    func buildingIsNoMountain() {
        // 31=S neben 32=SZ. Der rote Stein obendrauf macht daraus ein
        // Gebäude, also steht der Berg wieder allein.
        let board = sideA([31: [.stone], 32: [.stone, .brick]])
        #expect(points(board, "Berge") == 0)
    }

    // MARK: - Bäume

    @Test("Baumhöhen zählen 1/3/7, ohne Bedingung")
    func treeHeights() {
        // 11=L, 21=HL, 31=HHL — Höhe 1, 2, 3.
        let board = sideA([11: [.leaves],
                           21: [.wood, .leaves],
                           31: [.wood, .wood, .leaves]])
        #expect(points(board, "Bäume") == 1 + 3 + 7)
    }

    @Test("Ein brauner Stein ohne Grün ist keine Landschaft")
    func bareWoodScoresNothing() {
        let board = sideA([11: [.wood], 12: [.wood, .wood]])
        #expect(total(board) == 0)
        #expect([Stone.wood].landscape == nil)
        #expect([Stone.wood, .wood].landscape == nil)
    }

    @Test("Eine Landschaftsart ohne jedes Feld bekommt keine Gruppe")
    func emptyKindHasNoGroup() {
        // Die Abgrenzung zu `zeroLinesAreKept`: Punktlose **Zeilen**
        // bleiben stehen, weil man sie beim Nachrechnen sucht. Eine
        // Gruppe ohne jede Zeile gibt es dagegen nicht — es gäbe nichts
        // zu suchen.
        let board = sideA([11: [.wood]])
        #expect(board.breakdown().contains { $0.title.hasPrefix("Bäume") } == false)
    }

    // MARK: - Felder

    @Test("Ein einzelner gelber Stein zählt 0")
    func loneFieldScoresNothing() {
        #expect(points(sideA([34: [.field]]), "Felder") == 0)
    }

    @Test("Zwei angrenzende Felder zählen 5")
    func fieldPairScores() {
        // 51 und 52 liegen in derselben Spalte übereinander.
        #expect(points(sideA([51: [.field], 52: [.field]]), "Felder") == 5)
    }

    // MARK: - Gebäude

    @Test("Ein Gebäude am Rand hat zu wenige Farben")
    func buildingAtTheRim() {
        // 35=ZZ ganz unten in der letzten Spalte: die fehlenden Nachbarn
        // sind leer und zählen nicht mit.
        #expect(points(sideA([35: [.brick, .brick]]), "Gebäude") == 0)
    }

    @Test("Ein Gebäude mit drei Farben ringsum zählt")
    func buildingWithThreeColours() {
        // 22=HZ, ringsum ein Baum, ein Berg und ein Feld — drei
        // verschiedene oberste Steine.
        let board = sideA([22: [.wood, .brick],
                           21: [.leaves],
                           23: [.stone],
                           12: [.field]])
        #expect(points(board, "Gebäude") > 0)
    }

    // MARK: - Wasser, Seite A

    @Test("Der Ast neben der längsten Kette zählt nicht mit")
    func riverBranchDoesNotCount() {
        // Fluss 11-12-13-14-15 in Spalte eins, dazu 23 als Ast daneben.
        // Gezählt wird die längste Kette, nicht alles Zusammenhängende.
        let river: [Int: [Stone]] = [11: [.water], 12: [.water], 13: [.water],
                                     14: [.water], 15: [.water], 23: [.water]]
        let withBranch = points(sideA(river), "Wasser")
        var without = river
        without[23] = nil
        #expect(withBranch == points(sideA(without), "Wasser"))
    }

    @Test("Ein zweiter, kürzerer Fluss zählt gar nicht")
    func onlyTheLongestRiverCounts() {
        let board = sideA([11: [.water], 12: [.water], 13: [.water],
                           53: [.water]])
        #expect(board.scoringCells().contains(53) == false)
    }

    // MARK: - Wasser, Seite B

    @Test("Auf Seite B zählt Wasser nur zwischen zwei Inseln")
    func islandWaterSeparates() {
        // Spalte vier ganz aus Wasser trennt das Brett in zwei Inseln.
        let splitting = sideB([41: [.water], 42: [.water], 43: [.water],
                               11: [.leaves], 71: [.leaves]])
        // Ein einzelner Wasserstein trennt nichts.
        let lonely = sideB([21: [.water], 11: [.leaves], 71: [.leaves]])
        #expect(points(splitting, "Wasser") > points(lonely, "Wasser"))
        #expect(lonely.scoringCells().contains(21) == false)
    }

    // MARK: - Staffeln

    @Test("Die Höhenstaffel ist 1/3/7, nicht linear")
    func heightLadder() {
        #expect(BoardScoring.heightPoints(1) == 1)
        #expect(BoardScoring.heightPoints(2) == 3)
        #expect(BoardScoring.heightPoints(3) == 7)
    }

    @Test("Punktlose Zeilen bleiben in der Aufschlüsselung stehen")
    func zeroLinesAreKept() {
        // Szenario 4 verlangt ein nachrechenbares Ergebnis: Wer auf eine
        // andere Summe kommt, sucht zuerst, was nicht gezählt hat.
        let board = sideA([21: [.stone, .stone, .stone]])
        let mountains = board.breakdown().first { $0.title.hasPrefix("Berge") }
        #expect(mountains?.lines.isEmpty == false)
        #expect(mountains?.points == 0)
    }
}
