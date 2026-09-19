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

    static let amZug = "Anke"
}
