import Foundation

public enum BoardSide: Sendable { case a, b }

/// Which cells currently earn points.
///
/// **Provisional.** This is rule computation and belongs in the engine
/// module, not in the interface — `04-architektur.md` places it there
/// exactly once, checked per `pruefverfahren.md`, storey one. It sits here
/// because the dummy cannot show what it is meant to show without it. At
/// the walking skeleton it moves and is deleted here, not copied.
public struct BoardScoring {
    public let side: BoardSide
    public let columns: [Int]
    public let stacks: [Int: [Stone]]

    public init(side: BoardSide, columns: [Int], stacks: [Int: [Stone]]) {
        self.side = side
        self.columns = columns
        self.stacks = stacks
    }

    /// Every space on the board, empty ones included — the island scoring
    /// on side B counts them.
    public var allCells: [Int] {
        columns.enumerated().flatMap { index, count in
            (1...count).map { (index + 1) * 10 + $0 }
        }
    }

    /// Neighbours of a cell `<column><row>`. Even columns, counted from one,
    /// sit half a cell lower; see `regeln-basisspiel.md`.
    public func neighbours(_ cell: Int) -> [Int] {
        let c = cell / 10 - 1, r = cell % 10 - 1        // zero based
        let offset = c % 2 == 0 ? -1 : 1
        var candidates = [(c, r - 1), (c, r + 1)]
        for dc in [-1, 1] {
            candidates.append((c + dc, r))
            candidates.append((c + dc, r + offset))
        }
        return candidates.compactMap { cc, rr in
            guard cc >= 0, cc < columns.count, rr >= 0, rr < columns[cc] else { return nil }
            return (cc + 1) * 10 + (rr + 1)
        }
    }

    private func landscape(_ cell: Int) -> Landscape? {
        (stacks[cell] ?? []).landscape
    }

    /// Connected regions within a set of cells.
    private func regions(in set: Set<Int>) -> [[Int]] {
        var remaining = set
        var all: [[Int]] = []
        while let start = remaining.first {
            var region: [Int] = []
            var frontier = [start]
            remaining.remove(start)
            while let cell = frontier.popLast() {
                region.append(cell)
                for n in neighbours(cell) where remaining.contains(n) {
                    remaining.remove(n); frontier.append(n)
                }
            }
            all.append(region)
        }
        return all
    }

    /// The longest among all shortest paths inside a region, as a sequence
    /// of cells. "Both ends counted" — the length is the number of cells.
    private func longestPath(_ region: [Int]) -> [Int] {
        let set = Set(region)
        var best: [Int] = []
        for start in region {
            var predecessor: [Int: Int] = [:]
            var seen: Set<Int> = [start]
            var queue = [start]
            var last = start
            while !queue.isEmpty {
                var next: [Int] = []
                for cell in queue {
                    last = cell
                    for n in neighbours(cell) where set.contains(n) && !seen.contains(n) {
                        seen.insert(n); predecessor[n] = cell; next.append(n)
                    }
                }
                queue = next
            }
            var path = [last]
            while let p = predecessor[path[0]] { path.insert(p, at: 0) }
            if path.count > best.count { best = path }
        }
        return best
    }

