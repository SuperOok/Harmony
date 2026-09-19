import SwiftUI

/// Klickdummy aus Phase 5: der fremde Zug, der einzige zeitkritische
/// Eingabeweg. Keine Funktion dahinter — gemessen wird der Weg selbst,
/// in Antippern, wie `pruefverfahren.md` es für Stockwerk 3 vorsieht.
struct FremderZugView: View {
    @State private var genommen: Int?
    @State private var nachfuellung: [Stein] = []
    @State private var karteGenommen: String?
    @State private var karteNach: String?
    @State private var antipper = 0
    @State private var kartenwahlOffen = false

    private var vollstaendig: Bool {
        genommen != nil && nachfuellung.count == 3
            && (karteGenommen == nil || karteNach != nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    auslage
                    if genommen != nil { nachfuellen }
                    karten
                }
                .padding()
            }
            .navigationTitle("\(Attrappe.amZug) ist am Zug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(antipper) ×")
                        .font(.footnote.monospacedDigit().weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(.quaternary))
                        .accessibilityIdentifier("antipper")
                }
            }
            .safeAreaInset(edge: .bottom) { fussleiste }
            .sheet(isPresented: $kartenwahlOffen) { kartenwahl }
        }
    }

    // MARK: - Auslage

    private var auslage: some View {
        Abschnitt("Welches Feld wurde genommen?") {
            VStack(spacing: 8) {
                ForEach(Array(Attrappe.auslage.enumerated()), id: \.element.id) { i, feld in
                    Button {
                        antipper += 1
                        genommen = i
                        nachfuellung = []
                    } label: {
                        HStack(spacing: 10) {
                            ForEach(Array(feld.steine.enumerated()), id: \.offset) { _, s in
                                SteinPunkt(stein: s, groesse: 30)
                            }
                            Spacer()
                            if genommen == i {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(genommen == i ? Color.accentColor.opacity(0.14) : Color(.secondarySystemBackground))
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("feld-\(i)")
                }
            }
        }
    }

    // MARK: - Nachfüllung

    private var nachfuellen: some View {
        Abschnitt("Was wurde nachgefüllt?") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { i in
                        SteinPunkt(stein: i < nachfuellung.count ? nachfuellung[i] : nil)
                    }
                    Spacer()
                    if !nachfuellung.isEmpty {
                        Button("Zurück") {
                            antipper += 1
                            nachfuellung.removeLast()
                        }
                        .font(.footnote)
                        .accessibilityIdentifier("nachfuellung-zurueck")
                    }
                }
                HStack(spacing: 8) {
                    ForEach(Stein.allCases) { s in
                        Button {
                            antipper += 1
                            if nachfuellung.count < 3 { nachfuellung.append(s) }
                        } label: {
                            SteinPunkt(stein: s, groesse: 44)
                        }
                        .buttonStyle(.plain)
                        .disabled(nachfuellung.count == 3)
                        .opacity(nachfuellung.count == 3 ? 0.35 : 1)
                        .accessibilityIdentifier("palette-\(s.rawValue)")
                        .accessibilityLabel(s.name)
                    }
                }
            }
        }
    }

    // MARK: - Karten

    private var karten: some View {
        Abschnitt("Wurde eine Karte genommen?") {
            VStack(alignment: .leading, spacing: 12) {
                FlussLayout(abstand: 8) {
                    ForEach(Attrappe.offeneKarten, id: \.self) { name in
                        Button {
                            antipper += 1
                            if karteGenommen == name {
                                karteGenommen = nil; karteNach = nil
                            } else {
                                karteGenommen = name; karteNach = nil
                            }
                        } label: {
                            Text(name)
                                .font(.callout)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(
                                    Capsule().fill(karteGenommen == name
                                        ? Color.accentColor.opacity(0.18)
                                        : Color(.secondarySystemBackground))
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("karte-\(name)")
                    }
                }
                if karteGenommen != nil {
                    Button {
                        antipper += 1
                        kartenwahlOffen = true
                    } label: {
                        HStack {
                            Text(karteNach ?? "Welche Karte rückte nach?")
                                .foregroundStyle(karteNach == nil ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("nachgerueckt")
                }
            }
        }
    }

    /// Zwei Spalten, alphabetisch und **spaltenweise** gefüllt wie ein
    /// Telefonbuch: links A bis zur Mitte, rechts der Rest. Beim Suchen
    /// nach einem Namen läuft der Blick dann eine Spalte hinunter, statt
    /// zwischen beiden zu zickzacken.
    private var kartenwahl: some View {
        let uebrig = Attrappe.alleKarten
            .filter { !Attrappe.offeneKarten.contains($0) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        let umbruch = (uebrig.count + 1) / 2
        let links = Array(uebrig.prefix(umbruch))
        let rechts = Array(uebrig.dropFirst(umbruch))

        return NavigationStack {
            VStack(spacing: 8) {
                ForEach(links.indices, id: \.self) { i in
                    HStack(spacing: 8) {
                        karteZelle(links[i])
                        if i < rechts.count {
                            karteZelle(rechts[i])
                        } else {
                            Color.clear.frame(height: 42).frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .frame(maxHeight: .infinity, alignment: .top)
            .navigationTitle("Nachgerückt")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func karteZelle(_ name: String) -> some View {
        Button {
            antipper += 1
            karteNach = name
            kartenwahlOffen = false
        } label: {
            Text(name)
                .font(.callout)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.secondarySystemBackground)))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("nachruecker-\(name)")
    }

    // MARK: - Notation und Fußleiste

    private var zeile: String {
        var teile = [Attrappe.amZug]
        if let g = genommen { teile.append("-\(Attrappe.auslage[g].notation)") }
        if let k = karteGenommen { teile.append("+\(k)") }
        if nachfuellung.count == 3 { teile.append(">" + nachfuellung.map(\.rawValue).joined()) }
        if let n = karteNach { teile.append(">\(n)") }
        return teile.joined(separator: "  ")
    }

    /// Die Protokollzeile steht bei der Schaltfläche, nicht im Inhalt:
    /// Sie zeigt, was gleich eingetragen wird, und kann so nicht aus dem
    /// Bild geschoben werden.
    private var fussleiste: some View {
        VStack(spacing: 8) {
            Text(zeile)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("notation")

            Button {
                antipper += 1
            } label: {
                Text("Zug eintragen")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!vollstaendig)
            .accessibilityIdentifier("eintragen")
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.bar)
    }
}

// MARK: - Bausteine

struct SteinPunkt: View {
    let stein: Stein?
    var groesse: CGFloat = 34

    var body: some View {
        Group {
            if let stein {
                Circle().fill(stein.farbe)
                    .overlay(Circle().strokeBorder(.black.opacity(0.15), lineWidth: 1))
            } else {
                Circle().strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: groesse, height: groesse)
    }
}

private struct Abschnitt<Inhalt: View>: View {
    let titel: String
    @ViewBuilder let inhalt: Inhalt

    init(_ titel: String, @ViewBuilder inhalt: () -> Inhalt) {
        self.titel = titel
        self.inhalt = inhalt()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(titel).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            inhalt
        }
    }
}

/// Umbrechende Reihe — die Kartennamen sind unterschiedlich lang.
private struct FlussLayout: Layout {
    var abstand: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let breite = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, zeile: CGFloat = 0
        for s in subviews {
            let g = s.sizeThatFits(.unspecified)
            if x + g.width > breite, x > 0 { x = 0; y += zeile + abstand; zeile = 0 }
            x += g.width + abstand
            zeile = max(zeile, g.height)
        }
        return CGSize(width: breite, height: y + zeile)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, zeile: CGFloat = 0
        for s in subviews {
            let g = s.sizeThatFits(.unspecified)
            if x + g.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += zeile + abstand; zeile = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(g))
            x += g.width + abstand
            zeile = max(zeile, g.height)
        }
    }
}

#Preview {
    FremderZugView()
}
