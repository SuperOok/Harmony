import SwiftUI

/// Szenario 1: what lies on the table before the first turn — five spaces
/// of three stones, five open cards, the board side, the seating and the
/// names.
///
/// This is the largest single input of a game and it falls into the setup
/// phase, where everyone is sorting anyway and nobody waits. Thoroughness
/// beats speed here, which is why it is one screen rather than a sequence
/// of steps: any part can be filled in any order and what is still missing
/// stays visible.
struct SetupView: View {
    var onStart: (GameState) -> Void

    /// Harmonies seats four. One to three humans plus Harmony therefore
    /// covers every case in which she can play at all.
    @State private var humanCount = 2
    @State private var names = ["", "", ""]
    @State private var harmonySeat = 2
    @State private var sideB = false
    /// Filled in reading order, so no space has to be picked first.
    @State private var stones: [Stone] = []
    @State private var cards: [String] = []
    @State private var taps = 0
    @State private var cardPickerOpen = false

    private var isComplete: Bool { stones.count == 15 && cards.count == 5 }

    /// The five spaces as they are shown: each in the fixed order, so two
    /// equal spaces look equal.
    private var rows: [[Stone]] {
        (0..<5).map { field in
            let slice = Array(stones.dropFirst(field * 3).prefix(3))
            return DisplayField(stones: slice).ordered
        }
    }

    private func name(_ index: Int) -> String {
        names[index].isEmpty ? "Spieler \(index + 1)" : names[index]
    }

    /// The seating, with Harmony in her chosen place.
    private var seating: [String] {
        var order = (0..<humanCount).map(name)
        order.insert("Harmony", at: min(harmonySeat, order.count))
        return order
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    playersSection
                    sideSection
                    displaySection
                    cardsSection
                }
                .padding()
            }
            .navigationTitle("Aufbau")
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
            .sheet(isPresented: $cardPickerOpen) { cardPicker }
        }
    }

    // MARK: - Wer spielt mit

    private var playersSection: some View {
        TitledBlock("Wer spielt mit?") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Menschen", selection: $humanCount) {
                    Text("1").tag(1)
                    Text("2").tag(2)
                    Text("3").tag(3)
                }
                .pickerStyle(.segmented)
                .onChange(of: humanCount) { _, count in
                    harmonySeat = min(harmonySeat, count)
                }

                ForEach(0..<humanCount, id: \.self) { index in
                    TextField("Spieler \(index + 1)", text: $names[index])
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("name-\(index)")
                }

                Text("Namen sind eine Bequemlichkeit. Die Engine braucht nur "
                     + "die Zugreihenfolge; der Name macht Anweisung und "
                     + "Begründung lesbar.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Picker("Harmonys Platz", selection: $harmonySeat) {
                    ForEach(0...humanCount, id: \.self) { seat in
                        Text("\(seat + 1).").tag(seat)
                    }
                }
                .pickerStyle(.segmented)

                Text("Zugreihenfolge: " + seating.joined(separator: " → "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("seating")
            }
        }
    }

    // MARK: - Planseite

    private var sideSection: some View {
        TitledBlock("Welche Seite des Spielplans?") {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Seite", selection: $sideB) {
                    Text("Seite A · 23 Felder").tag(false)
                    Text("Seite B · 25 Felder").tag(true)
                }
                .pickerStyle(.segmented)

                Text(sideB
                     ? "Seite B wertet Inseln statt eines Flusses."
                     : "Seite A wertet den längsten Fluss.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Auslage

    private var displaySection: some View {
        TitledBlock("Die Auslage — \(stones.count) von 15 Steinen") {
            VStack(alignment: .leading, spacing: 14) {
                VStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { field in
                        HStack(spacing: 10) {
                            ForEach(0..<3, id: \.self) { slot in
                                StoneDot(stone: slot < rows[field].count ? rows[field][slot] : nil,
                                         size: 30)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
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

                Text("Die Steine werden der Reihe nach eingesetzt, von oben "
                     + "links; kein Feld muss vorher ausgewählt werden. "
                     + "Innerhalb eines Feldes stehen sie in fester Ordnung, "
                     + "damit gleiche Felder sofort als gleich zu erkennen "
                     + "sind — die Reihenfolge in einem Feld bedeutet nichts.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Offene Karten

    private var cardsSection: some View {
        TitledBlock("Die offenen Karten — \(cards.count) von 5") {
            VStack(alignment: .leading, spacing: 12) {
                if cards.isEmpty {
                    Text("Noch keine gewählt.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
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

                HStack {
                    Button(cards.isEmpty ? "Karten wählen" : "Weiter wählen") {
                        taps += 1
                        cardPickerOpen = true
                    }
                    .disabled(cards.count == 5)
                    .accessibilityIdentifier("choose-cards")

                    Spacer()

                    if !cards.isEmpty {
                        Button("Zurück") {
                            taps += 1
                            cards.removeLast()
                        }
                        .font(.footnote)
                        .accessibilityIdentifier("cards-undo")
                    }
                }
            }
        }
    }

    /// The same picker the game uses, here for five cards in a row. They
    /// stay highlighted as they are chosen, and after the fifth the view
    /// closes on its own.
    private var cardPicker: some View {
        CardPickerView(
            title: cards.count == 5 ? "Fünf gewählt" : "Noch \(5 - cards.count) wählen",
            unavailable: [],
            limit: 5,
            chosen: $cards,
            onTap: { taps += 1 },
            onComplete: { cardPickerOpen = false })
    }

    // MARK: - Fußleiste

    private var footer: some View {
        VStack(spacing: 8) {
            Text(isComplete
                 ? "Vollständig — \(taps) Antipper"
                 : "Fehlen: \(15 - stones.count) Steine, \(5 - cards.count) Karten")
                .font(.footnote)
                .foregroundStyle(.secondary)
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
