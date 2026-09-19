import SwiftUI

// Attrappendaten für den Klickdummy aus Phase 5.
// Keine Engine, keine Regeln — nur so viel Zustand, wie der Eingabeweg braucht.

enum Stein: String, CaseIterable, Identifiable {
    case wasser = "W", stein = "S", holz = "H", laub = "L", feld = "F", ziegel = "Z"

    var id: String { rawValue }

    var farbe: Color {
        switch self {
        case .wasser: Color(red: 0.20, green: 0.47, blue: 0.75)
        case .stein:  Color(white: 0.55)
        case .holz:   Color(red: 0.45, green: 0.31, blue: 0.19)
        case .laub:   Color(red: 0.25, green: 0.56, blue: 0.29)
        case .feld:   Color(red: 0.93, green: 0.78, blue: 0.22)
        case .ziegel: Color(red: 0.78, green: 0.26, blue: 0.22)
        }
    }

    var name: String {
        switch self {
        case .wasser: "Wasser"
        case .stein:  "Stein"
        case .holz:   "Holz"
        case .laub:   "Laub"
        case .feld:   "Feld"
        case .ziegel: "Ziegel"
        }
    }
}

/// Was aus einem Stapel wird. Abgeleitet, nie gespeichert — dieselbe
/// Entscheidung wie in `04-architektur.md`: Wer die Landschaft ablegt, hat
/// die Einordnung schon vorgenommen und kann sie nicht mehr prüfen.
///
/// Im Dummy steht diese Ableitung noch hier; ihr Platz ist später das
/// Engine-Modul, wo sie genau einmal existiert.
enum Landschaft {
    case wasser, feld, baum, berg, gebaeude

    var tönung: Color {
        switch self {
        case .wasser:   Stein.wasser.farbe
        case .feld:     Stein.feld.farbe
        case .baum:     Stein.laub.farbe
        case .berg:     Stein.stein.farbe
        case .gebaeude: Stein.ziegel.farbe
        }
    }
}

extension Array where Element == Stein {
    /// `nil` heißt: keine Landschaft. Ein nackter brauner oder roter Stein
    /// bildet keine und zählt 0 Punkte.
    var landschaft: Landschaft? {
        guard let oben = last else { return nil }
        switch oben {
        case .wasser: return count == 1 ? .wasser : nil
        case .feld:   return count == 1 ? .feld : nil
        case .laub:   return count <= 3 && dropLast().allSatisfy { $0 == .holz } ? .baum : nil
        case .stein:  return count <= 3 && allSatisfy { $0 == .stein } ? .berg : nil
        case .ziegel: return count == 2 ? .gebaeude : nil
        case .holz:   return nil
        }
    }
}

struct Feld: Identifiable {
    let id = UUID()
    var steine: [Stein]

    /// Ein Feld ist ungeordnet. Zum Anzeigen und Vergleichen gilt eine
    /// feste Schreibweise, damit dasselbe Feld immer gleich aussieht.
    var notation: String {
        Stein.allCases.filter { steine.contains($0) }
            .flatMap { s in Array(repeating: s.rawValue, count: steine.filter { $0 == s }.count) }
            .joined()
    }
}

enum Attrappe {
    static let auslage: [Feld] = [
        Feld(steine: [.holz, .laub, .ziegel]),
        Feld(steine: [.wasser, .wasser, .stein]),
        Feld(steine: [.feld, .stein, .stein]),
        Feld(steine: [.laub, .holz, .wasser]),
        Feld(steine: [.ziegel, .feld, .laub]),
    ]

    static let offeneKarten = ["Pinguin", "Biene", "Lachs", "Wolf", "Rabe"]

    /// Zwei Menschen und Harmony — der Regelfall aus Phase 2.
    static let reihenfolge = ["Anke", "Bernd", "Harmony"]

    static let alleKarten = [
        "Eisvogel",
        "Hase",
        "Eichhörnchen",
        "Erdmännchen",
        "Biene",
        "Pinguin",
        "Affe",
        "Lachs",
        "Frosch",
        "Panther",
        "Papagei",
        "Schwein",
        "Koala",
        "Pfau",
        "Lama",
        "Wüstenfuchs",
        "Eisfuchs",
        "Waschbär",
        "Echse",
        "Igel",
        "Maus",
        "Rabe",
        "Fledermaus",
        "Krokodil",
        "Rochen",
        "Adler",
        "Bär",
        "Ente",
        "Otter",
        "Flamingo",
        "Wolf",
        "Marienkäfer"
    ]

}
