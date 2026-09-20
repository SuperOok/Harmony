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
    /// Removing a name for good. Offered for players, not for cards — the
    /// thirty-two animals are given, the people are not.
    ///
    /// Held down rather than tapped, so it cannot happen by accident, and
    /// **without a confirmation**: a name may be removed for reasons that
    /// make seeing it again the thing to avoid. It can be entered anew if
    /// that was a mistake.
    var onDelete: ((String) -> Void)? = nil
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

                    if onDelete != nil {
                        Text("Zum Entfernen einen Namen gedrückt halten.")
                            .font(.footnote).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
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
        .contextMenu {
            if let onDelete {
                Button("Entfernen", systemImage: "trash", role: .destructive) {
                    onDelete(name)
                }
            }
        }
    }
}

/// Players Harmony has seen before, kept on the device across launches.
///
/// Stored in the user defaults: it is a handful of names, and anything
/// heavier would be machinery without a purpose. **Local only**, as Phase 1
/// requires — nothing leaves the device, and the public repository never
/// sees a real name, which is why recorded transcripts use neutral ones
/// (`pruefverfahren.md`).
///
/// Version two is to add up everyone's score so the pad from the box is no
/// longer needed, and to keep past games; those results attach to the names
/// kept here. Removing a name is therefore a real deletion, not a filter —
/// see `onDelete` above for why it asks nothing back.
enum KnownPlayers {
    private static let key = "knownPlayers"
    private static let seed = ["Anke", "Bernd", "Clara", "Dieter", "Eva"]

    static var all: [String] {
        get {
            if let stored = UserDefaults.standard.stringArray(forKey: key) { return stored }
            // Seeded once, so emptying the list does not bring them back.
            UserDefaults.standard.set(seed, forKey: key)
            return seed
        }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    static func add(_ name: String) {
        guard !all.contains(name) else { return }
        all.append(name)
    }

    static func remove(_ name: String) {
        all.removeAll { $0 == name }
    }
}
