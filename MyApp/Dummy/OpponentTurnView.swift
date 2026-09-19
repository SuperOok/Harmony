import SwiftUI

/// Phase 5 click-through prototype: recording other players' turns, one
/// after another. No engine and no rule checking — what is measured is the
/// input path itself, in taps, as `pruefverfahren.md` foresees for storey
/// three. User-facing text is German, everything else English.
struct OpponentTurnView: View {
    // Game state, as far as the input path needs it
    @State private var display = Sample.display
    @State private var openCards = Sample.openCards
    @State private var seenCards = Set(Sample.openCards)
    @State private var history: [Entry] = []

    /// Launch argument for tests and for looking at a single screen, the
    /// hook `pruefverfahren.md` foresees for storey three.
    @State private var seatIndex =
        ProcessInfo.processInfo.arguments.contains("-harmonyTurn")
        ? Sample.turnOrder.count - 1 : 0

    // Input of the turn in progress
    @State private var takenIndex: Int?
    @State private var refill: [Stone] = []
    @State private var cardTaken: String?
    @State private var cardDrawn: String?
    @State private var taps = 0
    @State private var cardPickerOpen = false
    @State private var historyOpen = false
    @State private var showSideB = false

    struct Entry: Identifiable {
        let id = UUID()
        let line: String
        let taps: Int
    }

    private var currentPlayer: String { Sample.turnOrder[seatIndex] }
    private var isHarmony: Bool { currentPlayer == "Harmony" }

