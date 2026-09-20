import SwiftUI

/// Choosing names from a list — animal cards when a turn is recorded or a
/// game set up, players when the seating is entered. One view rather than
/// three: the task is the same, and it should not have to be learned again
/// for each kind of name.
///
/// Two columns, alphabetical, filled **column by column** like a printed
/// list. Looking a name up then means scanning one column instead of
/// checking both halves of every row.
///
/// Chosen names stay visible and highlighted, in the order they were
/// picked. Once `limit` of them are chosen the view closes by itself — a
/// confirmation after the last tap would cost a tap and tell nobody
/// anything.
struct NamePickerView: View {
    let title: String
    let options: [String]
    /// Names that are gone and are not offered at all.
    var unavailable: Set<String> = []
    let limit: Int
    @Binding var chosen: [String]
    /// Shown above the list when new names may be added, as for players.
    var addPrompt: String? = nil
    var onAdd: ((String) -> Void)? = nil
    /// Counts a tap, so the input path stays measurable.
    var onTap: () -> Void = {}
    var onComplete: () -> Void

    @State private var newName = ""

    private var offered: [String] {
        options
            .filter { !unavailable.contains($0) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if let addPrompt, let onAdd {
                        HStack {
                            TextField(addPrompt, text: $newName)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityIdentifier("new-name")
                            Button("Hinzufügen") {
                                let name = newName.trimmingCharacters(in: .whitespaces)
                                guard !name.isEmpty, !options.contains(name) else { return }
                                onAdd(name)
                                newName = ""
                                if chosen.count < limit {
                                    chosen.append(name)
                                    if chosen.count == limit { onComplete() }
                                }
                            }
                            .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                            .accessibilityIdentifier("add-name")
                        }
                    }

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

/// Players Harmony has seen before.
///
/// **Not persisted yet.** Version two is to add up everyone's score so the
/// pad from the box is no longer needed, and to keep past games; then this
/// list has to survive the app and carry results. Recognising a player
/// again is what makes an old game attachable to them.
enum KnownPlayers {
    static var all: [String] = ["Anke", "Bernd", "Clara", "Dieter", "Eva"]

    static func add(_ name: String) {
        guard !all.contains(name) else { return }
        all.append(name)
    }
}
