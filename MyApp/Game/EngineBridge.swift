import Foundation
import HarmonyRules
import HarmonyEngine

// What the engine says, in the shape the screens draw. The position itself
// needs no translation any more: `GameState` holds an `EngineState`, and
// events are entered into it directly. What is left here goes the other way
// — a suggestion becomes a `HarmonyMove`, a search report a line on screen —
// and the one replay the forecast asks for.
//
// Everything in here translates. Nothing decides.

extension Array where Element == GameEvent {
    /// What each opponent has taken, turn by turn: the three stones of the
    /// space they emptied. The log records the space, the display replayed
    /// from the start says what lay on it — so this costs no input at all.
    ///
    /// Seats as in the seating, which is also the order of play from the
    /// first turn on; `EndForecast` counts turns on that assumption.
    func takes(from start: GameState) -> [(seat: Int, turns: [[Stone]])] {
        var state = start
        var taken: [Int: [[Stone]]] = [:]
        for event in self {
            if case let .opponentTurn(turn) = event, turn.taken < state.display.count {
                taken[state.seatIndex, default: []].append(state.display[turn.taken].stones)
            }
            state.apply(event)
        }
        let harmony = start.seating.firstIndex(of: GameState.harmonyName)
        return start.seating.indices.filter { $0 != harmony }.map { ($0, taken[$0] ?? []) }
    }
}

extension Suggestion {
    /// The suggestion in the shape the screens already draw.
    ///
    /// The stones come out ordered by space and, within a space, bottom
    /// first — which is the only order they can be laid in anyway. The cubes
    /// follow, as `HarmonyMove` describes.
    var asHarmonyMove: HarmonyMove {
        let placements = move.placements.keys.sorted().flatMap { cell in
            move.placements[cell]!.map { Placement(stone: $0, cell: cell) }
        }
        let cubes = move.cubes.keys.sorted().map {
            CubePlacement(card: move.cubes[$0]!, cell: $0)
        }
        return HarmonyMove(space: move.space, placements: placements, cubes: cubes,
                           cardTaken: move.cardTaken, rationale: asRationale)
    }

    /// Why this move and not the next best one.
    var asRationale: MoveRationale {
        // A prospect is shown apart from a score, so the reason does not
        // claim more than it can. The engine says what kind of number each
        // term is, and gives a prospect's gain and probability as numbers.
        let shown = terms.map { term in
            ScoreTerm(name: term.name,
                      points: Int(term.points.rounded()),
                      kind: TermKind(term.kind),
                      gain: term.gain.map { Int($0.rounded()) },
                      probability: term.chance)
        }

        return MoveRationale(
            immediate: pointsNow,
            value: Int(value.rounded()),
            terms: shown,
            probabilityNote: "Die Wahrscheinlichkeiten stammen aus dem Beutel, "
                + "dessen Inhalt Harmony genau kennt.",
            runnerUp: runnerUp.map(notation) ?? "—",
            runnerUpImmediate: runnerUpPointsNow ?? 0,
            runnerUpValue: Int((runnerUpValue ?? 0).rounded()),
            gapExplanation: runnerUp == nil
                ? "Es gab keinen zweiten Zug."
                : "Verglichen wird der Wert der Stellung, nicht die Punkte.")
    }

    private func notation(_ move: Move) -> String { engineNotation(move) }
}

/// A move in the short written form, the one `docs/kartennotation.md` fixes.
///
/// Out here rather than inside a `Suggestion`, because a search that is
/// still running has a best move and no suggestion yet — and that move is
/// what the progress screen shows.
func engineNotation(_ move: Move) -> String {
    let stones = move.placements.keys.sorted().flatMap { cell in
        move.placements[cell]!.map { "\($0.rawValue)\(cell)" }
    }
    return (stones + move.cubes.keys.sorted().map { "T\($0)" })
        .joined(separator: " ")
}

/// A running search, seen from the screen in front of it.
///
/// The search runs on its own thread and reports a few hundred times a
/// minute; the screen asks four times a second. A lock and a single stored
/// report rather than a stream: nothing is gained by delivering every
/// report, and the search must never wait on the interface — that would
/// make watching it cost time the position does not have.
///
/// `@unchecked Sendable` is the claim that the lock does what the compiler
/// would otherwise check: every access to `latest` is inside it. And
/// `nonisolated`, weil dieser Typ seinen Sinn gerade darin hat, von zwei
/// Seiten benutzt zu werden — vom Suchlauf und vom Hauptstrang. Ohne das
/// Schlüsselwort läge er auf dem Hauptstrang, und die Suche würde ihn von
/// außen anfassen.
nonisolated final class SearchMonitor: @unchecked Sendable {
    private let lock = NSLock()
    private var latest: SearchProgress?
    private var stopped = false

    func report(_ progress: SearchProgress) {
        lock.lock()
        latest = progress
        lock.unlock()
    }

    /// Asks the search to stop. A flag rather than `Task.isCancelled`,
    /// because the search now works on several cores: its threads have no
    /// task of their own to ask, and `Task.isCancelled` would answer "no"
    /// on every one of them.
    func stop() {
        lock.lock()
        stopped = true
        lock.unlock()
    }

    var isStopped: Bool {
        lock.lock(); defer { lock.unlock() }
        return stopped
    }

    /// The most recent report, or nothing if the search has yet to send one.
    var current: SearchProgress? {
        lock.lock()
        defer { lock.unlock() }
        return latest
    }
}
