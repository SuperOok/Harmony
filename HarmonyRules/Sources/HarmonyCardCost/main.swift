import Foundation
import HarmonyRules

// What a whole card costs: the fewest stones that carry **all** of its
// habitats, one per cube, with the habitats laid over each other as far as
// the rules allow — and how much of the board that "big habitat" takes.
// `docs/kartenguete.md` has the reasoning.
//
// What is counted for the big habitat of a card:
//
// * **Steine** — the stones all habitats need together, the one thing the
//   search minimises.
// * **Felder** — the spaces of the board it occupies; among the layouts of
//   the fewest stones, the one with the fewest spaces.
// * **Würfelfelder** — spaces that carry a cube. One cube to a space, and a
//   stack under a cube never grows: those spaces are spoken for.
// * **Eingefroren** — cube spaces on a `Berg1` or `Berg2`, which could have
//   grown into something worth more.
// * **Landschaft** — what the stones of the layout score on side A by
//   themselves, the best among the layouts with the fewest stones and spaces.
//
// * **Auslastung** — the mean of two shares: the card's stones of the roughly
//   30 a game lays, and its spaces of the roughly 21 that are filled when the
//   game ends (Harmony, side A, two players: 29.8 stones, 21.4 spaces). The
//   two budgets are what a card competes for; the figures are assumptions
//   taken from games, not rules.
//
// Two readings of how habitats share spaces:
//
// * **fest** — only where they ask for the same landscape at the same height.
// * **überbauen** — a stack may also grow between two habitats as long as it
//   carries no cube yet (`Berg1`, later `Berg2`, `Berg3` or a building on
//   top). The first habitat keeps its cube ("Tierwürfel bleiben liegen"), the
//   second needs the taller stack. A cube's space never grows again, and the
//   order of the habitats must not run in a circle.
//
// The search is exact: every set of habitats of the right size, on the board
// of one side, with the cheapest one kept.
//
//   swift run -c release HarmonyCardCost            all cards, as a Markdown table
//   swift run -c release HarmonyCardCost Wolf       one card, with the layout

let cells = PatternCell.allCases
let code = Dictionary(uniqueKeysWithValues: cells.enumerated().map { ($1, $0) })

/// How two requirements on one space relate: 0 clash, 1 the same, 2 the
/// first can be a stage of the second, 3 the second of the first.
let relation: [[UInt8]] = cells.map { a in
    cells.map { b in
        if a == b { return 1 }
        if a.canPrecede(b) { return 2 }
        if b.canPrecede(a) { return 3 }
        return 0
    }
}

struct Instance {
    let requirement: [Int: PatternCell]
    let cube: Int
}

struct Cost {
    var stones: Int
    var spaces: Int
    var cubeSpaces: Int
    var frozen: Int
    /// The landscape points the layout carries on its own.
    var landscape: Int
    var layout: [Int: PatternCell]
    var cubes: [Int]
}

