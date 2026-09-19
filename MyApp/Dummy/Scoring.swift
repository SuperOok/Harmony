import Foundation

enum BoardSide { case a, b }

/// Which cells currently earn points.
///
/// **Provisional.** This is rule computation and belongs in the engine
/// module, not in the interface — `04-architektur.md` places it there
/// exactly once, checked per `pruefverfahren.md`, storey one. It sits here
/// because the dummy cannot show what it is meant to show without it. At
/// the walking skeleton it moves and is deleted here, not copied.
struct BoardScoring {
    let side: BoardSide
    let columns: [Int]
    let stacks: [Int: [Stone]]

    /// Every space on the board, empty ones included — the island scoring
    /// on side B counts them.
    var allCells: [Int] {
        columns.enumerated().flatMap { index, count in
            (1...count).map { (index + 1) * 10 + $0 }
        }
    }

    /// Neighbours of a cell `<column><row>`. Even columns, counted from one,
    /// sit half a cell lower; see `regeln-basisspiel.md`.
    func neighbours(_ cell: Int) -> [Int] {
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
    func scoringCells() -> Set<Int> {
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
