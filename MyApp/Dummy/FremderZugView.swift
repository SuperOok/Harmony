import SwiftUI

/// Klickdummy aus Phase 5: das Erfassen fremder Züge, Zug um Zug.
/// Keine Engine, keine Regelprüfung — gemessen wird der Eingabeweg selbst,
/// in Antippern, wie `pruefverfahren.md` es für Stockwerk 3 vorsieht.
struct FremderZugView: View {
    // Spielzustand, so weit der Eingabeweg ihn braucht
    @State private var auslage = Attrappe.auslage
    @State private var offeneKarten = Attrappe.offeneKarten
    @State private var gesehen = Set(Attrappe.offeneKarten)
    /// Startparameter für Tests und zum Ansehen einzelner Bildschirme,
    /// wie `pruefverfahren.md` es für Stockwerk 3 vorsieht.
    @State private var spielerIndex =
        ProcessInfo.processInfo.arguments.contains("-harmonyAmZug")
        ? Attrappe.reihenfolge.count - 1 : 0
    @State private var verlauf: [Eintrag] = []

    // Eingabe des laufenden Zuges
    @State private var genommen: Int?
    @State private var nachfuellung: [Stein] = []
    @State private var karteGenommen: String?
    @State private var karteNach: String?
    @State private var antipper = 0
    @State private var kartenwahlOffen = false
    @State private var verlaufOffen = false

    struct Eintrag: Identifiable {
        let id = UUID()
        let zeile: String
        let antipper: Int
    }

    private var amZug: String { Attrappe.reihenfolge[spielerIndex] }
    private var istHarmony: Bool { amZug == "Harmony" }

    private var vollstaendig: Bool {
        genommen != nil && nachfuellung.count == 3
            && (karteGenommen == nil || karteNach != nil)
    }

    var body: some View {
        NavigationStack {
            Group {
                if istHarmony { harmonysZug } else { eingabe }
            }
            .navigationTitle(istHarmony ? "Harmony ist am Zug" : "\(amZug) ist am Zug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { verlaufOffen = true } label: {
                        Text(istHarmony ? "\(verlauf.count) Züge" : "\(antipper) ×")
                            .font(.footnote.monospacedDigit().weight(.semibold))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Capsule().fill(.quaternary))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("antipper")
                }
            }
            .sheet(isPresented: $kartenwahlOffen) { kartenwahl }
            .sheet(isPresented: $verlaufOffen) { verlaufListe }
        }
    }

    // MARK: - Eingabe eines fremden Zuges

    private var eingabe: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                auslageAbschnitt
                if genommen != nil { nachfuellen }
                karten
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) { fussleiste }
    }

    private var auslageAbschnitt: some View {
        Abschnitt("Welches Feld wurde genommen?") {
            VStack(spacing: 8) {
                ForEach(Array(auslage.enumerated()), id: \.element.id) { i, feld in
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
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(genommen == i ? Color.accentColor.opacity(0.14)
                                                    : Color(.secondarySystemBackground))
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("feld-\(i)")
                }
            }
        }
    }

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

    private var karten: some View {
        Abschnitt("Wurde eine Karte genommen?") {
            VStack(alignment: .leading, spacing: 12) {
                FlussLayout(abstand: 8) {
                    ForEach(offeneKarten, id: \.self) { name in
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

    // MARK: - Harmonys Zug (Platzhalter)

    private var harmonysZug: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TableauView(spalten: TableauView.seiteA,
                            zellen: TableauView.musterZellen)
                    .padding(.horizontal, 4)

                Text("Musterbrett — jeder Zellzustand einmal. Eine Zelle ist "
                     + "ein Stapel und wird auch so gezeigt: eine Scheibe je "
                     + "Stein, von unten nach oben.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Divider()

                Abschnitt("So sähe die Anweisung aus") {
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
            Button("Harmony hat gezogen") { naechsterSpieler() }
                .buttonStyle(.borderedProminent)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.bar)
                .accessibilityIdentifier("harmony-fertig")
        }
    }

    // MARK: - Auswahllisten

    /// Zwei Spalten, alphabetisch und **spaltenweise** gefüllt wie ein
    /// Telefonbuch: links A bis zur Mitte, rechts der Rest.
    private var kartenwahl: some View {
        let uebrig = Attrappe.alleKarten
            .filter { !gesehen.contains($0) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        let umbruch = (uebrig.count + 1) / 2
        let links = Array(uebrig.prefix(umbruch))
        let rechts = Array(uebrig.dropFirst(umbruch))

        return NavigationStack {
            ScrollView {
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
            }
            .navigationTitle("Nachgerückt · \(uebrig.count) im Stapel")
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
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("nachruecker-\(name)")
    }

    private var verlaufListe: some View {
        NavigationStack {
            Group {
                if verlauf.isEmpty {
                    ContentUnavailableView("Noch kein Zug erfasst", systemImage: "list.bullet")
                } else {
                    List(verlauf) { e in
                        HStack {
                            Text(e.zeile).font(.system(.footnote, design: .monospaced))
                            Spacer()
                            Text("\(e.antipper) ×")
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

    // MARK: - Fußleiste und Zugwechsel

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

            Button { eintragen() } label: {
                Text("Zug eintragen").frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!vollstaendig)
            .accessibilityIdentifier("eintragen")
        }
        .padding(.horizontal).padding(.top, 10).padding(.bottom, 8)
        .background(.bar)
    }

    private var zeile: String {
        var teile = [amZug]
        if let g = genommen { teile.append("-\(auslage[g].notation)") }
        if let k = karteGenommen { teile.append("+\(k)") }
        if nachfuellung.count == 3 { teile.append(">" + nachfuellung.map(\.rawValue).joined()) }
        if let n = karteNach { teile.append(">\(n)") }
        return teile.joined(separator: "  ")
    }

    private func eintragen() {
        verlauf.append(Eintrag(zeile: zeile, antipper: antipper + 1))

        // Das geleerte Feld nimmt die nachgezogenen Steine auf.
        if let g = genommen { auslage[g] = Feld(steine: nachfuellung) }

        // Die genommene Karte wird durch die nachgerückte ersetzt.
        if let k = karteGenommen, let n = karteNach,
           let i = offeneKarten.firstIndex(of: k) {
            offeneKarten[i] = n
            gesehen.insert(n)
        }

        naechsterSpieler()
    }

    private func naechsterSpieler() {
        genommen = nil
        nachfuellung = []
        karteGenommen = nil
        karteNach = nil
        antipper = 0
        spielerIndex = (spielerIndex + 1) % Attrappe.reihenfolge.count
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

struct Abschnitt<Inhalt: View>: View {
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
