import SwiftUI

/// Choosing cards, used both when recording an opponent's turn and when
/// setting the game up. One view rather than two: the task is the same, and
/// the operator should not have to learn it twice.
///
/// Two columns, alphabetical, filled **column by column** like a printed
/// list. Looking a name up then means scanning one column instead of
/// checking both halves of every row.
///
/// Chosen cards stay visible and highlighted. Once `limit` of them are
/// picked the view closes by itself — a confirmation after the last tap
/// would only cost a tap and tell nobody anything.
struct CardPickerView: View {
    let title: String
    /// Cards that are gone and are not offered at all.
    let unavailable: Set<String>
    let limit: Int
    @Binding var chosen: [String]
    /// Counts a tap, so the input path stays measurable.
    var onTap: () -> Void = {}
    var onComplete: () -> Void

    private var offered: [String] {
        Sample.allCards
            .filter { !unavailable.contains($0) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                let split = (offered.count + 1) / 2
                VStack(spacing: 8) {
                    ForEach(0..<split, id: \.self) { row in
                        HStack(spacing: 8) {
                            cell(offered[row])
                            if split + row < offered.count {
                                cell(offered[split + row])
                            } else {
                                Color.clear.frame(height: 42).frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func cell(_ name: String) -> some View {
        let isChosen = chosen.contains(name)
        return Button {
            onTap()
            if let index = chosen.firstIndex(of: name) {
                chosen.remove(at: index)
            } else if chosen.count < limit {
                chosen.append(name)
                if chosen.count == limit { onComplete() }
            }
        } label: {
            HStack(spacing: 6) {
                if isChosen {
                    Image(systemName: "checkmark").font(.caption.weight(.bold))
                }
                Text(name)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(.callout)
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(RoundedRectangle(cornerRadius: 10)
                .fill(isChosen ? Color.accentColor.opacity(0.25)
                               : Color(.secondarySystemBackground)))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("pick-\(name)")
    }
}
