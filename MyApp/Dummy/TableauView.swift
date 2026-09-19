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
                    Sechseck().fill(landschaft.tönung.opacity(0.22))
                }
                Sechseck().stroke(Color(.separator), lineWidth: 1)

                ForEach(Array(stapel.enumerated()), id: \.offset) { vonUnten, stein in
                    RoundedRectangle(cornerRadius: dicke * 0.4)
                        .fill(stein.farbe)
                        .overlay(RoundedRectangle(cornerRadius: dicke * 0.4)
                            .strokeBorder(.black.opacity(0.22), lineWidth: 0.8))
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

    /// Felder je Spalte: Seite A ist 5-4-5-4-5, Seite B ist 4-3-4-3-4-3-4.
    let spalten: [Int]
    /// Zellen unter ihrem Namen `<Spalte><Zeile>`.
    var zellen: [Int: Zelle] = [:]

    private var maxZeilen: Int { spalten.max() ?? 0 }

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
                                  markierung: zellen[name]?.markierung)
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

    /// Musterbrett: jeder mögliche Zellzustand genau einmal.
    static var musterZellen: [Int: Zelle] {
        [
            12: Zelle(stapel: [.wasser]),
            13: Zelle(stapel: [.feld]),
            14: Zelle(stapel: [.laub]),                       // Baum 1
            15: Zelle(stapel: [.holz, .laub]),                // Baum 2
            21: Zelle(stapel: [.holz, .holz, .laub], wuerfel: true),  // Baum 3
            22: Zelle(stapel: [.stein]),                      // Berg 1
            23: Zelle(stapel: [.stein, .stein]),              // Berg 2
            24: Zelle(stapel: [.stein, .stein, .stein]),      // Berg 3
            31: Zelle(stapel: [.holz, .ziegel]),              // Gebäude auf Holz
            32: Zelle(stapel: [.stein, .ziegel]),             // Gebäude auf Stein
            33: Zelle(stapel: [.ziegel, .ziegel]),            // Gebäude auf Ziegel
            34: Zelle(stapel: [.holz]),                       // nackter brauner Stein
            35: Zelle(stapel: [.ziegel]),                     // nackter roter Stein
            41: Zelle(stapel: [.wasser], wuerfel: true),
            42: Zelle(stapel: [.stein], wuerfel: true),       // einzelner Berg, Erdmännchen
            51: Zelle(markierung: "1"),
            52: Zelle(stapel: [.holz], markierung: "2·3"),
        ]
    }
}

#Preview {
    VStack(spacing: 24) {
        TableauView(spalten: TableauView.seiteA, zellen: TableauView.musterZellen)
        TableauView(spalten: TableauView.seiteB)
    }
    .padding()
}
