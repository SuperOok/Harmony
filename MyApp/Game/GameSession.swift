import Foundation
import Observation
import HarmonyRules
import HarmonyEngine

/// The game being played: its events, and what follows from them.
///
/// The position is not stored, it is replayed from the events — one
/// mechanism for undo, for surviving the background and for producing a test
/// case (`04-architektur.md`). Replaying costs a pass over all of them, so
/// it happens once per change and not once per look at the screen: the
/// views read `state`, `end` and `bagEmpty` as plain values.
@Observable
final class GameSession {
    let start: GameState
    private(set) var events: [GameEvent]
    private(set) var state: GameState
    private(set) var end: EndStatus

    /// Called after every change to the events, so the game survives being
    /// put away.
    @ObservationIgnored private let onChange: ([GameEvent]) -> Void

    init(start: GameState, restored: [GameEvent] = [],
         onChange: @escaping ([GameEvent]) -> Void = { _ in }) {
        self.start = start
        self.events = restored
        self.state = restored.state(from: start)
        self.end = restored.endStatus(from: start)
        self.onChange = onChange
    }

    func append(_ event: GameEvent) {
        events.append(event)
        refresh()
    }

    /// Störfall A: dropping the last event and replaying. Everything the
    /// event touched comes back by itself — the display, the open cards,
    /// Harmony's board and whose turn it is.
    func undoLast() {
        guard !events.isEmpty else { return }
        events.removeLast()
        refresh()
    }

    private func refresh() {
        state = events.state(from: start)
        end = events.endStatus(from: start)
        onChange(events)
    }

    var turnCount: Int { events.turnCount }

    /// The transcript as shown. Worked out when asked for — only the
    /// history sheet wants it.
    var history: [LogEntry] { events.entries(from: start) }

    /// No refill is entered once the bag cannot serve a whole draw.
    var bagEmpty: Bool { [GameEvent].stonesLeftInBag(afterTurns: turnCount) < EngineState.stonesPerTurn }

    /// Changes exactly when the position does, which is when the engine has
    /// to think again.
    var positionKey: String { "\(events.count)/\(state.seatIndex)" }

    /// Why the game is over. Usually what the log worked out; on the direct
    /// route it is read off the board, which gives the same answer.
    var endReason: String? {
        end.reason ?? state.boardEndReason
    }
}
