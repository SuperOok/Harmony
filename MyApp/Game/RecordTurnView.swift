import SwiftUI
import HarmonyRules
import HarmonyEngine

/// The input of another player's turn while it is being entered.
struct TurnInput {
    var takenIndex: Int?
    var refill: [Stone] = []
    var cardTaken: String?
    var cardDrawn: String?
    var taps = 0
    /// Reported with the turn being recorded: this player's board is full.
    /// Harmony cannot see a foreign board — this is the one thing she has
    /// to be told, at most once per game.
    var boardNearlyFull = false

    mutating func clear() { self = TurnInput() }

    /// Whether the turn can be recorded: a space, the refill — unless the
    /// bag is dry — and, for a card taken, the one that moved up.
    func isComplete(bagEmpty: Bool) -> Bool {
        takenIndex != nil && (refill.count == EngineState.stonesPerSpace || bagEmpty)
            && (cardTaken == nil || cardDrawn != nil)
    }

    /// The turn as the log holds it. The tap that records it is counted in.
    var turn: OpponentTurn? {
        guard let takenIndex else { return nil }
        return OpponentTurn(taken: takenIndex, refill: refill,
                            cardTaken: cardTaken, cardDrawn: cardDrawn,
                            taps: taps + 1, boardNearlyFull: boardNearlyFull)
    }
}

/// Recording another player's turn: which space was taken, what was drawn
/// for it, which card was taken and which moved up.
///
/// Phase 5 click-through prototype in its origin: what is measured is the
/// input path itself, in taps, as `pruefverfahren.md` foresees for storey
/// three.
struct RecordTurnView: View {
    let state: GameState
    let end: EndStatus
    let bagEmpty: Bool
    @Binding var input: TurnInput
    @Binding var cardPickerOpen: Bool
    let onRecord: (OpponentTurn) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let reason = end.reason, !end.isOver { lastRoundBanner(reason) }
                displaySection
                if input.takenIndex != nil {
                    RefillBlock(stones: $input.refill, bagEmpty: bagEmpty,
                                onTap: { input.taps += 1 })
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
                ForEach(Array(state.display.enumerated()), id: \.offset) { index, field in
                    Button {
                        input.taps += 1
                        input.takenIndex = index
                        input.refill = []
                    } label: {
                        HStack(spacing: 10) {
                            ForEach(Array(field.ordered.enumerated()), id: \.offset) { _, stone in
                                StoneDot(stone: stone, size: 30)
                            }
                            Spacer()
                            if input.takenIndex == index {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(input.takenIndex == index ? Color.accentColor.opacity(0.14)
                                                                : Color(.secondarySystemBackground))
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("field-\(index)")
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
                            input.taps += 1
                            if input.cardTaken == name {
                                input.cardTaken = nil; input.cardDrawn = nil
                            } else {
                                input.cardTaken = name; input.cardDrawn = nil
                            }
                        } label: {
                            Text(name)
                                .font(.callout)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(
                                    Capsule().fill(input.cardTaken == name
                                        ? Color.accentColor.opacity(0.18)
                                        : Color(.secondarySystemBackground))
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("card-\(name)")
                    }
                }
                if input.cardTaken != nil {
                    Button {
                        input.taps += 1
                        cardPickerOpen = true
                    } label: {
                        HStack {
                            Text(input.cardDrawn ?? "Welche Karte rückte nach?")
                                .foregroundStyle(input.cardDrawn == nil ? .secondary : .primary)
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
            input.taps += 1
            input.boardNearlyFull.toggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: input.boardNearlyFull ? "checkmark.square.fill" : "square")
                    .foregroundStyle(input.boardNearlyFull ? Color.accentColor : .secondary)
                Text("\(state.currentPlayer) hat jetzt zwei oder weniger freie Felder")
                    .font(.callout)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12)
                .fill(input.boardNearlyFull ? Color.accentColor.opacity(0.14)
                                            : Color(.secondarySystemBackground)))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("board-full")
    }

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

            Button {
                if let turn = input.turn { onRecord(turn) }
            } label: {
                Text("Zug eintragen").frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!input.isComplete(bagEmpty: bagEmpty))
            .accessibilityIdentifier("record")
        }
        .padding(.horizontal).padding(.top, 10).padding(.bottom, 8)
        .background(.bar)
    }

    private var line: String {
        var parts = [state.currentPlayer]
        if let index = input.takenIndex { parts.append("-\(state.display[index].notation)") }
        if let card = input.cardTaken { parts.append("+\(card)") }
        if input.refill.count == EngineState.stonesPerSpace {
            parts.append(">" + input.refill.map(\.rawValue).joined())
        }
        if let drawn = input.cardDrawn { parts.append(">\(drawn)") }
        return parts.joined(separator: "  ")
    }
}