    /// Every cell that currently earns points.
    public func scoringCells() -> Set<Int> {
        var result: Set<Int> = []

        // Trees carry no condition, they always score.
        for (cell, _) in stacks where landscape(cell) == .tree { result.insert(cell) }

        // Mountains only with at least one adjacent mountain.
        for (cell, _) in stacks where landscape(cell) == .mountain {
            if neighbours(cell).contains(where: { landscape($0) == .mountain }) {
                result.insert(cell)
            }
        }

        // Fields: a group of at least two adjacent yellow stones.
        for group in regions(in: Set(stacks.keys.filter { landscape($0) == .field }))
            where group.count >= 2 {
            result.formUnion(group)
        }

        let water = Set(allCells.filter { landscape($0) == .water })

        switch side {
        case .a:
            // River: only the longest one, and within it only the cells on
            // the longest chain — a branch beside it does not count.
            let paths = regions(in: water).map(longestPath)
            if let longest = paths.max(by: { $0.count < $1.count }), longest.count >= 2 {
                result.formUnion(longest)
            }

        case .b:
            // Islands: connected regions of all non-blue spaces, empty ones
            // included; each scores five. The water itself does not score,
            // it separates. A water cell counts when it borders **two
            // different** islands and so does the separating work. Water in
            // a bay does nothing.
            let islands = regions(in: Set(allCells).subtracting(water))
            var islandOf: [Int: Int] = [:]
            for (index, island) in islands.enumerated() {
                for cell in island { islandOf[cell] = index }
            }
            for cell in water {
                let touched = Set(neighbours(cell).compactMap { islandOf[$0] })
                if touched.count >= 2 { result.insert(cell) }
            }
        }

        // Buildings: surrounded by at least three differently coloured
        // stones, counted over the topmost stone of each neighbouring
        // space. Empty neighbours do not count.
        for (cell, _) in stacks where landscape(cell) == .building {
            let colors = Set(neighbours(cell).compactMap { stacks[$0]?.last })
            if colors.count >= 3 { result.insert(cell) }
        }

        return result
    }
}

extension BoardSide {
    /// Spaces per column. Side A is 5-4-5-4-5 with 23 spaces, side B is
    /// 4-3-4-3-4-3-4 with 25 — the geometry from `regeln-basisspiel.md`.
    public var columns: [Int] {
        switch self {
        case .a: [5, 4, 5, 4, 5]
        case .b: [4, 3, 4, 3, 4, 3, 4]
        }
    }
}

/// A cell as it is spoken and written: `43` is "4.3".
public func cellName(_ cell: Int) -> String { "\(cell / 10).\(cell % 10)" }


// MARK: - Endwertung

/// One line of the final score: what earned the points, and how many.
///
/// Szenario 4 asks for a result that can be **checked against the board**,
/// which a total alone cannot be. Every line therefore names the spaces it
/// is about, and lines worth nothing are kept — they are the ones someone
/// goes looking for.
public struct ScoreLine: Identifiable, Sendable {
    public let id = UUID()
    public let label: String
    public let points: Int

    public init(label: String, points: Int) {
        self.label = label
        self.points = points
    }
}

public struct ScoreGroup: Identifiable, Sendable {
    public let id = UUID()
    public let title: String
    public let lines: [ScoreLine]
    /// Read under the group when the rule is easier to check than to recall.
    public var note: String? = nil

    public init(title: String, lines: [ScoreLine], note: String? = nil) {
        self.title = title
        self.lines = lines
        self.note = note
    }

    public var points: Int { lines.reduce(0) { $0 + $1.points } }
}

extension BoardScoring {
    /// Trees and mountains share one ladder: height 1/2/3 scores 1/3/7.
    public static func heightPoints(_ height: Int) -> Int {
        switch height {
        case 1: 1
        case 2: 3
        case 3: 7
        default: 0
        }
    }

    /// The river ladder: 0, 2, 5, 8, 11, 15, and four more per cell beyond
    /// the sixth.
    public static func riverPoints(_ length: Int) -> Int {
        switch length {
        case 2: 2
        case 3: 5
        case 4: 8
        case 5: 11
        case 6: 15
        default: length > 6 ? 15 + 4 * (length - 6) : 0
        }
    }

    /// The landscape score, group by group. Empty groups are left out —
    /// a board without a single building has nothing to check there.
    public func breakdown() -> [ScoreGroup] {
        [trees, mountains, fieldGroups, waterGroup, buildings]
            .filter { !$0.lines.isEmpty }
    }

    private var trees: ScoreGroup {
        let cells = stacks.keys.filter { (stacks[$0] ?? []).landscape == .tree }.sorted()
        return ScoreGroup(title: "Bäume", lines: cells.map { cell in
            let height = stacks[cell]?.count ?? 0
            return ScoreLine(label: "Höhe \(height) auf \(cellName(cell))",
                             points: Self.heightPoints(height))
        })
    }

