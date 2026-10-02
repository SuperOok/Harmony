import Foundation
import HarmonyRules
import HarmonyEngine

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

/// Störfall B: a cell set to what actually lies on the table.
///
/// **Not a turn.** It takes no stones out of the bag, it is not anybody's
/// move, and the seating does not advance — which is precisely what
/// `02-szenarien.md` asks for: correcting the app without the correction
/// becoming a regular move.
struct BoardCorrection {
    /// One space and what truly lies on it.
    struct Change {
        let cell: Int
        /// Bottom first. Empty clears the space.
        let stack: [Stone]
        /// The card the cube was taken from, `nil` for no cube.
        let cube: String?
    }

    /// **Several** spaces, not one.
    ///
    /// A single space cannot be corrected on its own without breaking the
    /// stone count: the grey stone that leaves 5.4 was demonstrably taken
    /// from the display and has to turn up somewhere. A correction is
    /// therefore always a rearrangement — what it may not do is conjure a
    /// stone or make one disappear. See `pruefverfahren.md`, Invarianten.
    let changes: [Change]

    /// Board notation, not move notation — a correction states a **state**
    /// and not a sequence of actions. The missing player name at the front
    /// is what marks it as something other than a turn. Spaces are written
    /// in a fixed order so that the same correction always reads the same.
    var notation: String {
        let parts = changes.sorted { $0.cell < $1.cell }.flatMap { change -> [String] in
            var written = ["\(change.cell)="
                           + (change.stack.isEmpty ? "—"
                              : change.stack.map(\.rawValue).joined())]
            if let cube = change.cube { written.append("T\(change.cell)/\(cube)") }
            return written
        }
        return (["!korr"] + parts).joined(separator: "  ")
    }
}

/// What happened, in order.
///
/// Phase 4 stores the sequence and derives the position by replaying it.
/// Three requirements then coincide: the undo from Störfall A is dropping
/// the last event, surviving a move to the background is writing the file,
/// and the same file is a ready-made test case.
enum GameEvent {
    case opponentTurn(OpponentTurn)
    /// Harmony's move is stored **as an event**, not as an instruction to
    /// compute it again. Replay therefore needs no engine and stays valid
    /// when the evaluation changes.
    case harmonyTurn(HarmonyMove)
    case correction(BoardCorrection)

    /// A correction sits in the sequence but is not a move. The bag, the
    /// seating and the round being played out all count turns, not events.
    var isTurn: Bool {
        if case .correction = self { return false }
        return true
    }
}

/// The position of the game as the app holds it: what Harmony knows, and
/// who is to move.
///
/// What Harmony knows is an `EngineState` — the one state the engine reasons
/// about, which events are entered into through `recordTurn`,
/// `recordOwnTurn` and `correct`. There used to be a second, the app's own,
/// with a bridge that translated between them; the bag count went wrong in
/// that translation. What is left here is only what the engine has no use
/// for: the names of the seating, and whose turn it is.
struct GameState {
    /// Harmony's name in the seating. She is found by it, so nobody else may
    /// carry it — the setup keeps it out of the list of players.
    static let harmonyName = "Harmony"

    /// Everything Harmony knows, as the engine holds it.
    var knowledge: EngineState
    var seatIndex: Int
    /// Seating in turn order, Harmony among them. Comes from the setup.
    var seating: [String]

    /// A position from the names and stones a setup or a saved game holds.
    ///
    /// The bag is what remains of the 120 stones after the display; the cards
    /// nobody has seen are all the others. Names have to be those of the
    /// card data — the pickers offer nothing else, and a saved game is
    /// checked before it gets here.
    init(display: [DisplayField], openCards: [String], seenCards: Set<String>,
         seatIndex: Int, harmonyBoard: [Int: [Stone]], harmonyCubes: [Int: String],
         harmonyCards: [AnimalCard], seating: [String], sideB: Bool) {
        let all = AnimalCards.all
        let byName = Dictionary(uniqueKeysWithValues: all.map { ($0.name, $0) })
        let open = openCards.map { name -> AnimalCard in
            guard let card = byName[name] else { fatalError("Keine Karte namens \(name)") }
            return card
        }
        let unavailable = seenCards.union(openCards).union(harmonyCards.map(\.name))
        knowledge = EngineState(
            side: sideB ? .b : .a,
            stacks: harmonyBoard,
            cubes: harmonyCubes,
            hand: harmonyCards.map { card in
                HeldCard(card: card, cubesPlaced: harmonyCubes.values.count { $0 == card.name })
            },
            display: display.map(\.stones),
            openCards: open,
            deck: all.filter { !unavailable.contains($0.name) },
            drawn: BagKnowledge.drawn(setup: display.map(\.stones), refills: []),
            turnsPlayed: 0,
            players: seating.count,
            // Without Harmony the position is not `isConsistent`, and
            // neither the setup nor `GameStore.load` lets it through.
            seat: seating.firstIndex(of: Self.harmonyName) ?? 0)
        self.seatIndex = seatIndex
        self.seating = seating
    }

