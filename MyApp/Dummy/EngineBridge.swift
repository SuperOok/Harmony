import Foundation
import HarmonyRules
import HarmonyEngine

// The click dummy and the engine, joined. A **bridge**, not the merge:
// `docs/06-durchstich.md` foresees the dummy's state giving way to
// `EngineState` entirely, and that is its own piece of work. What is here
// serves one purpose — getting a computed move onto the device so its timing
// can be felt, which is the thing no measurement on a Mac answers.
//
// Everything in here translates. Nothing decides.

extension GameState {
    /// The position as the engine needs it.
    ///
    /// The dummy knows its cards only by name; the patterns come from
    /// `animals.json`. A name that is not in there is a mistake in the
    /// sample data and gives `nil` rather than a quietly wrong position.
    ///
    /// `endsAfter` is the end the log has announced, if any — see
    /// `EndStatus`. It is the only way a foreign full board reaches the
    /// engine.
    func engineState(events: [GameEvent], endsAfter: Int? = nil,
                     endForecast: [EndOutcome] = []) -> EngineState? {
        let deck = HarmonyRules.AnimalCards.all
        let byName = Dictionary(uniqueKeysWithValues: deck.map { ($0.name, $0) })

        func cards(_ names: [String]) -> [HarmonyRules.AnimalCard]? {
            var found: [HarmonyRules.AnimalCard] = []
            for name in names {
                guard let card = byName[name] else { return nil }
                found.append(card)
            }
            return found
        }

        guard let open = cards(openCards),
              let held = cards(harmonyCards.map(\.name))
        else { return nil }

        let hand = held.map { card in
            HeldCard(card: card,
                     cubesPlaced: harmonyCubes.values.count { $0 == card.name })
        }

        return EngineState(
            side: sideB ? .b : .a,
            stacks: harmonyBoard,
            cubes: harmonyCubes,
            hand: hand,
            display: display.map(\.stones),
            openCards: open,
            deck: deck.filter { !seenCards.contains($0.name) },
            drawn: stonesDrawn(events: events),
            turnsPlayed: events.turnCount,
            players: seating.count,
            seat: seating.firstIndex(of: "Harmony") ?? 0,
            endsAfter: endsAfter,
            endForecast: endForecast)
    }

    /// Everything that has left the bag: the fifteen of the setup and three
    /// per turn since. The setup's stones are the ones the sample display
    /// started with, the rest come out of the log.
    private func stonesDrawn(events: [GameEvent]) -> [Stone: Int] {
        var drawn: [Stone: Int] = [:]
        for field in Sample.display {
            for stone in field.stones { drawn[stone, default: 0] += 1 }
        }
        for event in events {
            guard case let .opponentTurn(turn) = event else { continue }
            for stone in turn.refill { drawn[stone, default: 0] += 1 }
        }
        return drawn
    }
}

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
        let harmony = start.seating.firstIndex(of: "Harmony")
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
    private var asRationale: MoveRationale {
        // A prospect is shown apart from a score, so the reason does not
        // claim more than it can. The engine already keeps them apart: an
        // outlook carries the probability it was weighted with.
        let shown = terms.map { term -> ScoreTerm in
            let isProspect = term.name.hasPrefix("Aussicht")
                || term.name == "Fluss" || term.name == "Inseln"
            return ScoreTerm(name: term.name,
                             points: Int(term.points.rounded()),
                             prospect: isProspect,
                             probability: isProspect ? probability(in: term.detail) : nil)
        }

        return MoveRationale(
            immediate: pointsNow,
            value: Int(value.rounded()),
            terms: shown,
            probabilityNote: "Die Wahrscheinlichkeiten stammen aus dem Beutel, "
                + "dessen Inhalt Harmony genau kennt.",
            runnerUp: runnerUp.map(notation) ?? "—",
            runnerUpImmediate: 0,
            runnerUpValue: Int((runnerUpValue ?? 0).rounded()),
            gapExplanation: runnerUp == nil
                ? "Es gab keinen zweiten Zug."
                : "Verglichen wird der Wert der Stellung, nicht die Punkte.")
    }

    /// The percentage the engine wrote into the term's detail, back as a
    /// fraction. Read rather than recomputed, so the screen shows the number
    /// the search actually used.
    private func probability(in detail: String?) -> Double? {
        guard let detail, let percent = detail.split(separator: "×").last else { return nil }
        let digits = percent.filter(\.isNumber)
        guard let value = Double(digits), value > 0 else { return nil }
        return value / 100
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
