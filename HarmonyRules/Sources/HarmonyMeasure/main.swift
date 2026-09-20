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

// MARK: - Und was die Suche daraus macht

// A full search over an empty board runs for many minutes, which is itself
// the finding. Rather than sitting through it, the cost of one evaluation is
// timed and multiplied out: generating and weighing run together, so the
// whole is the one plus the other.

print("Was ein Zug kostet, und was die Suche daraus folgt\n")
print("Gewogen wird, wie die Suche es tut: einmal je Legung vorrechnen,")
print("dann die Züge darunter. Die Spalte »einzeln« ist dieselbe Bewertung")
print("ohne Vorgerechnetes — der Zustand vor dieser Beschleunigung.\n")
print(pad("belegt", 8) + pad("je Zug", 11) + pad("einzeln", 11) + pad("Züge", 12)
      + pad("Erzeugen", 12) + "Suche gesamt")

for down in [6, 12, 18] {
    let state = position(side: .a, stonesDown: down)

    let generated = Date()
    let moves = Moves.all(from: state)
    let generating = Date().timeIntervalSince(generated)
    guard let sample = moves.first else { continue }

    // Ein paar hundert Züge, damit die Zahl nicht am Rauschen hängt.
    let rounds = 200
    let available = Search.availability(after: sample.space, of: state)

    // So, wie die Suche rechnet: je Legung einmal vorrechnen.
    let anchors = Moves.standingHabitatCells(of: state)
    var weighed = 0
    let started = Date()
    for laying in Moves.layings(of: state.display[0], on: state) {
        if weighed >= rounds { break }
        let laid = state.laying(stacks: laying.stacks, space: 0)
        let prepared = Evaluator.prepare(laid, availability: available)
        for move in Moves.turns(space: 0, laying: laying, from: state, anchors: anchors) {
            weighed += 1
            _ = Evaluator.evaluate(state.applying(move), availability: available,
                                   prepared: move.cubes.isEmpty ? prepared : nil)
        }
    }
    let each = Date().timeIntervalSince(started) / Double(max(weighed, 1))

    // Und dieselbe Arbeit ohne Vorgerechnetes, zum Vergleich.
    let alone = Date()
    for move in moves.prefix(rounds) {
        _ = Evaluator.evaluate(state.applying(move), availability: available)
    }
    let single = Date().timeIntervalSince(alone) / Double(min(rounds, moves.count))

    print(pad("\(down)", 8)
          + pad(String(format: "%.0f µs", each * 1e6), 11)
          + pad(String(format: "%.0f µs", single * 1e6), 11)
          + pad(grouped(moves.count), 12)
          + pad(String(format: "%.1f s", generating), 12)
          + String(format: "%.0f s", generating + each * Double(moves.count)))
}

// Eine kleine Stellung ganz durchgerechnet, damit die Hochrechnung oben
// einen Beleg hat — und daneben dieselbe Suche auf einem Kern, damit
// sichtbar bleibt, was das Verteilen bringt.
var small = position(side: .a, stonesDown: 12)
small.display = [small.display[0]]

let serialStart = Date()
let serial = Search.best(from: small, cores: 1)
let serialTime = Date().timeIntervalSince(serialStart)

let manyStart = Date()
let suggestion = Search.best(from: small)
let manyTime = Date().timeIntervalSince(manyStart)

let cores = ProcessInfo.processInfo.activeProcessorCount
print(String(format: "\nEin Auslagenfeld, 12 Felder belegt, %d Züge:",
             suggestion?.weighed ?? 0))
print(String(format: "  ein Kern      %5.2f s", serialTime))
print(String(format: "  %2d Kerne      %5.2f s   ×%.2f", cores, manyTime, serialTime / manyTime))
if let suggestion {
    let where_ = suggestion.move.placements.keys.sorted().map { cellName($0) }
    print("  Vorschlag: \(where_.joined(separator: " "))"
          + (suggestion.move.cardTaken.map { " +\($0)" } ?? "")
          + String(format: ", Wert %.1f", suggestion.value)
          + (serial?.move == suggestion.move ? " — derselbe wie auf einem Kern"
                                             : " — ANDERER ZUG als auf einem Kern"))
}