    // MARK: - What the screens read

    var display: [DisplayField] { knowledge.display.map { DisplayField(stones: $0) } }
    var openCards: [String] { knowledge.openCards.map(\.name) }
    /// Every card that has lain open or been held — the complement of those
    /// nobody has seen.
    var seenCards: Set<String> {
        Set(AnimalCards.all.map(\.name)).subtracting(knowledge.deck.map(\.name))
    }
    var harmonyBoard: [Int: [Stone]] { knowledge.stacks }
    var harmonyCubes: [Int: String] { knowledge.cubes }
    /// The cards Harmony has taken.
    var harmonyCards: [AnimalCard] { knowledge.hand.map(\.card) }
    var sideB: Bool { knowledge.side == .b }

    /// What a position has to be to be shown at all: someone to move, a seat
    /// that exists, Harmony among the seats, and a display of at most five
    /// spaces. A saved game that fails this is thrown away rather than
    /// played on with Harmony moved to seat 0 (see `init`).
    var isConsistent: Bool {
        seating.indices.contains(seatIndex) && seating.contains(Self.harmonyName)
            && display.count <= EngineState.displaySpaces
    }

    var currentPlayer: String { seating[seatIndex] }
    /// Side A has 23 spaces, side B has 25 — the game ends two later there.
    var boardSize: Int { knowledge.side.board.cells.count }

    /// Why Harmony's own board ends the game, once two cells or fewer are
    /// left; `nil` before that.
    var boardEndReason: String? {
        let free = boardSize - harmonyBoard.count
        return free <= 2 ? "Harmonys Spielplan hat nur noch \(free) freie Felder." : nil
    }

    var isHarmonysTurn: Bool { currentPlayer == Self.harmonyName }

    static func initial(seat: Int = 0) -> GameState {
        GameState(display: Sample.display,
                  openCards: Sample.openCards,
                  seenCards: Set(Sample.openCards),
                  seatIndex: seat,
                  harmonyBoard: Sample.harmonyBoard,
                  harmonyCubes: [:],
                  harmonyCards: Sample.harmonyCards,
                  seating: Sample.turnOrder,
                  sideB: false)
    }

    /// A game played out, for looking at the final score without tapping
    /// through five and thirty turns first. Either board is a real end
    /// position: two free spaces, which is the second end trigger.
    ///
    /// The two sides need two boards, not one. Side B has 25 spaces in
    /// seven columns and side A has 23 in five, so a position for one does
    /// not even fit on the other — and water is scored by two different
    /// rules, the river against the islands.
    static func finished(sideB: Bool = false) -> GameState {
        GameState(display: Sample.display,
                  openCards: Sample.openCards,
                  seenCards: Set(Sample.openCards),
                  seatIndex: 0,
                  harmonyBoard: sideB ? Sample.harmonyBoardFinalB : Sample.harmonyBoardFinal,
                  harmonyCubes: sideB ? Sample.harmonyCubesFinalB : Sample.harmonyCubesFinal,
                  harmonyCards: sideB ? Sample.harmonyCardsB : Sample.harmonyCards,
                  seating: Sample.turnOrder,
                  sideB: sideB)
    }

    mutating func apply(_ event: GameEvent) {
        switch event {
        case let .opponentTurn(turn):
            knowledge.recordTurn(space: turn.taken, refill: turn.refill,
                                 cardTaken: turn.cardTaken, cardDrawn: turn.cardDrawn)
        case let .harmonyTurn(move):
            // Her turn empties a display space like anyone else's, and the
            // card she takes leaves the row like anyone else's. Leaving
            // either out would let her reckon with stones and cards that
            // are no longer there.
            knowledge.recordOwnTurn(
                space: move.space,
                placements: Dictionary(grouping: move.placements, by: \.cell)
                    .mapValues { $0.map(\.stone) },
                cubes: Dictionary(move.cubes.map { ($0.cell, $0.card) },
                                  uniquingKeysWith: { _, later in later }),
                refill: move.refill,
                cardTaken: move.cardTaken, cardDrawn: move.cardDrawn)
        case let .correction(correction):
            for change in correction.changes {
                knowledge.correct(cell: change.cell, stack: change.stack, cube: change.cube)
            }
            // No move was played, so it is still the same player's turn.
            return
        }
        seatIndex = (seatIndex + 1) % seating.count
    }

