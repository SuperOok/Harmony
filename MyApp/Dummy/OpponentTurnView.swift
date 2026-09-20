import SwiftUI
import HarmonyRules
import HarmonyEngine

/// Phase 5 click-through prototype: recording other players' turns, one
/// after another. No engine and no rule checking — what is measured is the
/// input path itself, in taps, as `pruefverfahren.md` foresees for storey
/// three. User-facing text is German, everything else English.
struct OpponentTurnView: View {
    /// The game is the sequence of events; the position is replayed from
    /// it. Phase 4 chose this so that undo, surviving the background and
    /// producing a test case are one mechanism rather than three.
    @State private var events: [GameEvent] = []

    /// The position the log starts from — what the setup produced.
    let startState: GameState
    /// What was already played when the app came back.
    var restored: [GameEvent] = []
    /// Opens straight on the final score, the way `-harmonyTurn` opens on
    /// Harmony's screen. The position it shows is a real end position; only
    /// the round being over is asserted rather than played.
    var finished = false
    /// Called after every event, so the game survives being put away.
    var onEventsChanged: ([GameEvent]) -> Void = { _ in }
    /// Throws the game away and returns to the setup.
    var onNewGame: () -> Void = {}

    // Input of the turn in progress
    @State private var takenIndex: Int?
    @State private var refill: [Stone] = []
    @State private var cardTaken: String?
    @State private var cardDrawn: String?
    @State private var taps = 0
    @State private var cardPickerOpen = false
    @State private var historyOpen = false
    @State private var showSideB = false
    /// Reported with the turn being recorded: this player's board is full.
    /// Harmony cannot see a foreign board — this is the one thing she has
    /// to be told, at most once per game.
    @State private var boardNearlyFull = false
    @State private var showSetupExample = false
    /// Störfall B. Reached from the transcript and nowhere else — the way
    /// is meant to be inconvenient, see `CorrectionView`.
    @State private var correctionOpen = false
    /// The reason currently on screen. Offered, not forced: the move stands
    /// on its own and the why is one tap away.
    @State private var shownRationale: MoveRationale?

    /// What the engine worked out, and how long it took.
    ///
    /// A bridge, not the merge — see `EngineBridge.swift`. The search runs
    /// for seconds to minutes, so it runs off the main thread and the screen
    /// says so while it does. That is the point of putting it on a device at
    /// all: the figure from a Mac says nothing about the table.
    @State private var computed: HarmonyMove?
    @State private var thinkingSince: Date?
    @State private var thinkingTook: TimeInterval?
    @State private var thinkingWeighed = 0
    @State private var thinkingComplete = true
    @State private var engineFailed = false
    /// Held so the caretaker can stop it. A search that runs for minutes
    /// needs a way out, and stopping it is not giving up: the engine hands
    /// back the best it had found by then.
    @State private var thinker: Task<Void, Never>?
    /// Where the running search leaves its reports, and whether the screen
    /// that shows them is up. It opens by itself when a search starts: the
    /// alternative was a line under a board taller than the display, which
    /// on the device looks exactly like nothing happening.
    @State private var monitor = SearchMonitor()
    @State private var thinkingOpen = false
    /// Harmony's turn, waiting for what the table has to tell her: the
    /// stones drawn for the space she emptied, and the card that moved up.
    /// She cannot know either, so she asks.
    @State private var harmonyReport: HarmonyMove?
    @State private var reportCardPicker = false

    private var state: GameState { events.state(from: startState) }
    private var end: EndStatus { events.endStatus(from: startState) }
    /// No refill is entered once the bag cannot serve three stones.
    private var bagEmpty: Bool {
        [GameEvent].stonesLeftInBag(afterTurns: events.turnCount) < 3
    }
    private var history: [LogEntry] { events.entries(from: startState) }

    /// Why the game is over. Usually what the log worked out; on the direct
    /// route it is read off the board, which gives the same answer.
    private var endReason: String? {
        if let reason = end.reason { return reason }
        let free = state.boardSize - state.harmonyBoard.count
        return free <= 2
            ? "Harmonys Spielplan hat nur noch \(free) freie Felder."
            : nil
    }

    private var currentPlayer: String { state.currentPlayer }
    private var isHarmony: Bool { state.isHarmonysTurn }

