import Foundation

/// Welche Zellen gerade Punkte einbringen.
///
/// **Vorläufig.** Das ist Regelrechnung und gehört ins Engine-Modul, nicht
/// zur Oberfläche — `04-architektur.md` sieht sie dort genau einmal vor,
/// geprüft nach `pruefverfahren.md`, Stockwerk 1. Sie steht hier, weil der
/// Dummy ohne sie nicht zeigen kann, was er zeigen soll. Beim Durchstich
/// wandert sie und wird hier gelöscht, nicht kopiert.
enum Planseite { case a, b }

struct Brettwertung {
    let seite: Planseite
    let spalten: [Int]
    let stapel: [Int: [Stein]]

    /// Alle Felder des Spielplans, auch die leeren — die Inselwertung auf
    /// Seite B rechnet sie mit.
    var alleZellen: [Int] {
        spalten.enumerated().flatMap { si, anzahl in
            (1...anzahl).map { (si + 1) * 10 + $0 }
        }
    }

    /// Nachbarn einer Zelle `<Spalte><Zeile>`. Gerade Spalten (1-basiert
    /// gezählt) sitzen eine halbe Zelle tiefer, siehe `regeln-basisspiel.md`.
    func nachbarn(_ name: Int) -> [Int] {
        let c = name / 10 - 1, r = name % 10 - 1        // 0-basiert
        let versatz = c % 2 == 0 ? -1 : 1
        var kandidaten = [(c, r - 1), (c, r + 1)]
        for dc in [-1, 1] {
            kandidaten.append((c + dc, r))
            kandidaten.append((c + dc, r + versatz))
        }
        return kandidaten.compactMap { cc, rr in
            guard cc >= 0, cc < spalten.count, rr >= 0, rr < spalten[cc] else { return nil }
            return (cc + 1) * 10 + (rr + 1)
        }
    }

    private func landschaft(_ name: Int) -> Landschaft? {
        (stapel[name] ?? []).landschaft
    }

    /// Zusammenhangsgebiete innerhalb einer Menge von Zellen.
    private func gebiete(aus menge: Set<Int>) -> [[Int]] {
        var offen = menge
        var alle: [[Int]] = []
        while let start = offen.first {
            var gebiet: [Int] = []
            var rand = [start]
            offen.remove(start)
            while let z = rand.popLast() {
                gebiet.append(z)
                for n in nachbarn(z) where offen.contains(n) {
                    offen.remove(n); rand.append(n)
                }
            }
            alle.append(gebiet)
        }
        return alle
    }

    /// Längster unter allen kürzesten Wegen im Gebiet, als Zellenfolge.
    /// „Beide Enden mitgezählt" — die Länge ist die Zahl der Zellen.
    private func laengsterWeg(_ gebiet: [Int]) -> [Int] {
        let menge = Set(gebiet)
        var bester: [Int] = []
        for start in gebiet {
            var vorgaenger: [Int: Int] = [:]
            var gesehen: Set<Int> = [start]
            var schlange = [start]
            var letzter = start
            while !schlange.isEmpty {
                var naechste: [Int] = []
                for z in schlange {
                    letzter = z
                    for n in nachbarn(z) where menge.contains(n) && !gesehen.contains(n) {
                        gesehen.insert(n); vorgaenger[n] = z; naechste.append(n)
                    }
                }
                schlange = naechste
            }
            var weg = [letzter]
            while let v = vorgaenger[weg[0]] { weg.insert(v, at: 0) }
            if weg.count > bester.count { bester = weg }
        }
        return bester
    }

    /// Alle Zellen, die derzeit Punkte einbringen.
    func zaehlende() -> Set<Int> {
        var ergebnis: Set<Int> = []

        // Bäume: keine Bedingung, sie zählen immer.
        for (name, _) in stapel where landschaft(name) == .baum { ergebnis.insert(name) }

        // Berge: nur mit mindestens einem angrenzenden Berg.
        for (name, _) in stapel where landschaft(name) == .berg {
            if nachbarn(name).contains(where: { landschaft($0) == .berg }) {
                ergebnis.insert(name)
            }
        }

        // Felder: eine Gruppe aus mindestens 2 angrenzenden gelben Steinen.
        for gruppe in gebiete(aus: Set(stapel.keys.filter { landschaft($0) == .feld }))
            where gruppe.count >= 2 {
            ergebnis.formUnion(gruppe)
        }

        let wasser = Set(alleZellen.filter { landschaft($0) == .wasser })

        switch seite {
        case .a:
            // Fluss: nur der längste, und darin nur die Zellen auf der
            // längsten Kette — ein Ast daneben zählt nicht mit.
            let wege = gebiete(aus: wasser).map(laengsterWeg)
            if let laengster = wege.max(by: { $0.count < $1.count }), laengster.count >= 2 {
                ergebnis.formUnion(laengster)
            }

        case .b:
            // Inseln: Zusammenhangsgebiete aller nicht-blauen Felder,
            // leere eingeschlossen; jede zählt 5. Das Wasser selbst zählt
            // nicht — es trennt. Satt ist deshalb eine Wasserzelle, die an
            // **zwei verschiedene** Inseln grenzt und damit wirklich auf
            // einer Trennlinie liegt. Wasser in einer Bucht tut nichts.
            let inseln = gebiete(aus: Set(alleZellen).subtracting(wasser))
            var inselVon: [Int: Int] = [:]
            for (i, insel) in inseln.enumerated() {
                for z in insel { inselVon[z] = i }
            }
            for z in wasser {
                let beruehrt = Set(nachbarn(z).compactMap { inselVon[$0] })
                if beruehrt.count >= 2 { ergebnis.insert(z) }
            }
        }

        // Gebäude: von mindestens 3 verschiedenfarbigen Steinen umgeben,
        // gezählt über den obersten Stein jedes Nachbarfeldes. Leere
        // Nachbarfelder zählen nicht mit.
        for (name, _) in stapel where landschaft(name) == .gebaeude {
            let farben = Set(nachbarn(name).compactMap { stapel[$0]?.last })
            if farben.count >= 3 { ergebnis.insert(name) }
        }

        return ergebnis
    }
}