    /// Whether the event can be applied to this position: the space it names
    /// exists and its refill is a whole draw or none. A saved game is
    /// replayed through this before it is believed.
    func accepts(_ event: GameEvent) -> Bool {
        switch event {
        case let .opponentTurn(turn):
            return knowledge.display.indices.contains(turn.taken)
                && [0, EngineState.stonesPerSpace].contains(turn.refill.count)
        case let .harmonyTurn(move):
            return knowledge.display.indices.contains(move.space)
                && [0, EngineState.stonesPerSpace].contains(move.refill.count)
        case .correction:
            return true
        }
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
        case let .correction(correction):
            return correction.notation
        }
    }
}

/// The transcript as shown: one line per event, with what it cost in taps
/// and, for Harmony's own turns, the reason that can be reopened later.
struct LogEntry: Identifiable {
    /// The position in the transcript. Not a fresh identity per call: the
    /// entries are worked out again on every look at the screen, and a list
    /// whose rows change identity each time rebuilds all of them.
    let id: Int
    let line: String
    /// `nil` for what is not a turn. A correction costs taps as well, but
    /// they do not belong in the tap budget: that one measures the regular
    /// input path, and a correction is by design outside it.
    let taps: Int?
    let rationale: MoveRationale?
}

extension Array where Element == GameEvent {
    func entries(from start: GameState) -> [LogEntry] {
        var state = start
        var result: [LogEntry] = []
        for event in self {
            switch event {
            case let .opponentTurn(turn):
                result.append(LogEntry(id: result.count, line: state.line(for: event),
                                       taps: turn.taps, rationale: nil))
            case let .harmonyTurn(move):
                result.append(LogEntry(id: result.count, line: state.line(for: event),
                                       taps: 1, rationale: move.rationale))
            case .correction:
                result.append(LogEntry(id: result.count, line: state.line(for: event),
                                       taps: nil, rationale: nil))
            }
            state.apply(event)
        }
        return result
    }

    /// Turns, not events. Corrections lie in between and count for
    /// nothing — neither for the bag nor for the round being played out.
    var turnCount: Int { lazy.filter(\.isTurn).count }

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
        BagKnowledge.total.values.reduce(0, +) - EngineState.setupStones
            - EngineState.stonesPerTurn * turns
    }

    func endStatus(from start: GameState) -> EndStatus {
        var state = start
        let seats = Swift.max(start.seating.count, 1)
        var status = EndStatus()

        var turns = 0
        for event in self {
            state.apply(event)
            if event.isTurn { turns += 1 }
            var reason: String?

            if Self.stonesLeftInBag(afterTurns: turns) < EngineState.stonesPerTurn {
                reason = "Der Beutel ist leer."
            }
            if let boardReason = state.boardEndReason { reason = boardReason }
            if case let .opponentTurn(turn) = event, turn.boardNearlyFull {
                reason = "Eine Mitspielerin hat nur noch zwei freie Felder."
            }

            if let reason, status.reason == nil {
                status.reason = reason
                // The round is played out: on to the next multiple of the
                // number of seats.
                status.endsAfter = EngineState.roundOut(turns, players: seats)
            }
        }

        if let endsAfter = status.endsAfter {
            status.isOver = turnCount >= endsAfter
            status.turnsLeft = Swift.max(endsAfter - turnCount, 0)
        }
        return status
    }
}


// MARK: - Endwertung

/// Harmony's result at the end, in the two halves Szenario 4 names:
/// landscapes and animal cards. The humans count their own the way they
/// always have — the app does not offer to.
struct FinalScore {
    let landscapes: [ScoreGroup]
    let cards: ScoreGroup
    /// Cubes placed. The rules break a tie on this number, so it belongs
    /// on the screen even though Harmony cannot know the other scores.
    let cubesPlaced: Int

    var landscapeTotal: Int { landscapes.reduce(0) { $0 + $1.points } }
    var total: Int { landscapeTotal + cards.points }
}

extension GameState {
    var finalScore: FinalScore {
        let side: BoardSide = sideB ? .b : .a
        let scoring = BoardScoring(side: side, columns: side.columns,
                                   stacks: harmonyBoard)
        let lines = harmonyCards.map { card -> ScoreLine in
            let cubes = harmonyCubes.values.filter { $0 == card.name }.count
            return ScoreLine(
                label: cubes == 0
                    ? "\(card.name) — kein Würfel gelegt"
                    : "\(card.name) — \(cubes) von \(card.cubeSpaces) Würfeln",
                points: card.score(cubes: cubes))
        }
        return FinalScore(
            landscapes: scoring.breakdown(),
            cards: ScoreGroup(title: "Tierkarten", lines: lines,
                              note: "Gewertet wird die höchste sichtbare Zahl, "
                                  + "also der Wert unter dem zuletzt gelegten "
                                  + "Würfel. Verbliebene Würfel kosten nichts."),
            cubesPlaced: harmonyCubes.count)
    }
}
