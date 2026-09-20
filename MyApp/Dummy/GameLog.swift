import Foundation

/// What happened, in order.
///
/// Phase 4 stores the sequence and derives the position by replaying it.
/// Three requirements then coincide: the undo from Störfall A is dropping
/// the last event, surviving a move to the background is writing the file,
/// and the same file is a ready-made test case.
enum GameEvent {
    case opponentTurn(taken: Int, refill: [Stone],
                      cardTaken: String?, cardDrawn: String?, taps: Int)
    /// Harmony's move is stored **as an event**, not as an instruction to
    /// compute it again. Replay therefore needs no engine and stays valid
    /// when the evaluation changes.
    case harmonyTurn(HarmonyMove)
}

struct GameState {
    var display: [DisplayField]
    var openCards: [String]
    var seenCards: Set<String>
    var seatIndex: Int
    var harmonyBoard: [Int: [Stone]]
    var harmonyCubes: [Int: String]
    /// Seating in turn order, Harmony among them. Comes from the setup.
    var seating: [String]
    var sideB: Bool

    var currentPlayer: String { seating[seatIndex] }
    var isHarmonysTurn: Bool { currentPlayer == "Harmony" }

    static func initial(seat: Int = 0) -> GameState {
        GameState(display: Sample.display,
                  openCards: Sample.openCards,
                  seenCards: Set(Sample.openCards),
                  seatIndex: seat,
                  harmonyBoard: Sample.harmonyBoard,
                  harmonyCubes: [:],
                  seating: Sample.turnOrder,
                  sideB: false)
    }

    mutating func apply(_ event: GameEvent) {
        switch event {
        case let .opponentTurn(taken, refill, cardTaken, cardDrawn, _):
            // The emptied space takes the stones drawn for it.
            display[taken] = DisplayField(stones: refill)
            if let cardTaken, let cardDrawn,
               let index = openCards.firstIndex(of: cardTaken) {
                openCards[index] = cardDrawn
                seenCards.insert(cardDrawn)
            }
        case let .harmonyTurn(move):
            harmonyBoard = move.applied(to: harmonyBoard)
            for cube in move.cubes { harmonyCubes[cube.cell] = cube.card }
        }
        seatIndex = (seatIndex + 1) % seating.count
    }

    /// How the event reads in the transcript. Needs the state **before**
    /// it, because a space is named by what lay on it.
    func line(for event: GameEvent) -> String {
        switch event {
        case let .opponentTurn(taken, refill, cardTaken, cardDrawn, _):
            var parts = [currentPlayer, "-\(display[taken].notation)"]
            if let cardTaken { parts.append("+\(cardTaken)") }
            parts.append(">" + refill.map(\.rawValue).joined())
            if let cardDrawn { parts.append(">\(cardDrawn)") }
            return parts.joined(separator: "  ")
        case let .harmonyTurn(move):
            return "Harmony  \(move.notation)"
        }
    }
}

/// The transcript as shown: one line per event, with what it cost in taps
/// and, for Harmony's own turns, the reason that can be reopened later.
struct LogEntry: Identifiable {
    let id = UUID()
    let line: String
    let taps: Int
    let rationale: MoveRationale?
}

extension Array where Element == GameEvent {
    func entries(from start: GameState) -> [LogEntry] {
        var state = start
        var result: [LogEntry] = []
        for event in self {
            switch event {
            case let .opponentTurn(_, _, _, _, taps):
                result.append(LogEntry(line: state.line(for: event),
                                       taps: taps, rationale: nil))
            case let .harmonyTurn(move):
                result.append(LogEntry(line: state.line(for: event),
                                       taps: 1, rationale: move.rationale))
            }
            state.apply(event)
        }
        return result
    }

    func state(from start: GameState) -> GameState {
        var state = start
        for event in self { state.apply(event) }
        return state
    }
}
