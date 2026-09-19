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

    /// Jede Zelle hat drei Reihen, so hoch wie ein Stapel werden darf, und
    /// wird **von unten** gefüllt. Ein Berg der Höhe 1 belegt damit ein
    /// Drittel, einer der Höhe 3 die ganze Zelle — vorher war es umgekehrt
    /// herum missverständlich: Eine einzelne volle Fläche wirkte massiver
    /// als drei dünne Streifen. Nebenbei sitzt die Baumkrone nun dort, wo
    /// sie am Tisch auch sitzt: oben.
    private static let reihen = 3

    var body: some View {
        GeometryReader { geo in
            let hoehe = geo.size.height
            let fuge: CGFloat = 2
            let reiheHoehe = (hoehe - fuge * CGFloat(Self.reihen - 1)) / CGFloat(Self.reihen)
            let obersteVonOben = Self.reihen - max(stapel.count, 1)

            ZStack {
                Sechseck().fill(Color(.tertiarySystemFill))

                VStack(spacing: fuge) {
                    ForEach(0..<Self.reihen, id: \.self) { reiheVonOben in
                        let vonUnten = Self.reihen - 1 - reiheVonOben
                        Rectangle()
                            .fill(vonUnten < stapel.count ? stapel[vonUnten].farbe : .clear)
                            .frame(height: reiheHoehe)
                    }
                }
                .clipShape(Sechseck())

                Sechseck().stroke(Color(.separator), lineWidth: 1)

                if wuerfel {
                    // Die echten Tierwürfel sind durchscheinend orange.
                    // Er liegt auf dem obersten Stein, nicht in der Mitte.
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(red: 0.95, green: 0.55, blue: 0.10).opacity(0.82))
                        .overlay(RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(.white.opacity(0.9), lineWidth: 1.5))
                        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                        .frame(width: reiheHoehe * 0.78, height: reiheHoehe * 0.78)
                        .offset(y: (CGFloat(obersteVonOben) + 0.5) * (reiheHoehe + fuge) - hoehe / 2)
                }

                if let markierung {
                    Sechseck().stroke(Color.accentColor, lineWidth: 3)
                    Text(markierung)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor))
                        .offset(y: -hoehe * 0.3)
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
