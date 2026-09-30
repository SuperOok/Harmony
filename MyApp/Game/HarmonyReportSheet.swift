import SwiftUI
import HarmonyRules

/// What the table tells Harmony after her turn.
///
/// She took three stones out of a space and, if the move said so, a card.
/// What came back out of the bag and which card moved up she cannot know —
/// and guessing it would be exactly the invented data this app exists to
/// avoid. So the same palette as for anyone else's turn, and the same card
/// picker.
struct HarmonyReportSheet: View {
    @State private var move: HarmonyMove
    let bagEmpty: Bool
    /// Cards that have been seen and so cannot be the one that moved up.
    let seenCards: Set<String>
    let onRecord: (HarmonyMove) -> Void

    @State private var cardPickerOpen = false

    init(move: HarmonyMove, bagEmpty: Bool, seenCards: Set<String>,
         onRecord: @escaping (HarmonyMove) -> Void) {
        _move = State(initialValue: move)
        self.bagEmpty = bagEmpty
        self.seenCards = seenCards
        self.onRecord = onRecord
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    RefillBlock(stones: $move.refill, bagEmpty: bagEmpty,
                                identifierPrefix: "harmony-")

                    if let taken = move.cardTaken {
                        TitledBlock("Welche Karte rückte nach?") {
                            Button {
                                cardPickerOpen = true
                            } label: {
                                HStack {
                                    Text(move.cardDrawn ?? "Für \(taken) nachgerückt")
                                        .foregroundStyle(move.cardDrawn == nil
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
                    onRecord(move)
                } label: {
                    Text("Eintragen").frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!move.isComplete(bagEmpty: bagEmpty))
                .padding(.horizontal).padding(.vertical, 8)
                .background(.bar)
                .accessibilityIdentifier("harmony-record")
            }
            .sheet(isPresented: $cardPickerOpen) {
                NamePickerView(
                    title: "Nachgerückt",
                    options: Sample.allCards,
                    unavailable: seenCards,
                    limit: 1,
                    chosen: Binding(get: { move.cardDrawn.map { [$0] } ?? [] },
                                    set: { move.cardDrawn = $0.first }),
                    onComplete: { cardPickerOpen = false })
            }
        }
    }
}
