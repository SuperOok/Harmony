import Foundation

/// What happened, in order.
///
/// Phase 4 stores the sequence and derives the position by replaying it.
/// Three requirements then coincide: the undo from Störfall A is dropping
/// the last event, surviving a move to the background is writing the file,
/// and the same file is a ready-made test case.
/// One recorded turn of another player. A struct rather than a pile of
/// associated values, because it keeps growing.
struct OpponentTurn {
    let taken: Int
    let refill: [Stone]
    var cardTaken: String? = nil
    var cardDrawn: String? = nil
    var taps: Int = 0
    /// Reported by the operator: this player's board has two or fewer free
    /// spaces, which ends the game. Harmony cannot see a foreign board, so
    /// this is the one thing she has to be told — at most once per game.
    var boardNearlyFull = false
}

enum GameEvent {
    case opponentTurn(OpponentTurn)
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
    /// Side A has 23 spaces, side B has 25 — the game ends two later there.
    var boardSize: Int { sideB ? 25 : 23 }
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
        case let .opponentTurn(turn):
            // The emptied space takes the stones drawn for it — unless the
            // bag ran dry, in which case it stays empty.
            if !turn.refill.isEmpty {
                display[turn.taken] = DisplayField(stones: turn.refill)
            }
            if let taken = turn.cardTaken, let drawn = turn.cardDrawn,
               let index = openCards.firstIndex(of: taken) {
                openCards[index] = drawn
                seenCards.insert(drawn)
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
        case let .opponentTurn(turn):
            var parts = [currentPlayer, "-\(display[turn.taken].notation)"]
            if let card = turn.cardTaken { parts.append("+\(card)") }
            if !turn.refill.isEmpty {
                parts.append(">" + turn.refill.map(\.rawValue).joined())
            }
            if let drawn = turn.cardDrawn { parts.append(">\(drawn)") }
            if turn.boardNearlyFull { parts.append("!voll") }
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
            case let .opponentTurn(turn):
                result.append(LogEntry(line: state.line(for: event),
                                       taps: turn.taps, rationale: nil))
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


// MARK: - Spielende

/// The two triggers from the rules, and the round that is played out after
/// one of them fires so that everyone has had the same number of turns.
struct EndStatus {
    /// `nil` while the game runs on.
    var reason: String?
    /// Number of recorded turns after which the game is over.
    var endsAfter: Int?
    var isOver = false
    var turnsLeft = 0
}

extension Array where Element == GameEvent {
    /// The bag holds 120 stones; fifteen fill the display at setup and
    /// three follow per turn. Harmony knows this without being told —
    /// every refill passes through the input anyway.
    static func stonesLeftInBag(afterTurns turns: Int) -> Int {
        120 - 15 - 3 * turns
    }

    func endStatus(from start: GameState) -> EndStatus {
        var state = start
        let seats = Swift.max(start.seating.count, 1)
        var status = EndStatus()

        for (index, event) in enumerated() {
            state.apply(event)
            let turns = index + 1
            var reason: String?

            if Self.stonesLeftInBag(afterTurns: turns) < 3 {
                reason = "Der Beutel ist leer."
            }
            let free = state.boardSize - state.harmonyBoard.count
            if free <= 2 {
                reason = "Harmonys Spielplan hat nur noch \(free) freie Felder."
            }
            if case let .opponentTurn(turn) = event, turn.boardNearlyFull {
                reason = "Eine Mitspielerin hat nur noch zwei freie Felder."
            }

            if let reason, status.reason == nil {
                status.reason = reason
                // The round is played out: on to the next multiple of the
                // number of seats.
                status.endsAfter = ((turns + seats - 1) / seats) * seats
            }
        }

        if let endsAfter = status.endsAfter {
            status.isOver = count >= endsAfter
            status.turnsLeft = Swift.max(endsAfter - count, 0)
        }
        return status
    }
}
