import SwiftUI
import HarmonyRules

/// Szenario 1, in two steps so that neither has to be scrolled: first who
/// is playing, then what lies on the table.
///
/// The split is not only about height. Players outlive a single game —
/// version two is to add up everyone's score and keep past games, which
/// needs them recognised again — while the display is thrown away with the
/// game. Two screens keep the two apart.
///
/// **The whole setup is held here**, not in the two steps. Switching steps
/// replaces the view and takes its `@State` with it, so anything kept down
/// there is lost on the way back — and the way back is expressly open,
/// because the seating is often settled only once the display is on the
/// table.
struct SetupView: View {
    var onStart: (GameState) -> Void

    @State private var step = 1
    @State private var players: [String] = []
    /// The full turn order including Harmony. Kept apart from the choice of
    /// players: who plays and in which order are two questions, and the
    /// second is often settled only after the display is on the table —
    /// once it is clear who starts and who works the device.
    @State private var seating: [String] = ["Harmony"]
    @State private var taps = 0
    @State private var sideB = false
    /// Filled in reading order, so no space has to be picked first.
    @State private var stones: [Stone] = []
    @State private var cards: [String] = []

    var body: some View {
        if step == 1 {
            SetupPlayersView(players: $players,
                             seating: $seating,
                             taps: $taps,
                             onNext: { step = 2 })
        } else {
            SetupBoardView(seating: seating,
                           taps: $taps,
                           sideB: $sideB,
                           stones: $stones,
                           cards: $cards,
                           onBack: { step = 1 },
                           onStart: onStart)
        }
    }
}

/// Step one: who is playing, and in which order.
struct SetupPlayersView: View {
    @Binding var players: [String]
    @Binding var seating: [String]
    @Binding var taps: Int
    var onNext: () -> Void

    @State private var pickerOpen = false
    /// Held as view state, not read from the store on the fly: a change to
    /// a static store is invisible to SwiftUI, so the list would not
    /// refresh when a name is added or removed.
    @State private var knownPlayers = KnownPlayers.all

    /// Harmonies has four seats and Harmony occupies one of them.
    private let maxHumans = 3
    /// The seating list is as tall as its rows, so it has to know them
    /// exactly: a list inside a scroll view carries no height of its own,
    /// and a guessed one clipped the fourth seat behind the note below it.
    private let seatRow: CGFloat = 44

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TitledBlock("Wer spielt mit?") {
                        VStack(alignment: .leading, spacing: 10) {
                            if players.isEmpty {
                                Text("Noch niemand gewählt.")
                                    .font(.callout).foregroundStyle(.secondary)
                            } else {
                                FlowLayout(spacing: 8) {
                                    ForEach(players, id: \.self) { name in
                                        Text(name)
                                            .font(.callout)
                                            .padding(.horizontal, 12).padding(.vertical, 7)
                                            .background(Capsule().fill(Color(.secondarySystemBackground)))
                                    }
                                }
                            }

                            Button(players.isEmpty ? "Spielerinnen wählen" : "Ändern") {
                                taps += 1
                                pickerOpen = true
                            }
                            .accessibilityIdentifier("choose-players")
                        }
                    }

                    if !players.isEmpty {
                        TitledBlock("Zugreihenfolge — zum Verschieben ziehen") {
                            VStack(alignment: .leading, spacing: 8) {
                                List {
                                    ForEach(seating, id: \.self) { name in
                                        HStack {
                                            Text("\((seating.firstIndex(of: name) ?? 0) + 1).")
                                                .font(.callout.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                            Text(name).font(.callout)
                                        }
                                        .frame(height: seatRow)
                                        .listRowInsets(EdgeInsets(top: 0, leading: 8,
                                                                  bottom: 0, trailing: 8))
                                    }
                                    .onMove { from, to in
                                        seating.move(fromOffsets: from, toOffset: to)
                                    }
                                }
                                .environment(\.editMode, .constant(.active))
                                .environment(\.defaultMinListRowHeight, seatRow)
                                .listStyle(.plain)
                                .scrollDisabled(true)
                                .frame(height: CGFloat(seating.count) * seatRow)
                                .accessibilityIdentifier("seating")

                                Text("Auch Harmony lässt sich verschieben. Die "
                                     + "Reihenfolge kann später noch geändert "
                                     + "werden — der Weg zurück steht in der "
                                     + "Auslage offen.")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Spielerinnen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(taps) ×")
                        .font(.footnote.monospacedDigit().weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(.quaternary))
                        .accessibilityIdentifier("taps")
                }
            }
            .safeAreaInset(edge: .bottom) { footer }
            .sheet(isPresented: $pickerOpen) {
                NamePickerView(
                    title: players.isEmpty
                           ? "Wer spielt mit?" : "\(players.count) gewählt",
                    options: knownPlayers,
                    limit: maxHumans,
                    chosen: $players,
                    addPrompt: "Neue Spielerin",
                    onAdd: { name in
                        KnownPlayers.add(name)
                        knownPlayers = KnownPlayers.all
                    },
                    onDelete: { name in
                        KnownPlayers.remove(name)
                        knownPlayers = KnownPlayers.all
                        players.removeAll { $0 == name }
                    },
                    onTap: { taps += 1 },
                    // The number of humans is not fixed in advance, so the
                    // view cannot always close by itself. Below three it
                    // takes one tap — the one the count picker used to cost.
                    doneLabel: "Fertig",
                    onComplete: { pickerOpen = false })
            }
            .onChange(of: players) { _, _ in rebuildSeating() }
        }
    }

