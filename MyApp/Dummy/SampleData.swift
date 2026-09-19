import SwiftUI

// Dummy data for the Phase 5 click-through prototype.
// No engine and no rule checking — only as much state as the input path needs.
// Identifiers and comments are English, user-facing text stays German.

/// A stone is a colour, nothing more. The raw values are the shorthand
/// letters from `pruefverfahren.md`; they are mnemonics for the German
/// material names and stay as they are, because the recorded fixtures and
/// transcripts use them.
enum Stone: String, CaseIterable, Identifiable {
    case water = "W", stone = "S", wood = "H", leaves = "L", field = "F", brick = "Z"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .water:  Color(red: 0.20, green: 0.47, blue: 0.75)
        case .stone:  Color(white: 0.55)
        case .wood:   Color(red: 0.45, green: 0.31, blue: 0.19)
        case .leaves: Color(red: 0.25, green: 0.56, blue: 0.29)
        case .field:  Color(red: 0.93, green: 0.78, blue: 0.22)
        case .brick:  Color(red: 0.78, green: 0.26, blue: 0.22)
        }
    }

    /// Shown on screen, therefore German.
    var name: String {
        switch self {
        case .water:  "Wasser"
        case .stone:  "Stein"
        case .wood:   "Holz"
        case .leaves: "Laub"
        case .field:  "Feld"
        case .brick:  "Ziegel"
        }
    }
}

/// What a stack amounts to. Derived, never stored — the same decision as in
/// `04-architektur.md`: storing the classification would put it beyond
/// checking.
///
/// In the dummy this derivation still lives here; its place is the engine
/// module, where it will exist exactly once.
enum Landscape {
    case water, field, tree, mountain, building

    var tint: Color {
        switch self {
        case .water:    Stone.water.color
        case .field:    Stone.field.color
        case .tree:     Stone.leaves.color
        case .mountain: Stone.stone.color
        case .building: Stone.brick.color
        }
    }
}

extension Array where Element == Stone {
    /// `nil` means no landscape. A bare brown or red stone forms none and
    /// scores zero.
    var landscape: Landscape? {
        guard let top = last else { return nil }
        switch top {
        case .water:  return count == 1 ? .water : nil
        case .field:  return count == 1 ? .field : nil
        case .leaves: return count <= 3 && dropLast().allSatisfy { $0 == .wood } ? .tree : nil
        case .stone:  return count <= 3 && allSatisfy { $0 == .stone } ? .mountain : nil
        case .brick:  return count == 2 ? .building : nil
        case .wood:   return nil
        }
    }
}

/// One of the five spaces on the shared board. It carries three stones and
/// has no identity of its own: the spaces bear no marking and sit in a
/// circle, so a space is named by what lies on it.
struct DisplayField: Identifiable {
    let id = UUID()
    var stones: [Stone]

    /// A space is unordered. For writing it down one spelling applies, so
    /// the same space always looks the same and diffs stay stable.
    var notation: String {
        Stone.allCases
            .flatMap { s in Array(repeating: s.rawValue, count: stones.filter { $0 == s }.count) }
            .joined()
    }
}

enum Sample {
    static let display: [DisplayField] = [
        DisplayField(stones: [.wood, .leaves, .brick]),
        DisplayField(stones: [.water, .water, .stone]),
        DisplayField(stones: [.field, .stone, .stone]),
        DisplayField(stones: [.leaves, .wood, .water]),
        DisplayField(stones: [.brick, .field, .leaves]),
    ]

    static let openCards = ["Pinguin", "Biene", "Lachs", "Wolf", "Rabe"]

    static let allCards = [
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

    /// Two humans and Harmony — the leading case from Phase 2.
    static let turnOrder = ["Anke", "Bernd", "Harmony"]
}
