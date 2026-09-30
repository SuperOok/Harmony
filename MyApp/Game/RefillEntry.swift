import SwiftUI
import HarmonyRules
import HarmonyEngine

/// What was drawn for an emptied display space: the three slots and the
/// palette of six colours to fill them from. The same input serves anyone's
/// turn and Harmony's own — one palette, learned once.
struct RefillEntry: View {
    @Binding var stones: [Stone]
    /// Put before the accessibility identifiers, so that the two places this
    /// appears can be told apart by the interface tests.
    var identifierPrefix = ""
    /// Counts a tap, so the input path stays measurable.
    var onTap: () -> Void = {}

    private var full: Bool { stones.count == EngineState.stonesPerSpace }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ForEach(0..<EngineState.stonesPerSpace, id: \.self) { i in
                    StoneDot(stone: i < stones.count ? stones[i] : nil)
                }
                Spacer()
                if !stones.isEmpty {
                    Button("Zurück") {
                        onTap()
                        stones.removeLast()
                    }
                    .font(.footnote)
                    .accessibilityIdentifier("\(identifierPrefix)refill-undo")
                }
            }
            HStack(spacing: 8) {
                ForEach(Stone.allCases) { stone in
                    Button {
                        onTap()
                        if !full { stones.append(stone) }
                    } label: {
                        StoneDot(stone: stone, size: 44)
                    }
                    .buttonStyle(.plain)
                    .disabled(full)
                    .opacity(full ? 0.35 : 1)
                    .accessibilityIdentifier("\(identifierPrefix)palette-\(stone.rawValue)")
                    .accessibilityLabel(stone.name)
                }
            }
        }
    }
}

/// The block that asks for the refill — or says there is none to enter,
/// because the bag has run dry.
struct RefillBlock: View {
    @Binding var stones: [Stone]
    let bagEmpty: Bool
    var identifierPrefix = ""
    var onTap: () -> Void = {}

    var body: some View {
        if bagEmpty {
            TitledBlock("Nachfüllen entfällt") {
                Text("Der Beutel ist leer; das Feld bleibt frei.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        } else {
            TitledBlock("Was wurde nachgefüllt?") {
                RefillEntry(stones: $stones, identifierPrefix: identifierPrefix, onTap: onTap)
            }
        }
    }
}