    /// What is still missing, on both setup screens alike.
    private var footer: some View {
        VStack(spacing: 8) {
            Text(players.isEmpty
                 ? "Fehlt: mindestens eine Mitspielerin."
                 : "\(players.count) von höchstens \(maxHumans) Menschen, dazu Harmony.")
                .font(.footnote).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                onNext()
            } label: {
                Text("Weiter zur Auslage").frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(players.isEmpty)
            .accessibilityIdentifier("next")
        }
        .padding(.horizontal).padding(.top, 10).padding(.bottom, 8)
        .background(.bar)
    }

    /// Keeps the order already arranged and puts anyone new in front of
    /// Harmony, so choosing a player does not silently reshuffle the seats.
    private func rebuildSeating() {
        var order = seating.filter { $0 == "Harmony" || players.contains($0) }
        for name in players where !order.contains(name) {
            order.insert(name, at: max(order.count - 1, 0))
        }
        if !order.contains("Harmony") { order.append("Harmony") }
        seating = order
    }
}

/// Step two: what lies on the table.
struct SetupBoardView: View {
    let seating: [String]
    @Binding var taps: Int
    @Binding var sideB: Bool
    @Binding var stones: [Stone]
    @Binding var cards: [String]
    var onBack: () -> Void
    var onStart: (GameState) -> Void

    @State private var cardPickerOpen = false

    private var isComplete: Bool { stones.count == 15 && cards.count == 5 }

    /// The five spaces as they are shown: each in the fixed order, so two
    /// equal spaces look equal.
    private var rows: [[Stone]] {
        (0..<5).map { field in
            DisplayField(stones: Array(stones.dropFirst(field * 3).prefix(3))).ordered
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Seite", selection: $sideB) {
                    Text("Seite A · 23 Felder").tag(false)
                    Text("Seite B · 25 Felder").tag(true)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("side")

                TitledBlock("Die Auslage — \(stones.count) von 15") {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(spacing: 8) {
                            ForEach(0..<5, id: \.self) { field in
                                HStack(spacing: 10) {
                                    ForEach(0..<3, id: \.self) { slot in
                                        StoneDot(stone: slot < rows[field].count
                                                        ? rows[field][slot] : nil, size: 28)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 14).padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemBackground)))
                            }
                        }

                        HStack(spacing: 8) {
                            ForEach(Stone.allCases) { stone in
                                Button {
                                    taps += 1
                                    if stones.count < 15 { stones.append(stone) }
                                } label: {
                                    StoneDot(stone: stone, size: 44)
                                }
                                .buttonStyle(.plain)
                                .disabled(stones.count == 15)
                                .opacity(stones.count == 15 ? 0.35 : 1)
                                .accessibilityIdentifier("palette-\(stone.rawValue)")
                                .accessibilityLabel(stone.name)
                            }
                            Spacer()
                            if !stones.isEmpty {
                                Button("Zurück") {
                                    taps += 1
                                    stones.removeLast()
                                }
                                .font(.footnote)
                                .accessibilityIdentifier("stones-undo")
                            }
                        }
                    }
                }

                TitledBlock("Die offenen Karten — \(cards.count) von 5") {
                    VStack(alignment: .leading, spacing: 10) {
                        if cards.isEmpty {
                            Text("Noch keine gewählt.")
                                .font(.callout).foregroundStyle(.secondary)
                        } else {
                            FlowLayout(spacing: 8) {
                                ForEach(Sample.sorted(cards), id: \.self) { card in
                                    Text(card)
                                        .font(.callout)
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .background(Capsule().fill(Color(.secondarySystemBackground)))
                                }
                            }
                        }
                        Button(cards.isEmpty ? "Karten wählen" : "Ändern") {
                            taps += 1
                            cardPickerOpen = true
                        }
                        .accessibilityIdentifier("choose-cards")
                    }
                }

                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("Auslage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Spielerinnen", systemImage: "chevron.left") { onBack() }
                        .accessibilityIdentifier("back")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(taps) ×")
                        .font(.footnote.monospacedDigit().weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(.quaternary))
                        .accessibilityIdentifier("taps")
                }
            }
            .safeAreaInset(edge: .bottom) { footer }
            .sheet(isPresented: $cardPickerOpen) {
                NamePickerView(
                    title: cards.count == 5 ? "Fünf gewählt" : "Noch \(5 - cards.count) wählen",
                    options: Sample.allCards,
                    limit: 5,
                    chosen: $cards,
                    onTap: { taps += 1 },
                    onComplete: { cardPickerOpen = false })
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Text(isComplete
                 ? "Vollständig — \(taps) Antipper"
                 : "Fehlen: \(15 - stones.count) Steine, \(5 - cards.count) Karten")
                .font(.footnote).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                onStart(startState())
            } label: {
                Text("Partie beginnen").frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isComplete)
            .accessibilityIdentifier("start")
        }
        .padding(.horizontal).padding(.top, 10).padding(.bottom, 8)
        .background(.bar)
    }

    /// In the engine the setup is the first event of the log; here it is
    /// the state the log starts from, which amounts to the same position.
    ///
    /// Harmony's board is **not** empty as it would be in a real game: the
    /// prototype loads a mid-game tableau so the move demonstration keeps
    /// its meaning.
    private func startState() -> GameState {
        let fields = stride(from: 0, to: 15, by: 3).map {
            DisplayField(stones: Array(stones[$0..<($0 + 3)]))
        }
        return GameState(display: fields,
                         openCards: cards,
                         seenCards: Set(cards),
                         seatIndex: 0,
                         // Eine Partie beginnt mit leerem Spielplan und
                         // ohne Karten. Die Attrappenstellung bleibt dem
                         // Startparameter `-harmonyTurn` vorbehalten, der
                         // mitten in eine Partie springt.
                         harmonyBoard: [:],
                         harmonyCubes: [:],
                         harmonyCards: [],
                         seating: seating,
                         sideB: sideB)
    }
}
