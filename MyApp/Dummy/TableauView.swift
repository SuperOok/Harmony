import SwiftUI

/// Flat-top-Sechseck: Ecken links und rechts, Kanten oben und unten.
/// In ein Rechteck der Breite 2R und Höhe √3·R eingepasst.
struct Sechseck: Shape {
    func path(in rect: CGRect) -> Path {
        let r = rect.width / 2
        var p = Path()
        for i in 0..<6 {
            let a = Double(i) * .pi / 3
            let pt = CGPoint(x: rect.midX + r * cos(a), y: rect.midY + r * sin(a))
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath()
        return p
    }
}

/// Eine Zelle ist ein Stapel. Sie wird auch so gezeigt: eine Scheibe je
/// Stein, von unten nach oben, mit Fugen dazwischen — die Höhe liest man
/// dann ab, statt eine Zahl entziffern zu müssen. Kartenmuster verlangen
/// die Höhe exakt, Berg2 und Berg3 dürfen sich nicht ähneln.
struct ZelleView: View {
    var stapel: [Stein] = []
    var wuerfel = false
    var markierung: String? = nil
    /// Bringt diese Zelle gerade Punkte? Satte Tönung heißt ja, blasse
    /// heißt: Landschaft ja, Punkte nein — ein Berg ohne Bergnachbarn, ein
    /// einzelnes Feld, ein Ast neben dem längsten Fluss.
    var zaehlt = false

    /// Das Sechseck ist das **Feld**, der Stapel sein **Inhalt** — so wie am
    /// Tisch, wo runde Plättchen in einem Sechseckfeld liegen und es nicht
    /// ausfüllen. Von der Seite gesehen ist ein rundes Plättchen ein flaches
    /// Rechteck.
    ///
    /// Aufgebaut wird vom Zellboden nach oben: drei Plättchenhöhen, so hoch
    /// wie ein Stapel werden darf, und darüber Platz für den Tierwürfel. Er
    /// **liegt auf** dem obersten Plättchen, statt es zu verdecken — deshalb
    /// sind die Plättchen flach und er ist würfelig.
    private static let reihen = 3
    private static let wuerfelFaktor: CGFloat = 1.3

    var body: some View {
        GeometryReader { geo in
            let breite = geo.size.width
            let hoehe = geo.size.height
            let fuge: CGFloat = 2

            let nutzhoehe = hoehe * 0.82
            let dicke = (nutzhoehe - fuge * CGFloat(Self.reihen - 1) - fuge)
                / (CGFloat(Self.reihen) + Self.wuerfelFaktor)
            let wuerfelKante = dicke * Self.wuerfelFaktor
            let boden = hoehe - hoehe * 0.09

            ZStack {
                // Die Tönung zeigt die abgeleitete Landschaft, die Plättchen
                // die Steine. Ein nackter brauner oder roter Stein bildet
                // keine Landschaft und bleibt deshalb neutral.
                Sechseck().fill(Color(.tertiarySystemFill))
                if let landschaft = stapel.landschaft {
                    Sechseck().fill(landschaft.tönung.opacity(zaehlt ? 0.45 : 0.15))
                }
                Sechseck().stroke(Color(.separator), lineWidth: 1)

                ForEach(Array(stapel.enumerated()), id: \.offset) { vonUnten, stein in
                    RoundedRectangle(cornerRadius: dicke * 0.4)
                        .fill(stein.farbe)
                        // Passt sich dem Erscheinungsbild an: Schwarz wäre
                        // auf dunklem Grund unsichtbar, und dann ließen sich
                        // zwei gleichfarbige Plättchen nicht auseinanderhalten.
                        .overlay(RoundedRectangle(cornerRadius: dicke * 0.4)
                            .strokeBorder(.primary.opacity(0.25), lineWidth: 0.8))
                        .frame(width: breite * 0.48, height: dicke)
                        .position(x: breite / 2,
                                  y: boden - CGFloat(vonUnten) * (dicke + fuge) - dicke / 2)
                }

                if wuerfel {
                    // Die echten Tierwürfel sind durchscheinend orange.
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(red: 0.95, green: 0.55, blue: 0.10).opacity(0.85))
                        .overlay(RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(.white.opacity(0.9), lineWidth: 1.2))
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .frame(width: wuerfelKante, height: wuerfelKante)
                        .position(x: breite / 2,
                                  y: boden - CGFloat(max(stapel.count, 0)) * (dicke + fuge)
                                     - wuerfelKante / 2)
                }

                if let markierung {
                    Sechseck().stroke(Color.accentColor, lineWidth: 3)
                    Text(markierung)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor))
                        .position(x: breite / 2, y: hoehe * 0.16)
                }
            }
        }
    }
}

/// Ein Spielplan als Sechseckgitter. Spalten von links nach rechts, gerade
/// Spalten eine halbe Zelle tiefer — die Geometrie aus `regeln-basisspiel.md`.
struct TableauView: View {
    struct Zelle {
        var stapel: [Stein] = []
        var wuerfel = false
        var markierung: String? = nil
    }

    let seite: Planseite
    /// Felder je Spalte: Seite A ist 5-4-5-4-5, Seite B ist 4-3-4-3-4-3-4.
    let spalten: [Int]
    /// Zellen unter ihrem Namen `<Spalte><Zeile>`.
    var zellen: [Int: Zelle] = [:]

