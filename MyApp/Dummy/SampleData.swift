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

    /// Harmony's board before her turn. Mid-game: a river, a pair of
    /// fields, two adjacent mountains, and two wood tiles at 43 waiting
    /// for a green one.
    static let harmonyBoard: [Int: [Stone]] = [
        11: [.water], 12: [.water], 13: [.water],
        22: [.field], 23: [.field],
        31: [.stone, .stone, .stone], 32: [.stone, .stone, .stone],
        43: [.wood, .wood],
        51: [.leaves],
    ]

    /// The move Harmony proposes. Taking the space with leaves and two
    /// stones completes a tree of height three at 43 and a mountain of
    /// height one at 44, which together match the Fledermaus pattern, so
    /// its cube goes on the mountain. The third stone at 54 gives that
    /// mountain a neighbour, which is what makes either of them score.
    static let harmonyMove = HarmonyMove(
        placements: [
            Placement(stone: .leaves, cell: 43),
            Placement(stone: .stone, cell: 44),
            Placement(stone: .stone, cell: 54),
        ],
        cubes: [CubePlacement(card: "Fledermaus", cell: 44)],
        rationale: MoveRationale(
            immediate: 12,
            value: 12,
            terms: [
                ScoreTerm(name: "Baum der Höhe 3 auf 4.3", points: 7),
                ScoreTerm(name: "Zwei benachbarte Berge, 4.4 und 5.4", points: 2),
                ScoreTerm(name: "Tierwürfel Fledermaus, erster von vier", points: 3),
            ],
            probabilityNote: nil,
            runnerUp: "Laub auf 4.3, beide Steine auf 5.3 und 5.4",
            runnerUpImmediate: 9,
            runnerUpValue: 9,
            gapExplanation: "Der Abstand ist genau der Tierwürfel. Ohne einen "
                + "Berg neben dem Baum ist das Muster der Fledermaus nicht "
                + "vollständig, und der Würfel bliebe auf der Karte liegen."
        )
    )

    /// The second example scores **nothing** when it is played. Two wood
    /// tiles form no landscape and a lone mountain has no neighbour, so the
    /// move is worth zero points and is still the better one: it leaves a
    /// tree of height three and the Fledermaus pattern one green tile away.
    static let harmonyMoveSetup = HarmonyMove(
        placements: [
            Placement(stone: .wood, cell: 53),
            Placement(stone: .wood, cell: 53),
            Placement(stone: .stone, cell: 54),
        ],
        cubes: [],
        rationale: MoveRationale(
            immediate: 0,
            value: 8,
            terms: [
                ScoreTerm(name: "Zwei Holz auf 5.3 — noch keine Landschaft",
                          points: 0),
                ScoreTerm(name: "Berg der Höhe 1 auf 5.4 — noch ohne Bergnachbarn",
                          points: 0),
                ScoreTerm(name: "Mit einem Laub auf 5.3: Baum der Höhe 3 (7) und "
                          + "das Muster der Fledermaus (3)",
                          points: 10, prospect: true, probability: 0.8),
            ],
            probabilityNote: "Laub ist bis zum nächsten eigenen Zug mit rund "
                + "80 % erreichbar: Es liegt dreimal offen in der Auslage, und "
                + "von den 19 grünen Steinen sind noch 14 im Beutel.",
            runnerUp: "Beide Holz auf 3.3 und 4.1, Stein auf 5.4",
            runnerUpImmediate: 1,
            runnerUpValue: 4,
            gapExplanation: "Die Alternative bringt sofort einen Punkt mehr und "
                + "steht trotzdem schlechter: Sie lässt zwei Holzplättchen "
                + "verstreut zurück, aus denen kein Baum mehr wird. Punkte "
                + "jetzt und Wert der Stellung sind nicht dasselbe."
        )
    )
}

/// One named contribution to the score. Named, because the reason shows the
/// largest of them and a nameless summand cannot be shown.
struct ScoreTerm {
    let name: String
    let points: Int
    /// Not points but prospect: what the move sets up for a later turn.
    /// Kept apart because a prospect is not a score, and mixing the two
    /// would make the reason claim more than it can.
    var prospect = false
    /// How likely the prospect is met in time. The figure comes from the
    /// bag and the deck, both of which Harmony knows exactly, and it is the
    /// chance layer of the expectimax search seen from the other side. A
    /// prospect without its probability would be an arbitrary number.
    var probability: Double? = nil

    /// Expected value: what the prospect is worth once weighted.
    var expected: Int {
        guard let probability else { return points }
        return Int((Double(points) * probability).rounded())
    }
}

/// Why this move and not the next best one. Phase 2 asks both questions:
/// what does the move bring, and what would the alternative have been — a
/// number without a comparison answers neither.
struct MoveRationale: Identifiable {
    let id = UUID()
    /// What the move scores the moment it is played.
    let immediate: Int
    /// What the resulting position is worth, prospects included. The
    /// comparison runs on this number, not on the points — which is the
    /// only way a move worth nothing today can be the best one.
    let value: Int
    let terms: [ScoreTerm]
    /// Where the probabilities come from. Named, so a weighted number does
    /// not look like it was picked out of the air.
    var probabilityNote: String? = nil
    let runnerUp: String
    let runnerUpImmediate: Int
    let runnerUpValue: Int
    let gapExplanation: String

    var gap: Int { value - runnerUpValue }
    var isProspective: Bool { value != immediate }
}

struct Placement {
    let stone: Stone
    let cell: Int
}

struct CubePlacement {
    let card: String
    let cell: Int
}

/// A move Harmony proposes, as an ordered sequence of actions. Cubes are
/// written last wherever that yields the same result, so the first three
/// actions are the stones and the space they came from can be read off.
struct HarmonyMove {
    let placements: [Placement]
    let cubes: [CubePlacement]
    let rationale: MoveRationale

    /// The space taken is not stored: all three stones taken are placed,
    /// so the placements already say which space it was.
    var takenField: String {
        DisplayField(stones: placements.map(\.stone)).notation
    }

    var notation: String {
        (placements.map { "\($0.stone.rawValue)\($0.cell)" }
         + cubes.map { "T\($0.cell)/\($0.card)" }).joined(separator: " ")
    }

    /// The board after the move, which is what the operator has to produce.
    func applied(to board: [Int: [Stone]]) -> [Int: [Stone]] {
        var result = board
        for p in placements { result[p.cell, default: []].append(p.stone) }
        return result
    }

    /// Cell name to the number it carries in the instruction. A cell taking
    /// two stones carries both, as in "2·3".
    var markers: [Int: String] {
        var byCell: [Int: [Int]] = [:]
        for (index, p) in placements.enumerated() { byCell[p.cell, default: []].append(index + 1) }
        return byCell.mapValues { $0.map(String.init).joined(separator: "·") }
    }
}