/// The cheapest set of `count` habitats, in one reading.
func cheapest(_ instances: [Instance], count: Int, side: BoardSide, growing: Bool) -> Cost? {
    let board = side.board
    let slot = Dictionary(uniqueKeysWithValues: board.cells.enumerated().map { ($1, $0) })
    let n = instances.count
    guard n >= count else { return nil }

    // Per instance, per space: the requirement's code, or -1.
    let requirement: [[Int8]] = instances.map { instance in
        var row = [Int8](repeating: -1, count: board.cells.count)
        for (cell, wanted) in instance.requirement { row[slot[cell]!] = Int8(code[wanted]!) }
        return row
    }
    let cubeSlot = instances.map { slot[$0.cube]! }

    // before[i][j]: i has to be finished before j. Pairs that cannot live
    // together at all are marked in `fits`.
    var fits = [[Bool]](repeating: [Bool](repeating: true, count: n), count: n)
    var before = [[Bool]](repeating: [Bool](repeating: false, count: n), count: n)
    for i in 0..<n {
        for j in 0..<n where i != j {
            if cubeSlot[i] == cubeSlot[j] { fits[i][j] = false; continue }
            for s in 0..<board.cells.count {
                let a = requirement[i][s], b = requirement[j][s]
                guard a >= 0, b >= 0 else { continue }
                switch relation[Int(a)][Int(b)] {
                case 0: fits[i][j] = false
                case 1: break
                case 2:
                    // i's stage comes first. Not at all in the fixed reading,
                    // and never if j's cube already sits on this space.
                    if !growing || cubeSlot[i] == s { fits[i][j] = false } else { before[i][j] = true }
                default:
                    if !growing || cubeSlot[j] == s { fits[i][j] = false } else { before[j][i] = true }
                }
            }
        }
    }

    var best = Int.max
    var winners: [(state: [Int8], cubes: [Int])] = []
    var chosen: [Int] = []

    func circular(_ set: [Int]) -> Bool {
        // Kahn on at most five habitats.
        var left = set
        while !left.isEmpty {
            guard let free = left.first(where: { i in
                !left.contains { j in j != i && before[j][i] }
            }) else { return true }
            left.removeAll { $0 == free }
        }
        return false
    }

    func walk(from start: Int, height state: [Int8], cost: Int) {
        if chosen.count == count {
            if growing && circular(chosen) { return }
            if cost < best { best = cost; winners = [] }
            if cost == best { winners.append((state, chosen.map { cubeSlot[$0] })) }
            return
        }
        guard start < n else { return }
        for i in start..<n {
            guard chosen.allSatisfy({ fits[$0][i] }) else { continue }
            var next = state
            var extra = 0
            for s in 0..<board.cells.count {
                let b = requirement[i][s]
                guard b >= 0 else { continue }
                let a = state[s]
                if a < 0 {
                    next[s] = b; extra += cells[Int(b)].height
                } else if relation[Int(a)][Int(b)] == 2 {
                    next[s] = b; extra += cells[Int(b)].height - cells[Int(a)].height
                }
            }
            guard cost + extra <= best else { continue }
            chosen.append(i)
            walk(from: i + 1, height: next, cost: cost + extra)
            chosen.removeLast()
        }
    }
    walk(from: 0, height: [Int8](repeating: -1, count: board.cells.count), cost: 0)
    guard best < Int.max else { return nil }

    // Among the cheapest layouts the one on the fewest spaces, then the one
    // whose stones score most.
    let empty = BoardScoring(side: side, columns: side.columns, stacks: [:])
        .breakdown().reduce(0) { $0 + $1.points }
    var top: Cost?
    for winner in winners {
        var stacks: [Int: [Stone]] = [:]
        var shown: [Int: PatternCell] = [:]
        for (s, value) in winner.state.enumerated() where value >= 0 {
            let wanted = cells[Int(value)]
            stacks[board.cells[s]] = wanted.stacks.first
            shown[board.cells[s]] = wanted
        }
        let points = BoardScoring(side: side, columns: side.columns, stacks: stacks)
            .breakdown().reduce(0) { $0 + $1.points } - empty
        let cubeCells = winner.cubes.map { board.cells[$0] }.sorted()
        let frozen = cubeCells.count { shown[$0] == .mountain1 || shown[$0] == .mountain2 }
        let candidate = Cost(stones: best, spaces: shown.count, cubeSpaces: cubeCells.count,
                             frozen: frozen, landscape: points, layout: shown, cubes: cubeCells)
        if let current = top {
            if candidate.spaces < current.spaces
                || (candidate.spaces == current.spaces && candidate.landscape > current.landscape) {
                top = candidate
            }
        } else {
            top = candidate
        }
    }
    return top
}

/// What a game lays and fills, from the self-play of 2026-10-04.
let stoneBudget = 30.0
let spaceBudget = 21.0

func stones(of card: AnimalCard) -> Int { card.pattern.values.reduce(0) { $0 + $1.height } }

let deck = try AnimalCards.load()
let only = CommandLine.arguments.dropFirst().first

func f(_ x: Double) -> String { String(format: "%.2f", x) }

