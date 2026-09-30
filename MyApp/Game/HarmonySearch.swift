import Foundation
import Observation
import HarmonyRules
import HarmonyEngine

/// The search for Harmony's turn, as the screen in front of it sees it.
///
/// A bridge, not the merge — see `EngineBridge.swift`. The search runs for
/// seconds to minutes, so it runs off the main thread and the screen says so
/// while it does. That is the point of putting it on a device at all: the
/// figure from a Mac says nothing about the table.
@Observable
final class HarmonySearch {
    /// The turn to play, once there is one. **Nothing while the engine
    /// thinks:** a made-up turn standing where the suggestion will go is
    /// worse than an empty space — at the table somebody would play it.
    private(set) var computed: HarmonyMove?
    /// When the game probably ends, for the line above the board. Worked
    /// out before the search, so that it does not wait for the turn.
    private(set) var endEstimate: EndEstimate?
    /// When the running search began; `nil` while none runs.
    private(set) var since: Date?
    private(set) var took: TimeInterval?
    private(set) var weighed = 0
    private(set) var complete = true
    /// The position could not be handed to the engine — a card it does not
    /// know. There is no suggestion then, and the screen says so.
    private(set) var failed = false
    /// Where the running search leaves its reports. A fresh one per search:
    /// the old one would still carry the last position's state, and that
    /// would not be recognisable as such on the screen.
    private(set) var monitor = SearchMonitor()
    /// Whether the screen that shows the reports is up. It opens by itself
    /// when a search starts: the alternative was a line under a board taller
    /// than the display, which on the device looks exactly like nothing
    /// happening.
    var isShown = false

    /// Held so the caretaker can stop it. A search that runs for minutes
    /// needs a way out, and stopping it is not giving up: the engine hands
    /// back the best it had found by then.
    @ObservationIgnored private var task: Task<Void, Never>?

    /// The position changed: whatever ran belongs to the old one.
    func supersede() {
        task?.cancel()
        endEstimate = nil
    }

    /// "That is enough": the search returns the best turn it had reached.
    func stop() { task?.cancel() }

    /// Starts on a position. `position` is `nil` when the app could not make
    /// one out of what it holds.
    ///
    /// - Parameters:
    ///   - takes: what the others have taken, for the end forecast.
    ///   - names: the seating, for the log line.
    ///   - settings: read afresh for each search, so a change applies from the
    ///     next turn on.
    ///   - logsSearch: write what the search cost to the standard output —
    ///     the only way to learn it on a device.
    func begin(position: EngineState?, takes: [(seat: Int, turns: [[Stone]])],
               names: [String], settings: EngineSettings, logsSearch: Bool) {
        // Cleared first: a suggestion left over from the previous position
        // must not stand where this one's belongs.
        computed = nil
        guard let position else { failed = true; return }
        failed = false
        took = nil
        let started = Date()
        since = started
        let monitor = SearchMonitor()
        self.monitor = monitor
        isShown = true
        let usesForecast = settings.forecastEnd

        task = Task {
            // The forecast first, on its own: it takes milliseconds, and the
            // line above the board should not wait for the search.
            let forecast = await Task.detached(priority: .userInitiated) {
                EndForecast.forecast(taken: takes, side: position.side,
                                     players: position.players,
                                     turnsPlayed: position.turnsPlayed,
                                     bag: position.bag)
            }.value
            guard self.monitor === monitor else { return }
            endEstimate = position.endEstimate(forecast)

            let work = Task.detached(priority: .userInitiated) {
                var position = position
                if usesForecast { position.endForecast = forecast.outcomes }
                if logsSearch {
                    print(Self.forecastLine(forecast, position, names: names,
                                            steering: usesForecast))
                }
                return HarmonyEngine.Search.best(from: position,
                                                 weights: settings.weights,
                                                 cancelled: { monitor.isStopped },
                                                 progress: { monitor.report($0) })
            }
            // The thinking time: after it, it is enough, as if stopped by
            // hand. The search then returns the best turn it has by then.
            let clock = settings.thinkingLimit.map { limit in
                Task.detached {
                    try? await Task.sleep(for: .seconds(limit))
                    if !Task.isCancelled { monitor.stop() }
                }
            }
            defer { clock?.cancel() }
            // Stopping means "that is enough", not "forget it": the search
            // returns the best turn it had reached. The flag goes to the
            // monitor, not to the task: the search works on several cores
            // and its threads have no task of their own.
            let suggestion = await withTaskCancellationHandler {
                await work.value
            } onCancel: {
                monitor.stop()
            }
            // Only if this search is still the running one. A superseded one
            // notices its cancellation only at the next checkpoint and would
            // arrive here when the next is long under way — it would close
            // that one's screen and overwrite its turn.
            guard self.monitor === monitor else { return }
            since = nil
            isShown = false
            took = Date().timeIntervalSince(started)
            weighed = suggestion?.weighed ?? 0
            complete = suggestion?.complete ?? true
            computed = suggestion?.asHarmonyMove

            // On the device there is no screen to read along and no
            // measuring tool: what the search costs there can only be
            // learned from the app itself. `xcrun devicectl device process
            // launch --console` picks this line up.
            if logsSearch {
                print(String(format: "SUCHE %.1f s, %d Züge, %@, %@%@",
                             took ?? 0, weighed,
                             computed?.notation ?? "—",
                             complete ? "vollständig" : "abgebrochen",
                             settings.isStandard ? "" : ", Spielstärke angepasst"))
            }
        }
    }

    /// One line for the log: what the forecast assumes about the others'
    /// boards and what follows from it for Harmony's turns left. At the table
    /// it can be held against the real boards.
    nonisolated private static func forecastLine(_ forecast: EndForecast,
                                                 _ position: EngineState,
                                                 names: [String], steering: Bool) -> String {
        let boards = forecast.taken.map { entry in
            String(format: "%@ %.1f±%.1f", names[entry.seat], entry.mean, entry.spread)
        }
        var withForecast = position
        withForecast.endForecast = forecast.outcomes
        let spread = withForecast.turnsLeftSpread.enumerated()
            .filter { $0.element >= 0.005 }
            .map { String(format: "%d: %.0f %%", $0.offset, $0.element * 100) }
        return "ENDE belegt \(boards.joined(separator: ", "))"
            + " — Restzüge sicher \(position.ownTurnsLeft),"
            + " vorhergesagt \(spread.joined(separator: ", "))"
            + (steering ? " — steuert" : " — abgeschaltet")
    }
}
