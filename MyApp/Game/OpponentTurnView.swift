import SwiftUI
import HarmonyRules
import HarmonyEngine

/// The screen of a game in progress. It decides which of the parts is on
/// show — another player's turn to be entered, Harmony's own to be played,
/// the final score — and hands each what it needs; the parts themselves are
/// in their own files.
///
/// The game is the sequence of events, and the position is replayed from it
/// (`GameSession`). Phase 4 chose this so that undo, surviving the
/// background and producing a test case are one mechanism rather than three.
struct OpponentTurnView: View {
    let startState: GameState
    /// Opens straight on the final score, the way `-harmonyTurn` opens on
    /// Harmony's screen. The position it shows is a real end position; only
    /// the round being over is asserted rather than played.
    var finished = false
    /// Throws the game away and returns to the setup.
    var onNewGame: () -> Void = {}

    @State private var session: GameSession
    @State private var search = HarmonySearch()
    /// Input of the turn in progress.
    @State private var input = TurnInput()
    @State private var cardPickerOpen = false
    @State private var historyOpen = false
    /// Störfall B. Reached from the transcript and nowhere else — the way
    /// is meant to be inconvenient, see `CorrectionView`.
    @State private var correctionOpen = false
    /// The reason currently on screen. Offered, not forced: the move stands
    /// on its own and the why is one tap away.
    @State private var shownRationale: MoveRationale?
    /// Harmony's turn, waiting for what the table has to tell her: the
    /// stones drawn for the space she emptied, and the card that moved up.
    /// She cannot know either, so she asks.
    @State private var harmonyReport: HarmonyMove?

    /// Keeps the sample move and leaves the engine alone.
    ///
    /// For the interface tests: they measure the **input path**, and a
    /// search that runs for a minute would only make them slow and flaky
    /// without measuring anything they are about. The sample moves are
    /// built for side A; on side B their cells do not all exist, so none
    /// is offered there.
    private let sampleOnly = Launch.has("-sampleMove")

    /// Writes out what a search cost. For measurements on the device, where
    /// neither the measuring tool runs nor anybody reads along.
    private let logsSearch = Launch.has("-logSearch")

    init(startState: GameState, restored: [GameEvent] = [], finished: Bool = false,
         onEventsChanged: @escaping ([GameEvent]) -> Void = { _ in },
         onNewGame: @escaping () -> Void = {}) {
        self.startState = startState
        self.finished = finished
        self.onNewGame = onNewGame
        _session = State(initialValue: GameSession(start: startState, restored: restored,
                                                   onChange: onEventsChanged))
    }

    private var state: GameState { session.state }
    private var isHarmony: Bool { state.isHarmonysTurn }
    private var isOver: Bool { session.end.isOver || finished }

    /// Harmony has a move to show whenever it is her turn. Undoing her turn
    /// brings it back, which is the replay doing its work.
    private var pendingMove: HarmonyMove? {
        guard isHarmony else { return nil }
        if sampleOnly { return state.sideB ? nil : Sample.harmonyMove }
        return search.computed
    }

    var body: some View {
        NavigationStack {
            Group {
                if isOver {
                    GameOverView(score: state.finalScore, endReason: session.endReason,
                                 onShowHistory: { historyOpen = true })
                } else if isHarmony {
                    HarmonyTurnView(state: state, move: pendingMove, search: search,
                                    onShowRationale: { shownRationale = $0 },
                                    onDone: harmonyDone)
                } else {
                    RecordTurnView(state: state, end: session.end, bagEmpty: session.bagEmpty,
                                   input: $input, cardPickerOpen: $cardPickerOpen,
                                   onRecord: record)
                }
            }
            .navigationTitle(isOver
                             ? "Endwertung"
                             : isHarmony ? "Harmony ist am Zug"
                                         : "\(state.currentPlayer) ist am Zug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { historyOpen = true } label: {
                        Text(isHarmony ? "\(session.turnCount) Züge" : "\(input.taps) ×")
                            .font(.footnote.monospacedDigit().weight(.semibold))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Capsule().fill(.quaternary))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("taps")
                }
            }
            .onChange(of: session.positionKey, initial: true) { think() }
            .onDisappear { search.stop() }
            .sheet(isPresented: Binding(get: { harmonyReport != nil },
                                        set: { if !$0 { harmonyReport = nil } })) {
                if let move = harmonyReport {
                    HarmonyReportSheet(move: move, bagEmpty: session.bagEmpty,
                                       seenCards: state.seenCards,
                                       onRecord: { turn in
                                           session.append(.harmonyTurn(turn))
                                           harmonyReport = nil
                                       })
                }
            }
            .sheet(isPresented: $search.isShown) {
                ThinkingView(monitor: search.monitor,
                             started: search.since ?? Date(),
                             turnsPlayed: session.turnCount,
                             onStop: { search.stop() },
                             onHide: { search.isShown = false })
            }
            .sheet(isPresented: $cardPickerOpen) { cardPicker }
            .sheet(isPresented: $historyOpen) { historySheet }
            .sheet(isPresented: $correctionOpen) {
                CorrectionView(state: state) { session.append(.correction($0)) }
            }
            .sheet(item: $shownRationale) { RationaleSheet(rationale: $0) }
        }
    }

    // MARK: - Turn change

    /// Runs the search when the position calls for one; whatever ran before
    /// belongs to the old position.
    private func think() {
        search.supersede()
        guard isHarmony, !sampleOnly else { return }
        search.begin(position: state.engineState(events: session.events, start: startState,
                                                 endsAfter: session.end.endsAfter),
                     takes: session.events.takes(from: startState),
                     names: state.seating,
                     settings: SettingsStore.current,
                     logsSearch: logsSearch)
    }

    private func record(_ turn: OpponentTurn) {
        session.append(.opponentTurn(turn))
        input.clear()
    }

    /// Harmony's turn has been played on the table. Nothing to report back
    /// when the bag is dry and no card was taken — then it goes straight
    /// into the log.
    private func harmonyDone(_ move: HarmonyMove) {
        if session.bagEmpty && move.cardTaken == nil {
            session.append(.harmonyTurn(move))
        } else {
            var move = move
            move.refill = []
            harmonyReport = move
        }
    }

    private func undoLast() {
        session.undoLast()
        input.clear()
    }

    // MARK: - Sheets

    /// The same picker the setup uses, limited to the one card that came
    /// up. It closes by itself once chosen.
    private var cardPicker: some View {
        NamePickerView(
            title: "Nachgerückt",
            options: Sample.allCards,
            unavailable: state.seenCards,
            limit: 1,
            chosen: Binding(get: { input.cardDrawn.map { [$0] } ?? [] },
                            set: { input.cardDrawn = $0.first }),
            onTap: { input.taps += 1 },
            onComplete: { cardPickerOpen = false })
    }

    private var historySheet: some View {
        HistorySheet(history: session.history,
                     canUndo: !session.events.isEmpty,
                     onUndo: { undoLast(); historyOpen = false },
                     onShowRationale: { historyOpen = false; shownRationale = $0 },
                     onCorrect: { historyOpen = false; correctionOpen = true },
                     onNewGame: { historyOpen = false; onNewGame() })
    }
}

#Preview {
    OpponentTurnView(startState: .initial())
}