    private var isComplete: Bool {
        takenIndex != nil && refill.count == 3
            && (cardTaken == nil || cardDrawn != nil)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isHarmony { harmonyTurn } else { entry }
            }
            .navigationTitle(isHarmony ? "Harmony ist am Zug" : "\(currentPlayer) ist am Zug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { historyOpen = true } label: {
                        Text(isHarmony ? "\(history.count) Züge" : "\(taps) ×")
                            .font(.footnote.monospacedDigit().weight(.semibold))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Capsule().fill(.quaternary))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("taps")
                }
            }
            .sheet(isPresented: $cardPickerOpen) { cardPicker }
            .sheet(isPresented: $historyOpen) { historyList }
        }
    }

    // MARK: - Recording another player's turn

    private var entry: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                displaySection
                if takenIndex != nil { refillSection }
                cardSection
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) { footer }
    }

    private var displaySection: some View {
        TitledBlock("Welches Feld wurde genommen?") {
            VStack(spacing: 8) {
                ForEach(Array(display.enumerated()), id: \.element.id) { index, field in
                    Button {
                        taps += 1
                        takenIndex = index
                        refill = []
                    } label: {
                        HStack(spacing: 10) {
                            ForEach(Array(field.stones.enumerated()), id: \.offset) { _, stone in
                                StoneDot(stone: stone, size: 30)
                            }
                            Spacer()
                            if takenIndex == index {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(takenIndex == index ? Color.accentColor.opacity(0.14)
                                                          : Color(.secondarySystemBackground))
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("field-\(index)")
                }
            }
        }
    }

    private var refillSection: some View {
        TitledBlock("Was wurde nachgefüllt?") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { i in
                        StoneDot(stone: i < refill.count ? refill[i] : nil)
                    }
                    Spacer()
                    if !refill.isEmpty {
                        Button("Zurück") {
                            taps += 1
                            refill.removeLast()
                        }
                        .font(.footnote)
                        .accessibilityIdentifier("refill-undo")
                    }
                }
                HStack(spacing: 8) {
                    ForEach(Stone.allCases) { stone in
                        Button {
                            taps += 1
                            if refill.count < 3 { refill.append(stone) }
                        } label: {
                            StoneDot(stone: stone, size: 44)
                        }
                        .buttonStyle(.plain)
                        .disabled(refill.count == 3)
                        .opacity(refill.count == 3 ? 0.35 : 1)
                        .accessibilityIdentifier("palette-\(stone.rawValue)")
                        .accessibilityLabel(stone.name)
                    }
                }
            }
        }
    }

    private var cardSection: some View {
        TitledBlock("Wurde eine Karte genommen?") {
            VStack(alignment: .leading, spacing: 12) {
                FlowLayout(spacing: 8) {
                    ForEach(openCards, id: \.self) { name in
                        Button {
                            taps += 1
                            if cardTaken == name {
                                cardTaken = nil; cardDrawn = nil
                            } else {
                                cardTaken = name; cardDrawn = nil
                            }
                        } label: {
                            Text(name)
                                .font(.callout)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(
                                    Capsule().fill(cardTaken == name
                                        ? Color.accentColor.opacity(0.18)
                                        : Color(.secondarySystemBackground))
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("card-\(name)")
                    }
                }
                if cardTaken != nil {
                    Button {
                        taps += 1
                        cardPickerOpen = true
                    } label: {
                        HStack {
                            Text(cardDrawn ?? "Welche Karte rückte nach?")
                                .foregroundStyle(cardDrawn == nil ? .secondary : .primary)
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

    // MARK: - Harmony's turn (placeholder around the board)

    private var harmonyTurn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Seite", selection: $showSideB) {
                    Text("Seite A").tag(false)
                    Text("Seite B").tag(true)
                }
                .pickerStyle(.segmented)

                BoardView(side: showSideB ? .b : .a,
                          columns: showSideB ? BoardView.sideB : BoardView.sideA,
                          cells: showSideB ? BoardView.sampleCellsB : BoardView.sampleCellsA)
                    .padding(.horizontal, 4)

                Text(showSideB
                     ? "Seite B wertet keine Flüsse, sondern Inseln — die "
                       + "Zusammenhangsgebiete der nicht-blauen Felder, leere "
                       + "eingeschlossen. Wasser zählt hier nicht selbst, es "
                       + "trennt: Satt ist nur, was an zwei verschiedene Inseln "
                       + "grenzt. Die vierte Spalte trennt, das Wasser oben "
                       + "links trennt nichts."
                     : "Satte Tönung heißt: Diese Zelle bringt gerade Punkte. "
                       + "Blass heißt Landschaft ohne Punkte — der Berg3 links "
                       + "oben hat keinen Bergnachbarn, das einzelne Feld keinen "
                       + "Partner, und der Ast neben dem längsten Fluss zählt "
                       + "nicht mit.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Divider()

                TitledBlock("So sähe die Anweisung aus") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Nimm das Feld mit Holz, Laub, Stein.")
                        Text("1  Stein auf die leere Zelle 5.1")
                        Text("2  Holz auf 5.2, 3  Laub darauf — Baum der Höhe 2")
                        Text("Tierwürfel auf 5.2")
                    }
                    .font(.callout)
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            Button("Harmony hat gezogen") { nextSeat() }
                .buttonStyle(.borderedProminent)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.bar)
                .accessibilityIdentifier("harmony-done")
        }
    }

    // MARK: - Pickers

    /// Two columns, alphabetical and filled **column by column** like a
    /// printed list: A to the middle on the left, the rest on the right.
    /// Looking a name up then means scanning one column instead of checking
    /// both halves of every row.
    private var cardPicker: some View {
        let remaining = Sample.allCards
            .filter { !seenCards.contains($0) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        let split = (remaining.count + 1) / 2
        let left = Array(remaining.prefix(split))
        let right = Array(remaining.dropFirst(split))

        return NavigationStack {
            VStack(spacing: 8) {
                ForEach(left.indices, id: \.self) { i in
                    HStack(spacing: 8) {
                        cardCell(left[i])
                        if i < right.count {
                            cardCell(right[i])
                        } else {
                            Color.clear.frame(height: 42).frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .frame(maxHeight: .infinity, alignment: .top)
            .navigationTitle("Nachgerückt · \(remaining.count) im Stapel")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func cardCell(_ name: String) -> some View {
        Button {
            taps += 1
            cardDrawn = name
            cardPickerOpen = false
        } label: {
            Text(name)
                .font(.callout)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("draw-\(name)")
    }

    private var historyList: some View {
        NavigationStack {
            Group {
                if history.isEmpty {
                    ContentUnavailableView("Noch kein Zug erfasst", systemImage: "list.bullet")
                } else {
                    List(history) { entry in
                        HStack {
                            Text(entry.line).font(.system(.footnote, design: .monospaced))
                            Spacer()
                            Text("\(entry.taps) ×")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Verlauf")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Footer and turn change

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

            Button { record() } label: {
                Text("Zug eintragen").frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isComplete)
            .accessibilityIdentifier("record")
        }
        .padding(.horizontal).padding(.top, 10).padding(.bottom, 8)
        .background(.bar)
    }

    private var line: String {
        var parts = [currentPlayer]
        if let index = takenIndex { parts.append("-\(display[index].notation)") }
        if let card = cardTaken { parts.append("+\(card)") }
        if refill.count == 3 { parts.append(">" + refill.map(\.rawValue).joined()) }
        if let drawn = cardDrawn { parts.append(">\(drawn)") }
        return parts.joined(separator: "  ")
    }

    private func record() {
        history.append(Entry(line: line, taps: taps + 1))

        // The emptied space takes the stones drawn for it.
        if let index = takenIndex { display[index] = DisplayField(stones: refill) }

        // The taken card is replaced by the one that came up.
        if let taken = cardTaken, let drawn = cardDrawn,
           let index = openCards.firstIndex(of: taken) {
            openCards[index] = drawn
            seenCards.insert(drawn)
        }

        nextSeat()
    }

    private func nextSeat() {
        takenIndex = nil
        refill = []
        cardTaken = nil
        cardDrawn = nil
        taps = 0
        seatIndex = (seatIndex + 1) % Sample.turnOrder.count
    }
}

// MARK: - Building blocks

struct StoneDot: View {
    let stone: Stone?
    var size: CGFloat = 34

    var body: some View {
        Group {
            if let stone {
                Circle().fill(stone.color)
                    .overlay(Circle().strokeBorder(.primary.opacity(0.2), lineWidth: 1))
            } else {
                Circle().strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: size, height: size)
    }
}

struct TitledBlock<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            content
        }
    }
}

/// A wrapping row — the card names differ in length.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    OpponentTurnView()
}
