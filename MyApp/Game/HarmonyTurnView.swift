import SwiftUI
import HarmonyRules
import HarmonyEngine

/// Szenario 3: the move as an instruction. Shown is the **target state** —
/// the starting state lies on the table next to the device — with a ring
/// around every space that changes and a number for each stone in the order
/// it is placed.
struct HarmonyTurnView: View {
    let state: GameState
    /// The turn to play. `nil` while the engine thinks: nothing stands there
    /// then, because a made-up turn in its place would be played at the
    /// table.
    let move: HarmonyMove?
    let search: HarmonySearch
    let onShowRationale: (MoveRationale) -> Void
    /// "Zug ausgeführt": the turn has been played on the table.
    let onDone: (HarmonyMove) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Above the board, not below it: the board is taller than
                // the screen, and nobody at the table sees what stands
                // under it.
                engineStatus
                if let estimate = search.endEstimate { endLine(estimate) }

                BoardView(side: state.sideB ? .b : .a,
                          columns: state.sideB ? BoardView.sideB : BoardView.sideA,
                          cells: cells)
                    .padding(.horizontal, 4)

                if move == nil && search.since != nil {
                    Text("Der Vorschlag erscheint, sobald die Rechnung steht. "
                         + "Bis dahin steht hier nichts — ein ausgedachter Zug "
                         + "an dieser Stelle würde am Tisch gespielt.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                if let move {
                    instructions(move)
                    whyButton(move)
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
        .safeAreaInset(edge: .bottom) { footer }
    }

    // MARK: - What is to be done

    private func instructions(_ move: HarmonyMove) -> some View {
        TitledBlock("Was zu tun ist") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Nimm das Feld mit \(fieldInWords(move)).")
                    .font(.callout.weight(.semibold))
                ForEach(Array(move.placements.enumerated()), id: \.offset) { index, p in
                    Text("\(index + 1)  \(p.stone.name) auf \(cellName(p.cell)) — "
                         + landscapeInWords(p.cell, move))
                        .font(.callout)
                }
                ForEach(Array(move.cubes.enumerated()), id: \.offset) { _, c in
                    Text("Würfel von **\(c.card)** auf \(cellName(c.cell))")
                        .font(.callout)
                }
                if let card = move.cardTaken {
                    Text("Nimm die Karte **\(card)**.")
                        .font(.callout)
                }
            }
        }
    }

    private func whyButton(_ move: HarmonyMove) -> some View {
        Button {
            onShowRationale(move.rationale)
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
    }

    /// Target state while a move is pending, plain state afterwards.
    private var cells: [Int: BoardView.Cell] {
        guard let move else {
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

    private func fieldInWords(_ move: HarmonyMove) -> String {
        move.placements.map(\.stone.name).joined(separator: ", ")
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

    // MARK: - What the engine is doing

    /// What the engine is doing, and what it cost. On the table this line
    /// is the whole experiment: a suggestion nobody waits for is no
    /// suggestion.
    @ViewBuilder private var engineStatus: some View {
        if let since = search.since {
            TimelineView(.periodic(from: since, by: 0.5)) { context in
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Harmony rechnet — "
                         + String(format: "%.0f s", context.date.timeIntervalSince(since)))
                        .font(.footnote.monospacedDigit())
                    Spacer()
                    Button("Ansehen") { search.isShown = true }
                        .font(.footnote)
                        .accessibilityIdentifier("show-thinking")
                    Button("Das genügt") { search.stop() }
                        .font(.footnote)
                        // Only once a turn has been found. Stopping before
                        // would mean no suggestion and no way to one, since
                        // it is worked out only when the position changes.
                        .disabled(search.monitor.current?.best == nil)
                        .accessibilityIdentifier("stop-thinking")
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accentColor.opacity(0.14)))
                .accessibilityIdentifier("thinking")
            }
        } else if let took = search.took {
            Label(String(format: "%@ in %.1f Sekunden, %d Züge geprüft",
                         search.complete ? "Gerechnet" : "Abgebrochen",
                         took, search.weighed),
                  systemImage: search.complete ? "stopwatch" : "hand.raised")
                .font(.footnote).foregroundStyle(.secondary)
                .accessibilityIdentifier("thinking-took")
        }
    }

    /// When the game ends, as precisely as can be said. Estimated it is a
    /// range and the likeliest trigger; reported it is one number.
    private func endLine(_ estimate: EndEstimate) -> some View {
        Label(endInWords(estimate), systemImage: estimate.cause == .announced
                  ? "flag.checkered" : "hourglass")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("end-estimate")
    }

    private func endInWords(_ estimate: EndEstimate) -> String {
        let turns = estimate.fewest == estimate.most
            ? "\(estimate.most) \(estimate.most == 1 ? "Zug" : "Züge")"
            : "\(estimate.fewest)–\(estimate.most) Züge"
        if estimate.cause == .announced {
            return estimate.most <= 1
                ? "Spielende gemeldet: Dies ist Harmonys letzter Zug."
                : "Spielende gemeldet: noch \(turns) für Harmony, dieser mitgezählt."
        }
        let cause: String
        switch estimate.cause {
        case let .opponent(seat):
            cause = "am ehesten durch den Spielplan von \(state.seating[seat])"
        case .ownBoard:
            cause = "am ehesten durch Harmonys eigenen Spielplan"
        default:
            cause = "am ehesten, weil der Beutel leer ist"
        }
        let chance = estimate.causeChance < 0.995
            ? String(format: " (%.0f %%)", estimate.causeChance * 100)
            : ""
        return "Spielende geschätzt: noch \(turns) für Harmony, dieser mitgezählt — "
            + cause + chance + "."
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 8) {
            Text(move.map { "Harmony  \($0.notation)" } ?? "Harmony  —")
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("notation")

            Button("Zug ausgeführt") {
                if let move { onDone(move) }
            }
            .buttonStyle(.borderedProminent)
            // While nothing stands there is nothing to carry out. A button
            // that does nothing looks like a fault at the table.
            .disabled(move == nil)
            .accessibilityIdentifier("harmony-done")
        }
        .padding(.horizontal).padding(.top, 10).padding(.bottom, 8)
        .background(.bar)
    }
}
