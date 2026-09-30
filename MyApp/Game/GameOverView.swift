import SwiftUI
import HarmonyRules

/// Szenario 4: Harmony's own result, broken down far enough to be
/// **recalculated** at the table. Not a verdict — the humans add up theirs
/// the way they always have, and the app does not offer to.
struct GameOverView: View {
    let score: FinalScore
    /// Why the game is over, if it can be told.
    let endReason: String?
    let onShowHistory: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                totalBlock

                ForEach(Array(score.landscapes.enumerated()), id: \.offset) { _, group in
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
            Button("Verlauf ansehen", action: onShowHistory)
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.bar)
                .accessibilityIdentifier("show-history")
        }
    }

    private var totalBlock: some View {
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

            if let endReason {
                Text(endReason + " Alle hatten gleich viele Züge.")
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
                ForEach(Array(group.lines.enumerated()), id: \.offset) { _, line in
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
}
