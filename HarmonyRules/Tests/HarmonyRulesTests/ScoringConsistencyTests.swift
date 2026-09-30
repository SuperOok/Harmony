import Testing
@testable import HarmonyRules

/// `scoringCells()` paints the board and `breakdown()` adds it up. They are
/// two statements of the same rules, and the app shows both side by side —
/// so on any board they must agree about what scores. Hand-built cases in
/// `ScoringTests` pin each rule; this one holds the two statements together
/// over boards nobody chose.
@Suite("Wertung — zwei Aussagen über dasselbe Brett")
struct ScoringConsistencyTests {
    /// Enough to be varied, small enough to be fixed: the same boards on
    /// every run.
    private struct Lcg {
        var state: UInt64
        mutating func next(_ bound: Int) -> Int {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Int((state >> 33) % UInt64(bound))
        }
    }

    private static let legalStacks: [[Stone]] = [Stone].legal
        .sorted { $0.map(\.rawValue).joined() < $1.map(\.rawValue).joined() }

    private func boards(side: BoardSide, count: Int) -> [[Int: [Stone]]] {
        var random = Lcg(state: side == .a ? 7 : 11)
        return (0..<count).map { _ in
            var stacks: [Int: [Stone]] = [:]
            let fill = 3 + random.next(8)          // out of ten spaces
            for cell in side.board.cells where random.next(10) < fill {
                stacks[cell] = Self.legalStacks[random.next(Self.legalStacks.count)]
            }
            return stacks
        }
    }

    private func check(side: BoardSide) {
        for stacks in boards(side: side, count: 400) {
            let scoring = BoardScoring(side: side, columns: side.columns, stacks: stacks)
            let cells = scoring.scoringCells()
            let groups = scoring.breakdown()
            let described = "\(stacks.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value.map(\.rawValue).joined())" })"

            func scoringCells(of landscape: Landscape) -> Int {
                cells.count { (stacks[$0] ?? []).landscape == landscape }
            }
            func lines(_ title: String) -> [ScoreLine] {
                groups.first { $0.title.hasPrefix(title) }?.lines ?? []
            }
            func points(_ title: String) -> Int {
                groups.first { $0.title.hasPrefix(title) }?.points ?? 0
            }

            // One line per tree, per mountain, per building: those that
            // score are exactly the painted ones.
            #expect(scoringCells(of: .tree) == lines("Bäume").count { $0.points > 0 }, "\(described)")
            #expect(scoringCells(of: .mountain) == lines("Berge").count { $0.points > 0 }, "\(described)")
            #expect(scoringCells(of: .building) == lines("Gebäude").count { $0.points > 0 }, "\(described)")

            // Fields come in groups of five points, two stones at least.
            let fieldCells = scoringCells(of: .field)
            #expect((fieldCells > 0) == (points("Felder") > 0), "\(described)")
            #expect(points("Felder") % 5 == 0, "\(described)")
            #expect(fieldCells >= 2 * (points("Felder") / 5), "\(described)")

            // The river: painted are the cells of the longest one, and its
            // length is what the ladder pays for.
            if side == .a {
                let river = cells.count { (stacks[$0] ?? []).landscape == .water }
                #expect(points("Wasser") == BoardScoring.riverPoints(river), "\(described)")
            }
        }
    }

    @Test("Auf Seite A malen und zählen dieselben Felder")
    func sideAPaintsWhatItCounts() { check(side: .a) }

    @Test("Auf Seite B malen und zählen dieselben Felder")
    func sideBPaintsWhatItCounts() { check(side: .b) }
}