    /// Harmony has a move to show whenever it is her turn. Undoing her turn
    /// brings it back, which is the replay doing its work.
    /// The sample moves are built for side A; on side B their cells do not
    /// all exist, so none is offered there.
    /// Keeps the sample move and leaves the engine alone.
    ///
    /// For the interface tests: they measure the **input path**, and a
    /// search that runs for a minute would only make them slow and flaky
    /// without measuring anything they are about.
    private let sampleOnly = ProcessInfo.processInfo.arguments.contains("-sampleMove")

    private var pendingMove: HarmonyMove? {
        guard isHarmony else { return nil }
        if sampleOnly { return state.sideB ? nil : Sample.harmonyMove }
        // The sample move stays reachable through the picker, because it is
        // what the screens were built against. Side B has no sample: its
        // cells are not all there.
        if showSetupExample { return state.sideB ? nil : Sample.harmonyMoveSetup }
        // **Nothing while the engine thinks.** A made-up move standing where
        // the suggestion will go is worse than an empty space: at the table
        // somebody would play it.
        return computed
    }

    /// Changes exactly when the position does, which is when the engine has
    /// to think again.
    private var positionKey: String {
        "\(events.count)/\(state.seatIndex)/\(showSetupExample)"
    }

    /// Runs the search off the main thread. Cancelled by SwiftUI as soon as
    /// the position changes, which the engine asks about while it works.
    private func think() {
        thinker?.cancel()
        guard isHarmony, !showSetupExample, !sampleOnly else { return }
        guard let position = state.engineState(events: events) else {
            engineFailed = true
            return
        }
        engineFailed = false
        computed = nil
        thinkingTook = nil
        let started = Date()
        thinkingSince = started
        // Ein frischer Melder je Suche: der alte trüge noch den Stand der
        // vorigen Stellung, und der wäre auf dem Bildschirm nicht als solcher
        // zu erkennen.
        let monitor = SearchMonitor()
        self.monitor = monitor
        thinkingOpen = true

        thinker = Task {
            let work = Task.detached(priority: .userInitiated) {
                HarmonyEngine.Search.best(from: position,
                                          cancelled: { monitor.isStopped },
                                          progress: { monitor.report($0) })
            }
            // Stopping means "that is enough", not "forget it": the search
            // returns the best turn it had reached. The flag goes to the
            // monitor, not to the task: the search works on several cores
            // and its threads have no task of their own.
            let suggestion = await withTaskCancellationHandler {
                await work.value
            } onCancel: {
                monitor.stop()
            }
            // Nur, wenn diese Suche noch die laufende ist. Eine abgelöste
            // merkt ihren Abbruch erst beim nächsten Prüfpunkt und käme
            // sonst hier an, wenn längst die nächste rechnet — sie würde
            // deren Bildschirm schließen und ihren Zug überschreiben.
            guard self.monitor === monitor else { return }
            thinkingSince = nil
            thinkingOpen = false
            thinkingTook = Date().timeIntervalSince(started)
            thinkingWeighed = suggestion?.weighed ?? 0
            thinkingComplete = suggestion?.complete ?? true
            computed = suggestion?.asHarmonyMove
        }
    }

    private var isComplete: Bool {
        takenIndex != nil && (refill.count == 3 || bagEmpty)
            && (cardTaken == nil || cardDrawn != nil)
    }