if let only {
    guard let card = deck.first(where: { $0.name == only }) else {
        print("Keine Karte \(only)"); exit(2)
    }
    for side in [BoardSide.a, .b] {
        let found = Habitat.all(of: card, on: [:], board: side.board)
            .map { Instance(requirement: $0.requirement, cube: $0.cubeCell) }
        print("\(card.name), Seite \(side == .a ? "A" : "B"): \(found.count) Lagen, \(card.points.count) Würfel")
        for growing in [false, true] {
            guard let r = cheapest(found, count: card.points.count, side: side, growing: growing) else { continue }
            let layout = r.layout.sorted { $0.key < $1.key }.map {
                "\(cellName($0.key))=\($0.value.rawValue)\(r.cubes.contains($0.key) ? "*" : "")"
            }
            print("  \(growing ? "überbauen" : "fest     "): \(r.stones) Steine auf \(r.spaces) Feldern, "
                  + "\(r.cubeSpaces) mit Würfel (\(r.frozen) eingefroren), Landschaft \(r.landscape) — "
                  + layout.joined(separator: " "))
        }
    }
    exit(0)
}

struct Row {
    let name: String
    let cubes: Int
    let single: Int
    let best: Int
    var cost: [BoardSide: (fixed: Cost, growing: Cost)] = [:]
}

var rows: [Row] = []
for card in deck {
    var row = Row(name: card.name, cubes: card.points.count, single: stones(of: card),
                  best: card.points.last ?? 0)
    for side in [BoardSide.a, .b] {
        let found = Habitat.all(of: card, on: [:], board: side.board)
            .map { Instance(requirement: $0.requirement, cube: $0.cubeCell) }
        guard let fixed = cheapest(found, count: card.points.count, side: side, growing: false),
              let grown = cheapest(found, count: card.points.count, side: side, growing: true)
        else { continue }
        row.cost[side] = (fixed, grown)
    }
    rows.append(row)
    FileHandle.standardError.write(Data("\(card.name)\n".utf8))
}

// Sorted by points per stone for the whole card, side A, overbuilding.
func perStone(_ r: Row) -> Double {
    guard let c = r.cost[.a]?.growing else { return 0 }
    return Double(r.best) / Double(c.stones)
}
rows.sort { perStone($0) > perStone($1) }

print("| Karte | Würfel | Steine je Habitat | Steine gesamt | Felder | Würfelfelder | eingefroren "
      + "| Höchstpunkte | Landschaft | Punkte je Stein | (Punkte + Landschaft) je Stein "
      + "| (Punkte + Landschaft) je Feld | Auslastung | (Punkte + Landschaft) je 10 % Auslastung |")
print("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
var different: [String] = []
for r in rows {
    guard let a = r.cost[.a], let b = r.cost[.b] else {
        print("| \(r.name) | — |"); continue
    }
    let g = a.growing
    if a.fixed.stones != g.stones || b.growing.stones != g.stones || b.fixed.stones != g.stones {
        different.append("\(r.name) (A \(a.fixed.stones)/\(g.stones), B \(b.fixed.stones)/\(b.growing.stones))")
    }
    let total = Double(r.best + g.landscape)
    let load = (Double(g.stones) / stoneBudget + Double(g.spaces) / spaceBudget) / 2
    print("| \(r.name) | \(r.cubes) | \(r.single) | \(g.stones) | \(g.spaces) | \(g.cubeSpaces) "
          + "| \(g.frozen) | \(r.best) | \(g.landscape) | \(f(Double(r.best) / Double(g.stones))) "
          + "| \(f(total / Double(g.stones))) | \(f(total / Double(g.spaces))) "
          + "| \(f(100 * load)) % | \(f(total / (load * 10))) |")
}
func spread(_ values: [Double]) -> String {
    let sorted = values.sorted()
    return "\(f(sorted.first ?? 0)) bis \(f(sorted.last ?? 0)), Median \(f(sorted[sorted.count / 2]))"
}
let counted = rows.compactMap { r in r.cost[.a].map { (r, $0.growing) } }
print()
print("Punkte je Stein: \(spread(counted.map { Double($0.0.best) / Double($0.1.stones) })). "
      + "Mit Landschaft: \(spread(counted.map { Double($0.0.best + $0.1.landscape) / Double($0.1.stones) })). "
      + "Je Feld, mit Landschaft: \(spread(counted.map { Double($0.0.best + $0.1.landscape) / Double($0.1.spaces) })).")
print(different.isEmpty
      ? "Seite A und B, fest und überbaut ergeben bei allen Karten dieselbe Steinzahl."
      : "Abweichungen zwischen Seiten oder Lesarten: " + different.joined(separator: "; "))
