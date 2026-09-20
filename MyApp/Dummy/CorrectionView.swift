import SwiftUI

/// Störfall B: the operator placed a stone other than the one announced and
/// noticed it later. App and table have drifted apart.
///
/// **The table always wins.** Rebuilding the real game would be
/// unreasonable towards the other players, so the app is corrected — the
/// spaces are set to what actually lies there, without that becoming a
/// regular move.
///
/// Two things hold it in check. The way is **deliberately inconvenient**,
/// as `02-szenarien.md` demands: two steps away from the main screen,
/// behind the transcript, and every correction stays visible there
/// afterwards. And the **stone count has to come out**: stones may be
/// rearranged, never conjured or lost, because Harmony reasons about what
/// is left in the bag.
struct CorrectionView: View {
    let state: GameState
    let onApply: (BoardCorrection) -> Void

    @Environment(\.dismiss) private var dismiss

    /// The board being worked on. A correction touches several spaces —
    /// a stone that leaves one has to arrive at another — so the edit runs
    /// on a copy and is recorded in one piece.
    @State private var board: [Int: [Stone]]
    @State private var cubes: [Int: String]
    /// Nothing is edited until a space has been picked. The board is the
    /// selector — naming a cell by its coordinates would be the counting
    /// at the table that `05-ui.md` rules out.
    @State private var selected: Int?

    init(state: GameState, onApply: @escaping (BoardCorrection) -> Void) {
        self.state = state
        self.onApply = onApply
        _board = State(initialValue: state.harmonyBoard)
        _cubes = State(initialValue: state.harmonyCubes)
    }

    /// The stack under the space being edited.
    private var stack: [Stone] { selected.flatMap { board[$0] } ?? [] }

    /// Every space that now differs from what the app held.
    private var changedCells: [Int] {
        let cells = Set(board.keys)
            .union(state.harmonyBoard.keys)
            .union(cubes.keys)
            .union(state.harmonyCubes.keys)
        return cells.filter {
            (board[$0] ?? []) != (state.harmonyBoard[$0] ?? [])
                || cubes[$0] != state.harmonyCubes[$0]
        }.sorted()
    }

    /// What the correction would do to the stone count, colour by colour.
    /// It has to be empty — see `stoneBalance`.
    private var balance: [Stone: Int] {
        stoneBalance(from: state.harmonyBoard, to: board)
    }

    private var illegalCells: [Int] {
        changedCells.filter { !(board[$0] ?? []).isLegal }
    }

    private var correction: BoardCorrection? {
        guard !changedCells.isEmpty, balance.isEmpty, illegalCells.isEmpty
        else { return nil }
        return BoardCorrection(changes: changedCells.map {
            BoardCorrection.Change(cell: $0, stack: board[$0] ?? [], cube: cubes[$0])
        })
    }