    private var maxZeilen: Int { spalten.max() ?? 0 }

    private var zaehlende: Set<Int> {
        Brettwertung(seite: seite, spalten: spalten,
                     stapel: zellen.compactMapValues { $0.stapel.isEmpty ? nil : $0.stapel })
            .zaehlende()
    }

    var body: some View {
        GeometryReader { geo in
            // Breite = R·(1,5·Spalten + 0,5), Höhe = √3·R·maxZeilen
            let rBreite = geo.size.width / (1.5 * CGFloat(spalten.count) + 0.5)
            let rHoehe = geo.size.height / (sqrt(3) * CGFloat(maxZeilen))
            let r = min(rBreite, rHoehe)
            let zellHoehe = sqrt(3) * r

            ZStack(alignment: .topLeading) {
                ForEach(Array(spalten.enumerated()), id: \.offset) { si, anzahl in
                    let spalte = si + 1
                    ForEach(1...anzahl, id: \.self) { zeile in
                        let name = spalte * 10 + zeile
                        let versatz: CGFloat = spalte % 2 == 0 ? zellHoehe / 2 : 0
                        ZelleView(stapel: zellen[name]?.stapel ?? [],
                                  wuerfel: zellen[name]?.wuerfel ?? false,
                                  markierung: zellen[name]?.markierung,
                                  zaehlt: zaehlende.contains(name))
                            .frame(width: 2 * r, height: zellHoehe)
                            .offset(x: 1.5 * r * CGFloat(si),
                                    y: zellHoehe * CGFloat(zeile - 1) + versatz)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .aspectRatio((1.5 * CGFloat(spalten.count) + 0.5) / (sqrt(3) * CGFloat(maxZeilen)),
                     contentMode: .fit)
    }
}

extension TableauView {
    static let seiteA = [5, 4, 5, 4, 5]
    static let seiteB = [4, 3, 4, 3, 4, 3, 4]

    /// Seite B: Spalte 4 ist ganz Wasser und trennt das Brett in zwei
    /// Inseln — diese drei Zellen zählen. Das Wasser bei 21 trennt nichts.
    static var musterZellenB: [Int: Zelle] {
        [
            11: Zelle(stapel: [.laub]),
            12: Zelle(stapel: [.holz, .laub]),
            21: Zelle(stapel: [.wasser]),
            31: Zelle(stapel: [.stein]),
            32: Zelle(stapel: [.stein, .stein]),
            41: Zelle(stapel: [.wasser]),
            42: Zelle(stapel: [.wasser]),
            43: Zelle(stapel: [.wasser]),
            51: Zelle(stapel: [.feld]),
            52: Zelle(stapel: [.feld]),
            61: Zelle(stapel: [.stein]),
            62: Zelle(stapel: [.holz, .ziegel]),
            63: Zelle(stapel: [.laub]),
            71: Zelle(stapel: [.holz, .ziegel]),
        ]
    }

    /// Musterbrett: zeigt jeden Zellzustand und dazu jede Wertungsbedingung
    /// einmal erfüllt und einmal verfehlt.
    static var musterZellen: [Int: Zelle] {
        [
            // Fluss durch Spalte 1, mit einem Ast bei 23, der nicht zählt
            11: Zelle(stapel: [.wasser]),
            12: Zelle(stapel: [.wasser], wuerfel: true),
            13: Zelle(stapel: [.wasser]),
            14: Zelle(stapel: [.wasser]),
            15: Zelle(stapel: [.wasser]),
            23: Zelle(stapel: [.wasser]),

            // Berg3 ohne Bergnachbarn — 7 Punkte wert und zählt trotzdem 0
            21: Zelle(stapel: [.stein, .stein, .stein]),
            22: Zelle(stapel: [.laub]),                        // Baum 1
            24: Zelle(stapel: [.holz, .laub]),                 // Baum 2

            // zwei angrenzende Berge — beide zählen
            31: Zelle(stapel: [.stein]),
            32: Zelle(stapel: [.stein, .stein]),

            33: Zelle(stapel: [.stein, .ziegel]),              // Gebäude auf Stein
            34: Zelle(stapel: [.feld]),                        // einzelnes Feld, zählt 0
            35: Zelle(stapel: [.ziegel, .ziegel]),             // Gebäude am Rand, zu wenig Farben

            41: Zelle(stapel: [.holz]),                        // nacktes Holz
            42: Zelle(stapel: [.holz, .ziegel]),               // Gebäude auf Holz
            43: Zelle(stapel: [.holz, .holz, .laub], wuerfel: true),  // Baum 3

            51: Zelle(stapel: [.feld]),
            52: Zelle(stapel: [.feld]),                        // Feldgruppe zu zweit — zählt
            53: Zelle(stapel: [.wasser]),                      // kurzer Fluss, nicht der längste
            54: Zelle(stapel: [.ziegel]),                      // nackter Ziegel
            55: Zelle(stapel: [.stein]),                       // Berg ohne Nachbarn
        ]
    }
}

#Preview {
    VStack(spacing: 24) {
        TableauView(seite: .a, spalten: TableauView.seiteA, zellen: TableauView.musterZellen)
        TableauView(seite: .b, spalten: TableauView.seiteB, zellen: TableauView.musterZellenB)
    }
    .padding()
}
