import SwiftUI

/// Szenario 1, in two steps so that neither has to be scrolled: first who
/// is playing, then what lies on the table.
///
/// The split is not only about height. Players outlive a single game —
/// version two is to add up everyone's score and keep past games, which
/// needs them recognised again — while the display is thrown away with the
/// game. Two screens keep the two apart.
struct SetupView: View {
    var onStart: (GameState) -> Void

    @State private var step = 1
    @State private var players: [String] = []
    @State private var harmonySeat = 2
    @State private var taps = 0

    var body: some View {
        if step == 1 {
            SetupPlayersView(players: $players,
                             harmonySeat: $harmonySeat,
                             taps: $taps,
                             onNext: { step = 2 })
        } else {
            SetupBoardView(seating: seating,
                           taps: $taps,
                           onBack: { step = 1 },
                           onStart: onStart)
        }
    }

    /// The order players were picked in **is** the seating; Harmony takes
    /// the place chosen for her.
    private var seating: [String] {
        var order = players
        order.insert("Harmony", at: min(harmonySeat, order.count))
        return order
    }
}

/// Step one: who is playing, and in which order.
struct SetupPlayersView: View {
    @Binding var players: [String]
    @Binding var harmonySeat: Int
    @Binding var taps: Int
    var onNext: () -> Void

    @State private var humanCount = 2
    @State private var pickerOpen = false

    private var seating: [String] {
        var order = players
        order.insert("Harmony", at: min(harmonySeat, order.count))
        return order
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                TitledBlock("Wie viele Menschen?") {
                    Picker("Menschen", selection: $humanCount) {
                        Text("1").tag(1)
                        Text("2").tag(2)
                        Text("3").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: humanCount) { _, count in
                        if players.count > count { players.removeLast(players.count - count) }
                        harmonySeat = min(harmonySeat, count)
                    }
                    .accessibilityIdentifier("human-count")
                }

                TitledBlock("Wer spielt mit?") {
                    VStack(alignment: .leading, spacing: 12) {
                        if players.isEmpty {
                            Text("Noch niemand gewählt.")
                                .font(.callout).foregroundStyle(.secondary)
                        } else {
                            FlowLayout(spacing: 8) {
                                ForEach(Array(players.enumerated()), id: \.offset) { index, name in
                                    Text("\(index + 1). \(name)")
                                        .font(.callout)
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .background(Capsule().fill(Color(.secondarySystemBackground)))
                                }
                            }
                        }

                        HStack {
                            Button(players.isEmpty ? "Spieler wählen" : "Ändern") {
                                taps += 1
                                pickerOpen = true
                            }
                            .accessibilityIdentifier("choose-players")

                            Spacer()

                            if !players.isEmpty {
                                Button("Zurück") {
                                    taps += 1
                                    players.removeLast()
                                }
                                .font(.footnote)
                                .accessibilityIdentifier("players-undo")
                            }
                        }

                        Text("Die Reihenfolge der Auswahl ist die Zugreihenfolge. "
                             + "Bekannte Spieler stehen in der Liste; neue lassen "
                             + "sich dort eintragen.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }

                TitledBlock("Harmonys Platz") {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Platz", selection: $harmonySeat) {
                            ForEach(0...humanCount, id: \.self) { seat in
                                Text("\(seat + 1).").tag(seat)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(seating.enumerated()
                             .map { "\($0.offset + 1). \($0.element)" }
                             .joined(separator: "   "))
                            .font(.footnote).foregroundStyle(.secondary)
                            .accessibilityIdentifier("seating")
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Spieler")
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
            .safeAreaInset(edge: .bottom) {
                Button {
                    onNext()
                } label: {
                    Text("Weiter zur Auslage").frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(players.count != humanCount)
                .padding()
                .background(.bar)
                .accessibilityIdentifier("next")
            }
            .sheet(isPresented: $pickerOpen) {
                NamePickerView(
                    title: players.count == humanCount
                           ? "Vollzählig" : "Noch \(humanCount - players.count) wählen",
                    options: KnownPlayers.all,
                    limit: humanCount,
                    chosen: $players,
                    addPrompt: "Neuer Spieler",
                    onAdd: { KnownPlayers.add($0) },
                    onTap: { taps += 1 },
                    onComplete: { pickerOpen = false })
            }
        }
    }
}

/// Step two: what lies on the table.
struct SetupBoardView: View {
    let seating: [String]
    @Binding var taps: Int
    var onBack: () -> Void
    var onStart: (GameState) -> Void

    @State private var sideB = false
    /// Filled in reading order, so no space has to be picked first.
    @State private var stones: [Stone] = []
    @State private var cards: [String] = []
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
                    Button("Spieler", systemImage: "chevron.left") { onBack() }
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
                         harmonyBoard: Sample.harmonyBoard,
                         harmonyCubes: [:],
                         seating: seating,
                         sideB: sideB)
    }
}