    private var cells: [Int: BoardView.Cell] {
        var cells = board.mapValues { BoardView.Cell(stack: $0) }
        for (cell, _) in cubes { cells[cell]?.cube = true }
        // A ring on everything already touched, so the second half of a
        // move is not forgotten halfway through.
        for cell in changedCells {
            cells[cell, default: BoardView.Cell()] = BoardView.Cell(
                stack: board[cell] ?? [],
                cube: cubes[cell] != nil,
                highlighted: true)
        }
        if let selected {
            cells[selected, default: BoardView.Cell()].highlighted = true
        }
        return cells
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    preamble

                    BoardView(side: state.sideB ? .b : .a,
                              columns: state.sideB ? BoardView.sideB : BoardView.sideA,
                              cells: cells,
                              onSelect: { selected = $0 })
                        .padding(.horizontal, 4)

                    if let selected {
                        editor(for: selected)
                    } else {
                        Text("Tippe das Feld an, auf dem etwas anderes liegt.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Tableau berichtigen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) { footer }
        }
    }

    private var preamble: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
            Text("Der Tisch gewinnt. Berichtigt wird die App, damit sie "
                 + "wieder zeigt, was liegt — nicht Harmonys Zug, damit er "
                 + "besser wird. Ein Stein kann dabei nur anderswo liegen, "
                 + "nicht verschwinden.")
                .font(.footnote)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color(.secondarySystemBackground)))
    }

    // MARK: - What lies on the space

    private func editor(for cell: Int) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            TitledBlock("Was liegt auf \(cellName(cell))?") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        if stack.isEmpty {
                            Text("leer").font(.callout).foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(stack.enumerated()), id: \.offset) { _, stone in
                                StoneDot(stone: stone, size: 30)
                            }
                        }
                        Spacer()
                        Text(was(cell)).font(.footnote).foregroundStyle(.secondary)
                    }

                    // Only what the game can produce. The correction takes
                    // in what was played differently — not what could never
                    // have been played at all.
                    Text(stack.isEmpty
                         ? "Von unten nach oben. Angeboten wird nur, was "
                           + "zusammen einen zulässigen Stapel ergibt."
                         : "Was darauf nicht liegen kann, ist ausgegraut.")
                        .font(.caption).foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        let placeable = stack.placeable
                        ForEach(Stone.allCases) { stone in
                            let allowed = placeable.contains(stone)
                            Button { add(stone, to: cell) } label: {
                                StoneDot(stone: stone, size: 34)
                            }
                            .buttonStyle(.plain)
                            .disabled(!allowed)
                            .opacity(allowed ? 1 : 0.25)
                            .accessibilityIdentifier("correct-\(stone.rawValue)")
                        }
                    }

                    HStack(spacing: 12) {
                        Button("Oberster herunter") { removeTop(from: cell) }
                            .disabled(stack.isEmpty)
                        Button("Feld leeren", role: .destructive) {
                            board[cell] = nil
                            cubes[cell] = nil
                        }
                        .disabled(stack.isEmpty && cubes[cell] == nil)
                    }
                    .font(.callout)
                    .buttonStyle(.bordered)

                    // Only reachable when the app already held an
                    // impossible stack — otherwise the palette cannot
                    // produce one. Without the line the button would just
                    // sit there dead.
                    if !stack.isLegal {
                        Text("So kann kein Stapel aussehen. Berichtigen "
                             + "lässt sich erst, was es im Spiel gibt.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
            }

            cubeSection(for: cell)
        }
    }

    /// The cube belongs to a card, and which one decides the points — the
    /// same gap the move notation had, see `pruefverfahren.md`.
    private func cubeSection(for cell: Int) -> some View {
        TitledBlock("Tierwürfel") {
            VStack(alignment: .leading, spacing: 10) {
                if stack.isEmpty {
                    Text("Ein Würfel liegt auf einem Stein. Erst muss einer da sein.")
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    ForEach(state.harmonyCards) { card in
                        Button {
                            cubes[cell] = cubes[cell] == card.name ? nil : card.name
                        } label: {
                            HStack {
                                Text(card.name).font(.callout)
                                Spacer()
                                if cubes[cell] == card.name {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.tint)
                                }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: 12)
                                .fill(cubes[cell] == card.name
                                      ? Color.accentColor.opacity(0.14)
                                      : Color(.secondarySystemBackground)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("cube-\(card.name)")
                    }
                    if cubes[cell] != nil {
                        Text("Nochmal antippen nimmt ihn wieder herunter.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func was(_ cell: Int) -> String {
        let before = state.harmonyBoard[cell] ?? []
        return "bisher " + (before.isEmpty ? "leer" : before.map(\.rawValue).joined())
    }

    // MARK: - Footer

    /// Says in one line why the button is grey, because the reason is
    /// never the space on screen but the one where the stone has to go.
    private var balanceLine: String? {
        guard !balance.isEmpty else { return nil }
        let parts = Stone.allCases.compactMap { stone -> String? in
            guard let difference = balance[stone] else { return nil }
            return "\(abs(difference))× \(stone.name) "
                + (difference > 0 ? "zu viel" : "fehlt")
        }
        return parts.joined(separator: " · ")
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let balanceLine {
                Label(balanceLine, systemImage: "scalemass")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("balance")
            }

            Text(correction?.notation ?? "!korr  —")
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("correction-notation")

            Button {
                if let correction {
                    onApply(correction)
                    dismiss()
                }
            } label: {
                Text("Berichtigen").frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(correction == nil)
            .accessibilityIdentifier("correct")
        }
        .padding(.horizontal).padding(.top, 10).padding(.bottom, 8)
        .background(.bar)
    }

    // MARK: - Input

    private func add(_ stone: Stone, to cell: Int) {
        guard stack.placeable.contains(stone) else { return }
        board[cell, default: []].append(stone)
    }

    private func removeTop(from cell: Int) {
        guard !stack.isEmpty else { return }
        board[cell]?.removeLast()
        if board[cell]?.isEmpty == true {
            board[cell] = nil
            // A cube rests on the topmost tile; without tiles it has no place.
            cubes[cell] = nil
        }
    }
}

#Preview {
    CorrectionView(state: .initial()) { _ in }
        .preferredColorScheme(.dark)
}
