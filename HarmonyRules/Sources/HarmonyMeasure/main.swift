import Foundation
import HarmonyRules
import HarmonyEngine

// Counts the move space, which `docs/04-architektur.md` estimates at 10^4 to
// 10^5 own moves per position and expressly leaves to the walking skeleton to
// measure. It is pulled forward, ahead of evaluation and search: if the count
// comes out far above the estimate, the shape of those two changes, and it is
// cheaper to learn that before they are written than after.
//
// Counted are whole turns as the generator offers them — where the stones go,
// which card is taken, which cubes are laid — each distinct result once.

func pad(_ text: String, _ width: Int) -> String {
    text + String(repeating: " ", count: max(0, width - text.count))
}

func grouped(_ n: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = "."
    return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
}

let deck = try AnimalCards.load()

/// A position built the same way every time, so the numbers can be compared
/// across runs: `stonesDown` single stones spread over the board, five open
/// cards, and a hand of four.
func position(side: BoardSide, stonesDown count: Int) -> EngineState {
    let cells = side.board.cells
    let colours: [Stone] = [.stone, .wood, .leaves, .water, .field, .brick]
    var stacks: [Int: [Stone]] = [:]
    for i in 0..<count { stacks[cells[i % cells.count]] = [colours[i % colours.count]] }

    return EngineState(
        side: side,
        stacks: stacks,
        // Two cards, not four: with four unfinished ones no fifth may be
        // taken, and the card branch of the turn would fall away unnoticed.
        hand: deck.prefix(2).map { HeldCard(card: $0) },
        display: [[.stone, .wood, .leaves], [.water, .water, .field],
                  [.brick, .stone, .stone], [.leaves, .field, .brick],
                  [.wood, .wood, .stone]],
        openCards: Array(deck.dropFirst(2).prefix(5)),
        deck: Array(deck.dropFirst(7)),
        drawn: [.stone: 6, .wood: 4, .leaves: 3, .water: 2, .field: 3, .brick: 2],
        turnsPlayed: count / 3)
}

/// Multisets of three stones drawn from six colours — the refill of the
/// emptied space, and the first of the two chance sources.
let refills = 56

print("Verzweigung je Stellung")
print("Gezählt werden ganze Züge, jede Endstellung einmal.\n")

for side in [BoardSide.a, .b] {
    print("Seite \(side == .a ? "A" : "B"), \(side.board.cells.count) Felder")
    print(pad("belegt", 8) + pad("Züge", 14) + pad("davon m. Würfel", 17)
          + pad("× Zufall", 16) + "Sekunden")

    for down in [0, 6, 12, 18] {
        let state = position(side: side, stonesDown: down)
        guard state.freeCells > 3 else { continue }
        let start = Date()
        let moves = Moves.all(from: state)
        let seconds = Date().timeIntervalSince(start)
        let withCubes = moves.count { !$0.cubes.isEmpty }

        print(pad("\(down)", 8) + pad(grouped(moves.count), 14)
              + pad(grouped(withCubes), 17)
              + pad(grouped(moves.count * refills), 16)
              + String(format: "%.2f", seconds))
    }
    print()
}

print("""
Die Spalte »× Zufall« zählt die Nachfüllung des geleerten Feldes, nicht das
Nachrücken einer Karte. Sie ist die Zahl, die die Zusammenfassung der
Zufallsschicht vermeidet — siehe `docs/06-durchstich.md`.
""")
