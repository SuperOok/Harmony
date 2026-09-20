import Foundation
import HarmonyRules

// Counts the move space, which `docs/04-architektur.md` estimates at 10^4 to
// 10^5 own moves per position and expressly leaves to the walking skeleton to
// measure. It is pulled forward, ahead of evaluation and search: if the count
// comes out far above the estimate, the shape of those two changes, and it is
// cheaper to learn that before they are written than after.
//
// What is counted are **distinct resulting boards**, not orderings. Placing
// grey then brown on two different spaces gives the same table as brown then
// grey, and the engine must not treat them as two moves.

/// Left-aligned in a fixed width, so the columns line up in a terminal.
func pad(_ text: String, _ width: Int) -> String {
    text + String(repeating: " ", count: max(0, width - text.count))
}

/// Thousands separated, because these numbers are read for their order of
/// magnitude and not for their last digit.
func grouped(_ n: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = "."
    return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
}

/// A board as a comparable string, so that equal positions collapse.
func canonical(_ board: [Int: [Stone]]) -> String {
    board.keys.sorted()
        .map { "\($0):" + board[$0]!.map(\.rawValue).joined() }
        .joined(separator: " ")
}

/// Every board reachable by placing these stones, one at a time, anywhere the
/// stack rules allow. The stones of a display space are taken together and
/// all three are placed, as the rules require.
func outcomes(placing stones: [Stone], on board: [Int: [Stone]], cells: [Int]) -> Set<String> {
    var reached: Set<String> = []
    func step(_ board: [Int: [Stone]], _ left: ArraySlice<Stone>) {
        guard let stone = left.first else {
            reached.insert(canonical(board))
            return
        }
        for cell in cells {
            let stack = board[cell] ?? []
            guard stack.placeable.contains(stone) else { continue }
            var next = board
            next[cell] = stack + [stone]
            step(next, left.dropFirst())
        }
    }
    step(board, stones[...])
    return reached
}

/// A position with a given number of stones already down, built the same way
/// every time so the numbers can be compared across runs.
func position(stonesDown count: Int, cells: [Int]) -> [Int: [Stone]] {
    let colours: [Stone] = [.stone, .wood, .leaves, .water, .field, .brick]
    var board: [Int: [Stone]] = [:]
    for i in 0..<count {
        board[cells[i % cells.count]] = [colours[i % colours.count]]
    }
    return board
}

// The five display spaces of a real setup: three stones each, colours mixed.
let display: [[Stone]] = [
    [.stone, .wood, .leaves],
    [.water, .water, .field],
    [.brick, .stone, .stone],
    [.leaves, .field, .brick],
    [.wood, .wood, .stone],
]

/// Multisets of three stones drawn from six colours — the refill of the
/// emptied space, and the first of the two chance sources.
let refills = 56

print("Verzweigung je Stellung")
print("Gezählt werden verschiedene Endstellungen, nicht Reihenfolgen.\n")

for side in [BoardSide.a, BoardSide.b] {
    let cells = BoardScoring(side: side, columns: side.columns, stacks: [:]).allCells
    print("Seite \(side == .a ? "A" : "B"), \(cells.count) Felder")
    print(pad("belegt", 8) + pad("Steinzüge", 12) + pad("× Karte", 12) + pad("× Zufall", 14)
          + "Sekunden")

    for down in [0, 6, 12, 18] {
        guard down < cells.count else { continue }
        let board = position(stonesDown: down, cells: cells)
        let start = Date()
        var moves = 0
        for field in display {
            moves += outcomes(placing: field, on: board, cells: cells).count
        }
        let seconds = Date().timeIntervalSince(start)

        // Taking one of the five open cards, or none.
        let withCard = moves * 6
        // Below every move hangs the refill; a move that took a card also has
        // the card that moves up, out of a deck of 27 at the start.
        let withChance = withCard * refills

        print(pad("\(down)", 8) + pad(grouped(moves), 12) + pad(grouped(withCard), 12)
              + pad(grouped(withChance), 14) + String(format: "%.2f", seconds))
    }
    print()
}

print("""
Noch nicht enthalten: das Setzen der Tierwürfel und das Nachrücken einer
Karte. Beide kommen als Faktoren obendrauf, sobald Habitate und Kartenstapel
stehen.
""")
