import SwiftUI

/// Phase 5 click-through prototype: recording other players' turns, one
/// after another. No engine and no rule checking — what is measured is the
/// input path itself, in taps, as `pruefverfahren.md` foresees for storey
/// three. User-facing text is German, everything else English.
struct OpponentTurnView: View {
    /// The game is the sequence of events; the position is replayed from
    /// it. Phase 4 chose this so that undo, surviving the background and
    /// producing a test case are one mechanism rather than three.
    @State private var events: [GameEvent] = []

    /// Launch argument for tests and for looking at a single screen, the
    /// hook `pruefverfahren.md` foresees for storey three.
    private let startState = GameState.initial(
        seat: ProcessInfo.processInfo.arguments.contains("-harmonyTurn")
              ? Sample.turnOrder.count - 1 : 0)

    // Input of the turn in progress
    @State private var takenIndex: Int?
    @State private var refill: [Stone] = []
    @State private var cardTaken: String?
    @State private var cardDrawn: String?
    @State private var taps = 0
    @State private var cardPickerOpen = false
    @State private var historyOpen = false
    @State private var showSideB = false
    @State private var showSetupExample = false
    /// The reason currently on screen. Offered, not forced: the move stands
    /// on its own and the why is one tap away.
    @State private var shownRationale: MoveRationale?

    private var state: GameState { events.state(from: startState) }
    private var history: [LogEntry] { events.entries(from: startState) }

    private var currentPlayer: String { state.currentPlayer }
    private var isHarmony: Bool { state.isHarmonysTurn }

    /// Harmony has a move to show whenever it is her turn. Undoing her turn
    /// brings it back, which is the replay doing its work.
    private var pendingMove: HarmonyMove? {
        isHarmony ? (showSetupExample ? Sample.harmonyMoveSetup : Sample.harmonyMove) : nil
    }

    private var isComplete: Bool {
        takenIndex != nil && refill.count == 3
            && (cardTaken == nil || cardDrawn != nil)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isHarmony { harmonyTurn } else { entry }
            }
            .navigationTitle(isHarmony ? "Harmony ist am Zug" : "\(currentPlayer) ist am Zug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { historyOpen = true } label: {
                        Text(isHarmony ? "\(history.count) Züge" : "\(taps) ×")
                            .font(.footnote.monospacedDigit().weight(.semibold))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Capsule().fill(.quaternary))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("taps")
                }
            }
            .sheet(isPresented: $cardPickerOpen) { cardPicker }
            .sheet(isPresented: $historyOpen) { historyList }
            .sheet(item: $shownRationale) { rationaleSheet($0) }
        }
    }

    // MARK: - Recording another player's turn

    private var entry: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                displaySection
                if takenIndex != nil { refillSection }
                cardSection
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
                            ForEach(Array(field.stones.enumerated()), id: \.offset) { _, stone in
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
                    ForEach(state.openCards, id: \.self) { name in
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

                BoardView(side: .a, columns: BoardView.sideA, cells: harmonyCells)
                    .padding(.horizontal, 4)

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
                    Text("Zug eingetragen. Das Brett zeigt jetzt den Stand, "
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
                if let move = pendingMove { events.append(.harmonyTurn(move)) }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("harmony-done")
        }
        .padding(.horizontal).padding(.top, 10).padding(.bottom, 8)
        .background(.bar)
    }

    private func fieldInWords(_ move: HarmonyMove) -> String {
        move.placements.map(\.stone.name).joined(separator: ", ")
    }

    private func cellInWords(_ cell: Int) -> String {
        "\(cell / 10).\(cell % 10)"
    }

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

    // MARK: - Pickers

    /// Two columns, alphabetical and filled **column by column** like a
    /// printed list: A to the middle on the left, the rest on the right.
    /// Looking a name up then means scanning one column instead of checking
    /// both halves of every row.
    private var cardPicker: some View {
        let remaining = Sample.allCards
            .filter { !state.seenCards.contains($0) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        let split = (remaining.count + 1) / 2
        let left = Array(remaining.prefix(split))
        let right = Array(remaining.dropFirst(split))

        return NavigationStack {
            VStack(spacing: 8) {
                ForEach(left.indices, id: \.self) { i in
                    HStack(spacing: 8) {
                        cardCell(left[i])
                        if i < right.count {
                            cardCell(right[i])
                        } else {
                            Color.clear.frame(height: 42).frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .frame(maxHeight: .infinity, alignment: .top)
            .navigationTitle("Nachgerückt · \(remaining.count) im Stapel")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func cardCell(_ name: String) -> some View {
        Button {
            taps += 1
            cardDrawn = name
            cardPickerOpen = false
        } label: {
            Text(name)
                .font(.callout)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("draw-\(name)")
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
                            } else {
                                Text("\(entry.taps) ×")
                                    .font(.caption.monospacedDigit())
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
        events.append(.opponentTurn(taken: index, refill: refill,
                                    cardTaken: cardTaken, cardDrawn: cardDrawn,
                                    taps: taps + 1))
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
private struct FlowLayout: Layout {
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
    OpponentTurnView()
}