    private var mountains: ScoreGroup {
        let cells = stacks.keys.filter { (stacks[$0] ?? []).landscape == .mountain }.sorted()
        return ScoreGroup(title: "Berge", lines: cells.map { cell in
            let height = stacks[cell]?.count ?? 0
            let touches = neighbours(cell).contains {
                (stacks[$0] ?? []).landscape == .mountain
            }
            return ScoreLine(
                label: "Höhe \(height) auf \(cellName(cell))"
                    + (touches ? "" : " — ohne Bergnachbarn"),
                points: touches ? Self.heightPoints(height) : 0)
        }, note: "Ein Berg zählt nur neben einem anderen Berg. Ein grauer "
            + "Stapel mit rotem Stein obenauf ist ein Gebäude und zählt hier "
            + "gar nicht mit.")
    }

    private var fieldGroups: ScoreGroup {
        let yellow = Set(stacks.keys.filter { (stacks[$0] ?? []).landscape == .field })
        let groups = regions(in: yellow).sorted { ($0.min() ?? 0) < ($1.min() ?? 0) }
        return ScoreGroup(title: "Felder", lines: groups.map { group in
            let where_ = group.sorted().map(cellName).joined(separator: ", ")
            return group.count >= 2
                ? ScoreLine(label: "Gruppe aus \(group.count) Steinen: \(where_)",
                            points: 5)
                : ScoreLine(label: "Einzelner Stein auf \(where_) — keine Gruppe",
                            points: 0)
        }, note: "Jede Gruppe ab zwei Steinen zählt 5, unabhängig von ihrer Größe.")
    }

    private var waterGroup: ScoreGroup {
        let water = Set(allCells.filter { (stacks[$0] ?? []).landscape == .water })

        switch side {
        case .a:
            let rivers = regions(in: water)
                .map { (size: $0.count, path: longestPath($0)) }
                .sorted { $0.path.count > $1.path.count }
            let lines = rivers.enumerated().map { index, river -> ScoreLine in
                let length = river.path.count
                guard index == 0 else {
                    return ScoreLine(
                        label: "Weiterer Fluss der Länge \(length) — nur der längste zählt",
                        points: 0)
                }
                let aside = river.size - length
                let where_ = river.path.map(cellName).joined(separator: " – ")
                return ScoreLine(
                    label: "Länge \(length): \(where_)"
                        + (aside > 0
                           ? " — \(aside) Stein\(aside == 1 ? "" : "e") daneben zählt nicht mit"
                           : ""),
                    points: Self.riverPoints(length))
            }
            return ScoreGroup(title: "Wasser — der Fluss", lines: lines,
                              note: "Die Länge ist der längste unter allen "
                                  + "kürzesten Wegen, beide Enden mitgezählt.")

        case .b:
            let islands = regions(in: Set(allCells).subtracting(water))
                .sorted { ($0.min() ?? 0) < ($1.min() ?? 0) }
            return ScoreGroup(title: "Wasser — die Inseln", lines: islands.map {
                ScoreLine(label: "Insel aus \($0.count) Feldern, ab \(cellName($0.min() ?? 0))",
                          points: 5)
            }, note: "Leere Felder gehören zu einer Insel. Es gibt immer "
                + "mindestens eine.")
        }
    }

    private var buildings: ScoreGroup {
        let cells = stacks.keys.filter { (stacks[$0] ?? []).landscape == .building }.sorted()
        return ScoreGroup(title: "Gebäude", lines: cells.map { cell in
            let colors = Set(neighbours(cell).compactMap { stacks[$0]?.last })
            return ScoreLine(
                label: "Auf \(cellName(cell)) — \(colors.count) Farbe"
                    + (colors.count == 1 ? "" : "n") + " ringsum",
                points: colors.count >= 3 ? 5 : 0)
        }, note: "Gezählt wird der oberste Stein jedes belegten Nachbarfeldes. "
            + "Leere Nachbarn zählen nicht mit.")
    }
}