    var body: some View {
        NavigationStack {
            Group {
                if end.isOver || finished { gameOver }
                else if isHarmony { harmonyTurn } else { entry }
            }
            .navigationTitle(end.isOver || finished
                             ? "Endwertung"
                             : isHarmony ? "Harmony ist am Zug"
                                         : "\(currentPlayer) ist am Zug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { historyOpen = true } label: {
                        Text(isHarmony ? "\(events.turnCount) Züge" : "\(taps) ×")
                            .font(.footnote.monospacedDigit().weight(.semibold))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Capsule().fill(.quaternary))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("taps")
                }
            }
            .onAppear { if events.isEmpty, !restored.isEmpty { events = restored } }
            .onChange(of: events.count) { onEventsChanged(events) }
            .onChange(of: positionKey, initial: true) { think() }
            .sheet(isPresented: Binding(get: { harmonyReport != nil },
                                        set: { if !$0 { harmonyReport = nil } })) {
                harmonyReportSheet
            }
            .onDisappear { thinker?.cancel() }
            .sheet(isPresented: $thinkingOpen) {
                ThinkingView(monitor: monitor,
                             started: thinkingSince ?? Date(),
                             turnsPlayed: events.turnCount,
                             onStop: { thinker?.cancel() },
                             onHide: { thinkingOpen = false })
            }
            .sheet(isPresented: $cardPickerOpen) { cardPicker }
            .sheet(isPresented: $historyOpen) { historyList }
            .sheet(isPresented: $correctionOpen) {
                CorrectionView(state: state) { events.append(.correction($0)) }
            }
            .sheet(item: $shownRationale) { rationaleSheet($0) }
        }
    }

    // MARK: - Recording another player's turn

    private var entry: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let reason = end.reason, !end.isOver { lastRoundBanner(reason) }
                displaySection
                if takenIndex != nil {
                    if bagEmpty {
                        TitledBlock("Nachfüllen entfällt") {
                            Text("Der Beutel ist leer; das Feld bleibt frei.")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                    } else {
                        refillSection
                    }
                }
                cardSection
                fullBoardToggle
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) { footer }
    }

    private var displaySection: some View {
        TitledBlock("Welches Feld wurde genommen?") {
            VStack(spacing: 8) {
                ForEach(Array(state.display.enumerated()), id: \.element.id) { index, field in
                    Button {
                        taps += 1
                        takenIndex = index
                        refill = []
                    } label: {
                        HStack(spacing: 10) {
                            ForEach(Array(field.ordered.enumerated()), id: \.offset) { _, stone in
                                StoneDot(stone: stone, size: 30)
                            }
                            Spacer()
                            if takenIndex == index {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(takenIndex == index ? Color.accentColor.opacity(0.14)
                                                          : Color(.secondarySystemBackground))
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("field-\(index)")
                }
            }
        }
    }

    private var refillSection: some View {
        TitledBlock("Was wurde nachgefüllt?") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { i in
                        StoneDot(stone: i < refill.count ? refill[i] : nil)
                    }
                    Spacer()
                    if !refill.isEmpty {
                        Button("Zurück") {
                            taps += 1
                            refill.removeLast()
                        }
                        .font(.footnote)
                        .accessibilityIdentifier("refill-undo")
                    }
                }
                HStack(spacing: 8) {
                    ForEach(Stone.allCases) { stone in
                        Button {
                            taps += 1
                            if refill.count < 3 { refill.append(stone) }
                        } label: {
                            StoneDot(stone: stone, size: 44)
                        }
                        .buttonStyle(.plain)
                        .disabled(refill.count == 3)
                        .opacity(refill.count == 3 ? 0.35 : 1)
                        .accessibilityIdentifier("palette-\(stone.rawValue)")
                        .accessibilityLabel(stone.name)
                    }
                }
            }
        }
    }

    private var cardSection: some View {
        TitledBlock("Wurde eine Karte genommen?") {
            VStack(alignment: .leading, spacing: 12) {
                FlowLayout(spacing: 8) {
                    ForEach(Sample.sorted(state.openCards), id: \.self) { name in
                        Button {
                            taps += 1
                            if cardTaken == name {
                                cardTaken = nil; cardDrawn = nil
                            } else {
                                cardTaken = name; cardDrawn = nil
                            }
                        } label: {
                            Text(name)
                                .font(.callout)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(
                                    Capsule().fill(cardTaken == name
                                        ? Color.accentColor.opacity(0.18)
                                        : Color(.secondarySystemBackground))
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("card-\(name)")
                    }
                }
                if cardTaken != nil {
                    Button {
                        taps += 1
                        cardPickerOpen = true
                    } label: {
                        HStack {
                            Text(cardDrawn ?? "Welche Karte rückte nach?")
                                .foregroundStyle(cardDrawn == nil ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("drawn")
                }
            }
        }
    }

    // MARK: - Harmony's turn (placeholder around the board)

    /// Szenario 3: the move as an instruction. Shown is the **target
    /// state** — the starting state lies on the table next to the device —
    /// with a ring around every space that changes and a number for each
    /// stone in the order it is placed.
    private var harmonyTurn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Beispiel", selection: $showSetupExample) {
                    Text("Punktet sofort").tag(false)
                    Text("Bereitet vor").tag(true)
                }
                .pickerStyle(.segmented)

                // Über dem Brett, nicht darunter: das Brett ist höher als
                // der Bildschirm, und was unter ihm steht, sieht am Tisch
                // niemand.
                engineStatus

                BoardView(side: state.sideB ? .b : .a,
                          columns: state.sideB ? BoardView.sideB : BoardView.sideA,
                          cells: harmonyCells)
                    .padding(.horizontal, 4)

                if pendingMove == nil && thinkingSince != nil {
                    Text("Der Vorschlag erscheint, sobald die Rechnung steht. "
                         + "Bis dahin steht hier nichts — ein ausgedachter Zug "
                         + "an dieser Stelle würde am Tisch gespielt.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                if let move = pendingMove {
                    TitledBlock("Was zu tun ist") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nimm das Feld mit \(fieldInWords(move)).")
                                .font(.callout.weight(.semibold))
                            ForEach(Array(move.placements.enumerated()), id: \.offset) { index, p in
                                Text("\(index + 1)  \(p.stone.name) auf \(cellInWords(p.cell)) — "
                                     + landscapeInWords(p.cell, move))
                                    .font(.callout)
                            }
                            ForEach(Array(move.cubes.enumerated()), id: \.offset) { _, c in
                                Text("Würfel von **\(c.card)** auf \(cellInWords(c.cell))")
                                    .font(.callout)
                            }
                            if let card = move.cardTaken {
                                Text("Nimm die Karte **\(card)**.")
                                    .font(.callout)
                            }
                        }
                    }

                    Button {
                        shownRationale = move.rationale
                    } label: {
                        HStack {
                            Image(systemName: "questionmark.circle")
                            Text(move.rationale.isProspective
                                 ? "\(move.rationale.immediate) Punkte jetzt · "
                                   + "Bewertung \(move.rationale.value) · "
                                   + "\(move.rationale.gap) mehr"
                                 : "\(move.rationale.value) Punkte · "
                                   + "\(move.rationale.gap) mehr als der nächstbeste")
                            Spacer()
                            Image(systemName: "chevron.right").font(.footnote)
                        }
                        .font(.callout)
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("why")

                    Text("Gezeigt ist der Zielzustand. Der Ausgangszustand liegt "
                         + "auf dem Tisch. Ringe markieren, was sich ändert.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text(state.sideB
                         ? "Der Beispielzug ist für Seite A gebaut; auf Seite B "
                           + "gibt es seine Zellen nicht alle."
                         : "Zug eingetragen. Das Brett zeigt jetzt den Stand, "
                           + "der auch auf dem Tisch liegen sollte.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) { harmonyFooter }
    }

    /// Target state while a move is pending, plain state afterwards.
    private var harmonyCells: [Int: BoardView.Cell] {
        guard let move = pendingMove else {
            var cells = state.harmonyBoard.mapValues { BoardView.Cell(stack: $0) }
            for (cell, _) in state.harmonyCubes { cells[cell]?.cube = true }
            return cells
        }
        let target = move.applied(to: state.harmonyBoard)
        let markers = move.markers
        let cubeCells = Set(state.harmonyCubes.keys).union(move.cubes.map(\.cell))
        let newCubes = Set(move.cubes.map(\.cell))
        var cells: [Int: BoardView.Cell] = [:]
        for (name, stack) in target {
            cells[name] = BoardView.Cell(
                stack: stack,
                cube: cubeCells.contains(name),
                marker: markers[name],
                highlighted: markers[name] != nil || newCubes.contains(name))
        }
        return cells
    }

    /// What the engine is doing, and what it cost. On the table this line
    /// is the whole experiment: a suggestion nobody waits for is no
    /// suggestion.
    @ViewBuilder private var engineStatus: some View {
        if engineFailed {
            Label("Die Engine kennt eine dieser Karten nicht — gezeigt wird der "
                  + "Beispielzug.", systemImage: "exclamationmark.triangle")
                .font(.footnote).foregroundStyle(.secondary)
        } else if let since = thinkingSince {
            TimelineView(.periodic(from: since, by: 0.5)) { context in
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Harmony rechnet — "
                         + String(format: "%.0f s", context.date.timeIntervalSince(since)))
                        .font(.footnote.monospacedDigit())
                    Spacer()
                    Button("Ansehen") { thinkingOpen = true }
                        .font(.footnote)
                        .accessibilityIdentifier("show-thinking")
                    Button("Das genügt") { thinker?.cancel() }
                        .font(.footnote)
                        // Erst wenn ein Zug gefunden ist. Vorher abbrechen
                        // hieße: kein Vorschlag und kein Weg zu einem, denn
                        // gerechnet wird nur, wenn sich die Stellung ändert.
                        .disabled(monitor.current?.best == nil)
                        .accessibilityIdentifier("stop-thinking")
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accentColor.opacity(0.14)))
                .accessibilityIdentifier("thinking")
            }
        } else if let took = thinkingTook {
            Label(String(format: "%@ in %.1f Sekunden, %d Züge geprüft",
                         thinkingComplete ? "Gerechnet" : "Abgebrochen",
                         took, thinkingWeighed),
                  systemImage: thinkingComplete ? "stopwatch" : "hand.raised")
                .font(.footnote).foregroundStyle(.secondary)
                .accessibilityIdentifier("thinking-took")
        }
    }

    /// What the table tells Harmony after her turn.
    ///
    /// She took three stones out of a space and, if the move said so, a
    /// card. What came back out of the bag and which card moved up she
    /// cannot know — and guessing it would be exactly the invented data
    /// this app exists to avoid. So the same palette as for anyone else's
    /// turn, and the same card picker.
    private var harmonyReportSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !bagEmpty {
                        TitledBlock("Was wurde nachgefüllt?") {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(spacing: 10) {
                                    ForEach(0..<3, id: \.self) { i in
                                        StoneDot(stone: i < (harmonyReport?.refill.count ?? 0)
                                                 ? harmonyReport?.refill[i] : nil)
                                    }
                                    Spacer()
                                    if !(harmonyReport?.refill.isEmpty ?? true) {
                                        Button("Zurück") { harmonyReport?.refill.removeLast() }
                                            .font(.footnote)
                                            .accessibilityIdentifier("harmony-refill-undo")
                                    }
                                }
                                HStack(spacing: 8) {
                                    ForEach(Stone.allCases) { stone in
                                        Button {
                                            if (harmonyReport?.refill.count ?? 3) < 3 {
                                                harmonyReport?.refill.append(stone)
                                            }
                                        } label: {
                                            StoneDot(stone: stone, size: 44)
                                        }
                                        .buttonStyle(.plain)
                                        .disabled((harmonyReport?.refill.count ?? 0) == 3)
                                        .opacity((harmonyReport?.refill.count ?? 0) == 3 ? 0.35 : 1)
                                        .accessibilityIdentifier("harmony-palette-\(stone.rawValue)")
                                        .accessibilityLabel(stone.name)
                                    }
                                }
                            }
                        }
                    } else {
                        TitledBlock("Nachfüllen entfällt") {
                            Text("Der Beutel ist leer; das Feld bleibt frei.")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                    }

                    if let taken = harmonyReport?.cardTaken {
                        TitledBlock("Welche Karte rückte nach?") {
                            Button {
                                reportCardPicker = true
                            } label: {
                                HStack {
                                    Text(harmonyReport?.cardDrawn ?? "Für \(taken) nachgerückt")
                                        .foregroundStyle(harmonyReport?.cardDrawn == nil
                                                         ? .secondary : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.footnote).foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 11)
                                .background(RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemBackground)))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("harmony-drawn")
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Harmonys Zug nachtragen")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button {
                    if let move = harmonyReport {
                        events.append(.harmonyTurn(move))
                        harmonyReport = nil
                    }
                } label: {
                    Text("Eintragen").frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!(harmonyReport?.isComplete(bagEmpty: bagEmpty) ?? false))
                .padding(.horizontal).padding(.vertical, 8)
                .background(.bar)
                .accessibilityIdentifier("harmony-record")
            }
            .sheet(isPresented: $reportCardPicker) {
                NamePickerView(
                    title: "Nachgerückt",
                    options: Sample.allCards,
                    unavailable: state.seenCards,
                    limit: 1,
                    chosen: Binding(get: { harmonyReport?.cardDrawn.map { [$0] } ?? [] },
                                    set: { harmonyReport?.cardDrawn = $0.first }),
                    onComplete: { reportCardPicker = false })
            }
        }
    }

    private var harmonyFooter: some View {
        VStack(spacing: 8) {
            Text(pendingMove.map { "Harmony  \($0.notation)" } ?? "Harmony  —")
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("notation")

            Button("Zug ausgeführt") {
                guard var move = pendingMove else { return }
                // Nichts nachzufüllen, wenn der Beutel leer ist und keine
                // Karte genommen wurde — dann geht der Zug direkt ins
                // Protokoll.
                if bagEmpty && move.cardTaken == nil {
                    events.append(.harmonyTurn(move))
                } else {
                    move.refill = []
                    harmonyReport = move
                }
            }
            .buttonStyle(.borderedProminent)
            // Solange nichts dasteht, gibt es nichts auszuführen. Ein Knopf,
            // der nichts tut, sieht am Tisch aus wie ein Fehler.
            .disabled(pendingMove == nil)
            .accessibilityIdentifier("harmony-done")
        }
        .padding(.horizontal).padding(.top, 10).padding(.bottom, 8)
        .background(.bar)
    }

    private func fieldInWords(_ move: HarmonyMove) -> String {
        move.placements.map(\.stone.name).joined(separator: ", ")
    }

    private func cellInWords(_ cell: Int) -> String { cellName(cell) }

    private func landscapeInWords(_ cell: Int, _ move: HarmonyMove) -> String {
        let stack = move.applied(to: state.harmonyBoard)[cell] ?? []
        switch stack.landscape {
        case .tree:     return "Baum der Höhe \(stack.count)"
        case .mountain: return "Berg der Höhe \(stack.count)"
        case .water:    return "Wasser"
        case .field:    return "Feld"
        case .building: return "Gebäude"
        case .none:     return "noch keine Landschaft"
        }
    }

    /// The end is announced, not imposed: the round is played out so
    /// everyone has had the same number of turns.
    private func lastRoundBanner(_ reason: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "flag.checkered")
            VStack(alignment: .leading, spacing: 2) {
                Text("Letzte Runde").font(.callout.weight(.semibold))
                Text("\(reason) Noch \(end.turnsLeft) "
                     + (end.turnsLeft == 1 ? "Zug." : "Züge."))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.16)))
        .accessibilityIdentifier("last-round")
    }

    /// The only thing about a foreign board Harmony is told, and only when
    /// it matters. Costs a tap in the one turn it is needed and nothing in
    /// every other.
    private var fullBoardToggle: some View {
        Button {
            taps += 1
            boardNearlyFull.toggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: boardNearlyFull ? "checkmark.square.fill" : "square")
                    .foregroundStyle(boardNearlyFull ? Color.accentColor : .secondary)
                Text("\(currentPlayer) hat jetzt zwei oder weniger freie Felder")
                    .font(.callout)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12)
                .fill(boardNearlyFull ? Color.accentColor.opacity(0.14)
                                      : Color(.secondarySystemBackground)))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("board-full")
    }

    /// Szenario 4: Harmony's own result, broken down far enough to be
    /// **recalculated** at the table. Not a verdict — the humans add up
    /// theirs the way they always have, and the app does not offer to.
    private var gameOver: some View {
        let score = state.finalScore
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                totalBlock(score)

                ForEach(score.landscapes) { group in
                    scoreBlock(group)
                }

                scoreBlock(score.cards)

                Text("\(score.cubesPlaced) Tierwürfel liegen. Bei Gleichstand "
                     + "entscheidet ihre Zahl, danach ist der Sieg geteilt.")
                    .font(.footnote).foregroundStyle(.secondary)

                Text("Die Ergebnisse der Menschen werden wie immer von Hand "
                     + "gezählt.")
                    .font(.footnote).foregroundStyle(.tertiary)
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            Button("Verlauf ansehen") { historyOpen = true }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.bar)
                .accessibilityIdentifier("show-history")
        }
    }

    private func totalBlock(_ score: FinalScore) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Harmony").font(.callout).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(score.total)")
                    .font(.system(size: 52, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("Punkte").font(.title3).foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("total")

            Text("\(score.landscapeTotal) aus Landschaften, "
                 + "\(score.cards.points) aus Tierkarten.")
                .font(.callout).foregroundStyle(.secondary)

            if let reason = endReason {
                Text(reason + " Alle hatten gleich viele Züge.")
                    .font(.footnote).foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One group with its lines and its subtotal. Lines worth nothing stay
    /// in and are set back — they are what someone checks first when a
    /// number looks wrong.
    private func scoreBlock(_ group: ScoreGroup) -> some View {
        TitledBlock(group.title) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(group.lines) { line in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(line.label)
                            .font(.callout)
                            .foregroundStyle(line.points == 0 ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(line.points)")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(line.points == 0 ? .tertiary : .primary)
                    }
                    .padding(.vertical, 5)
                }

                Divider().padding(.vertical, 4)

                HStack {
                    Text(group.title).font(.callout.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(group.points)")
                        .font(.callout.monospacedDigit().weight(.semibold))
                }

                if let note = group.note {
                    Text(note)
                        .font(.footnote).foregroundStyle(.tertiary)
                        .padding(.top, 8)
                }
            }
        }
    }

    // MARK: - Pickers

    /// The same picker the setup uses, limited to the one card that came
    /// up. It closes by itself once chosen.
    private var cardPicker: some View {
        NamePickerView(
            title: "Nachgerückt",
            options: Sample.allCards,
            unavailable: state.seenCards,
            limit: 1,
            chosen: Binding(get: { cardDrawn.map { [$0] } ?? [] },
                            set: { cardDrawn = $0.first }),
            onTap: { taps += 1 },
            onComplete: { cardPickerOpen = false })
    }

    private var historyList: some View {
        NavigationStack {
            Group {
                if history.isEmpty {
                    ContentUnavailableView("Noch kein Zug erfasst", systemImage: "list.bullet")
                } else {
                    List(history) { entry in
                        HStack {
                            Text(entry.line).font(.system(.footnote, design: .monospaced))
                            Spacer()
                            if let rationale = entry.rationale {
                                Button {
                                    historyOpen = false
                                    shownRationale = rationale
                                } label: {
                                    Label("Warum", systemImage: "questionmark.circle")
                                        .labelStyle(.iconOnly)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.tint)
                            } else if let taps = entry.taps {
                                Text("\(taps) ×")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            } else {
                                // A correction stays visible as one. That is
                                // not decoration: it is the deterrent that
                                // keeps the way from being used to improve
                                // Harmony's move.
                                Image(systemName: "wrench.adjustable")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Verlauf")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zurücknehmen", systemImage: "arrow.uturn.backward") {
                        undoLast()
                        historyOpen = false
                    }
                    .disabled(events.isEmpty)
                    .accessibilityIdentifier("undo")
                }
            }
            // Störfall B lives next to Störfall A, because both repair the
            // same thing from different sides: undo takes back what was
            // entered wrongly, the correction takes in what was played
            // wrongly. Neither belongs on the screen of the running turn.
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 6) {
                    Button {
                        historyOpen = false
                        correctionOpen = true
                    } label: {
                        Label("Tableau berichtigen", systemImage: "wrench.adjustable")
                            .font(.callout)
                    }
                    .accessibilityIdentifier("correct-board")

                    Text("Nur wenn auf dem Tisch etwas anderes liegt als hier.")
                        .font(.caption).foregroundStyle(.secondary)

                    Divider().padding(.vertical, 4)

                    // Eine Partie überdauert das Weglegen des Geräts; ohne
                    // diesen Weg käme man aus der letzten nie wieder heraus.
                    Button(role: .destructive) {
                        historyOpen = false
                        onNewGame()
                    } label: {
                        Label("Neue Partie", systemImage: "trash").font(.callout)
                    }
                    .accessibilityIdentifier("new-game")

                    Text("Verwirft den gespeicherten Stand und fragt den Aufbau neu ab.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 10).padding(.bottom, 8)
                .background(.bar)
            }
        }
    }

    /// Störfall C: what does this move bring, and what would the
    /// alternative have been. A number without a comparison answers
    /// neither — "this move brings 14" means nothing until the next best
    /// one is known.
    private func rationaleSheet(_ rationale: MoveRationale) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    TitledBlock("Was der Zug bringt") {
                        VStack(spacing: 10) {
                            ForEach(Array(rationale.terms.enumerated()), id: \.offset) { _, term in
                                HStack(alignment: .firstTextBaseline) {
                                    if term.prospect {
                                        Image(systemName: "arrow.turn.right.up")
                                            .font(.caption2)
                                            .foregroundStyle(.tint)
                                    }
                                    Text(term.name)
                                        .font(.callout)
                                        .foregroundStyle(term.prospect ? .secondary : .primary)
                                    Spacer(minLength: 12)
                                    if term.points > 0 {
                                        Text(term.prospect
                                             ? (term.probability.map {
                                                   "\(term.points) × \(Int($0 * 100)) % = \(term.expected)"
                                               } ?? "(\(term.points))")
                                             : "+\(term.points)")
                                            .font(.callout.monospacedDigit()
                                                .weight(term.prospect ? .regular : .semibold))
                                            .foregroundStyle(term.prospect ? .secondary : .primary)
                                    }
                                }
                            }
                            Divider()
                            HStack {
                                Text("Punkte jetzt").font(.callout.weight(.semibold))
                                Spacer()
                                Text("\(rationale.immediate)")
                                    .font(.callout.monospacedDigit().weight(.bold))
                            }
                            if rationale.isProspective {
                                HStack {
                                    Text("Bewertung der Stellung").font(.callout.weight(.semibold))
                                    Spacer()
                                    Text("\(rationale.value)")
                                        .font(.callout.monospacedDigit().weight(.bold))
                                }
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Aussichten sind Erwartungswerte, keine Punkte: "
                                         + "der Gewinn mal der Wahrscheinlichkeit, ihn zu "
                                         + "erreichen. Verglichen wird auf der Bewertung — "
                                         + "sonst könnte ein Zug ohne sofortige Punkte nie "
                                         + "der beste sein.")
                                    if let note = rationale.probabilityNote {
                                        Text(note)
                                    }
                                }
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    TitledBlock("Die Alternative") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(rationale.runnerUp).font(.callout)
                            HStack {
                                Text(rationale.isProspective
                                     ? "\(rationale.runnerUpImmediate) Punkte jetzt, "
                                       + "Bewertung \(rationale.runnerUpValue)"
                                     : "\(rationale.runnerUpValue) Punkte")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            Text("Abstand: \(rationale.gap)")
                                .font(.callout.weight(.semibold))
                            Text(rationale.gapExplanation)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Begründung")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Footer and turn change

    /// The transcript line sits with the button, not in the content: it
    /// shows what is about to be recorded and so cannot be pushed off the
    /// screen.
    private var footer: some View {
        VStack(spacing: 8) {
            Text(line)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("notation")

            Button { record() } label: {
                Text("Zug eintragen").frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isComplete)
            .accessibilityIdentifier("record")
        }
        .padding(.horizontal).padding(.top, 10).padding(.bottom, 8)
        .background(.bar)
    }

    private var line: String {
        var parts = [currentPlayer]
        if let index = takenIndex { parts.append("-\(state.display[index].notation)") }
        if let card = cardTaken { parts.append("+\(card)") }
        if refill.count == 3 { parts.append(">" + refill.map(\.rawValue).joined()) }
        if let drawn = cardDrawn { parts.append(">\(drawn)") }
        return parts.joined(separator: "  ")
    }

    private func record() {
        guard let index = takenIndex else { return }
        events.append(.opponentTurn(OpponentTurn(
            taken: index, refill: refill,
            cardTaken: cardTaken, cardDrawn: cardDrawn,
            taps: taps + 1, boardNearlyFull: boardNearlyFull)))
        clearInput()
    }

    /// Störfall A: dropping the last event and replaying. Everything the
    /// event touched comes back by itself — the display, the open cards,
    /// Harmony's board and whose turn it is.
    private func undoLast() {
        guard !events.isEmpty else { return }
        events.removeLast()
        clearInput()
    }

    private func clearInput() {
        takenIndex = nil
        refill = []
        cardTaken = nil
        cardDrawn = nil
        boardNearlyFull = false
        taps = 0
    }
}

// MARK: - Building blocks

struct StoneDot: View {
    let stone: Stone?
    var size: CGFloat = 34

    var body: some View {
        Group {
            if let stone {
                Circle().fill(stone.color)
                    .overlay(Circle().strokeBorder(.primary.opacity(0.2), lineWidth: 1))
            } else {
                Circle().strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: size, height: size)
    }
}

struct TitledBlock<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            content
        }
    }
}

/// A wrapping row — the card names differ in length.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    OpponentTurnView(startState: .initial())
}
