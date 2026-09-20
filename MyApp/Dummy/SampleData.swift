import SwiftUI
import Foundation
import HarmonyRules

// Dummy data for the Phase 5 click-through prototype.
// No engine and no rule checking — only as much state as the input path needs.
// Identifiers and comments are English, user-facing text stays German.

/// The rules live in the `HarmonyRules` package — `04-architektur.md`
/// wants the engine as its own module, and `pruefverfahren.md` tests it
/// there without a host app. What stays here is **presentation**: a colour
/// is how a stone looks, not what it is worth.
extension Stone {
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
}

extension Landscape {
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


/// One of the five spaces on the shared board. It carries three stones and
/// has no identity of its own: the spaces bear no marking and sit in a
/// circle, so a space is named by what lies on it.
struct DisplayField: Identifiable {
    let id = UUID()
    var stones: [Stone]

    /// A space is unordered. One fixed order applies to both writing it
    /// down and showing it, so the same space always looks the same —
    /// which is what makes two equal spaces recognisable at a glance.
    var ordered: [Stone] {
        Stone.allCases
            .flatMap { s in Array(repeating: s, count: stones.filter { $0 == s }.count) }
    }

    var notation: String { ordered.map(\.rawValue).joined() }
}

enum Sample {
    static let display: [DisplayField] = [
        DisplayField(stones: [.wood, .leaves, .brick]),
        DisplayField(stones: [.water, .water, .stone]),
        DisplayField(stones: [.field, .stone, .stone]),
        DisplayField(stones: [.leaves, .wood, .water]),
        DisplayField(stones: [.brick, .field, .leaves]),
    ]

    /// The launch argument seeds the five longest names, so the layout can
    /// be looked at in its worst case — a hook like `-harmonyTurn`.
    static var openCards: [String] {
        ProcessInfo.processInfo.arguments.contains("-longCards")
        ? ["Eichhörnchen", "Erdmännchen", "Fledermaus", "Marienkäfer", "Wüstenfuchs"]
        : ["Pinguin", "Biene", "Lachs", "Wolf", "Rabe"]
    }

    /// Alphabetical, the way the open cards are always shown: the display
    /// is an unordered set, so a fixed order keeps it readable.
    static func sorted(_ cards: [String]) -> [String] {
        cards.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

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

    /// Harmony's cards at the end of the sample game. Four of them, which
    /// is the limit the rules put on unfinished cards.
    ///
    /// The ladders are copied from `tierkarten.md`; Phase 6 reads them from
    /// there instead. The Biene is taken but has no cube on it — a card
    /// left unfinished scores nothing and costs nothing, and the screen
    /// should show that case.
    /// A real card by name. The ladders used to be copied into the sample
    /// data; since Phase 6 they come out of `animals.json`, which is the
    /// only place they are maintained. An unknown name is a mistake in the
    /// sample and should be loud.
    static func card(_ name: String) -> AnimalCard {
        guard let found = AnimalCards.all.first(where: { $0.name == name }) else {
            fatalError("Die Attrappe nennt eine Karte, die es nicht gibt: \(name)")
        }
        return found
    }

    static let harmonyCards = [
        card("Fledermaus"), card("Lachs"), card("Koala"), card("Biene"),
    ]

    /// Harmony's board at the end of a game, on side A. Built so that every
    /// scoring rule appears **once met and once missed** — the same idea as
    /// `BoardView.sampleCellsA`, because a final score whose every line
    /// scores proves only half of the screen.
    ///
    /// Two spaces stay free, 3.4 and 4.4, which is the second end trigger:
    /// two or fewer free spaces at the end of a turn.
    static let harmonyBoardFinal: [Int: [Stone]] = [
        // A river of four down column one, with 2.2 branching off it
        11: [.water], 12: [.water], 13: [.water], 14: [.water], 22: [.water],
        // A second river of two, which does not count beside the longer one
        41: [.water], 52: [.water],
        // Trees of every height
        15: [.wood, .wood, .leaves], 21: [.wood, .leaves], 31: [.leaves],
        43: [.wood, .wood, .leaves],
        // Two mountains side by side, two more, and one standing alone
        32: [.stone, .stone], 33: [.stone],
        53: [.stone], 54: [.stone],
        51: [.stone, .stone, .stone],
        // A pair of fields, and a single yellow stone that is no group
        23: [.field], 24: [.field], 55: [.field],
        // One building with three colours around it, one at the edge with one
        42: [.brick, .brick], 35: [.brick, .brick],
    ]

    /// Where the cubes ended up, and which card each came from. Every one
    /// sits on a space where its card's pattern really is on the board:
    /// Fledermaus is a tree of three beside a mountain of one (4.3 and 5.3),
    /// Lachs a mountain of three beside water (5.1 and 5.2), Koala a tree
    /// of one beside a tree of two (3.1 and 2.1).
    static let harmonyCubesFinal: [Int: String] = [
        53: "Fledermaus",
        52: "Lachs",
        21: "Koala",
    ]

    /// The same thing on side B, where water is not a river but a divider:
    /// islands are the connected regions of everything **not** blue, empty
    /// spaces included, and each one counts five.
    ///
    /// Water fills columns two and four completely and so cuts the board
    /// into three islands of 4, 4 and 10 spaces. The single water space at
    /// 6.3 is a bay: it borders one island only and therefore separates
    /// nothing — the case that has to be visible beside the one that works.
    ///
    /// Two spaces stay free, 6.1 and 7.2, and they belong to their island.
    static let harmonyBoardFinalB: [Int: [Stone]] = [
        // Island one, the whole of column 1
        11: [.wood, .wood, .leaves], 12: [.wood, .leaves], 13: [.leaves],
        14: [.field],
        // The first cut
        21: [.water], 22: [.water], 23: [.water],
        // Island two, the whole of column 3
        31: [.stone, .stone, .stone], 32: [.stone],
        33: [.brick, .brick], 34: [.leaves],
        // The second cut
        41: [.water], 42: [.water], 43: [.water],
        // Island three, columns 5 to 7
        51: [.field], 52: [.field],
        53: [.stone, .stone], 54: [.stone],
        62: [.brick, .brick],
        63: [.water],                      // the bay, separating nothing
        71: [.wood, .wood, .leaves],
        73: [.brick, .brick], 74: [.stone],
    ]

    /// Cubes on side B. The mountain of three at 3.1 borders water on both
    /// sides, so the Lachs pattern is there twice; the building at 3.3
    /// borders four water spaces, of which two carry an Ente cube.
    static let harmonyCubesFinalB: [Int: String] = [
        21: "Lachs", 41: "Lachs",
        12: "Koala",
        42: "Ente", 43: "Ente",
    ]

    static let harmonyCardsB = [
        card("Lachs"), card("Koala"), card("Ente"), card("Biene"),
    ]

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
    /// Which display space is emptied. The stones alone would say which
    /// **kind** of space it was, but two spaces can hold the same three
    /// stones, and the one that gets refilled has to be the one that was
    /// taken.
    var space: Int = 0
    let placements: [Placement]
    let cubes: [CubePlacement]
    /// The card taken with the move, if one was. Harmony decides this; it
    /// belongs to the suggestion.
    var cardTaken: String? = nil
    let rationale: MoveRationale

    // What the table tells her afterwards. Not part of the suggestion —
    // she cannot know what comes out of the bag, and inventing it would be
    // exactly the kind of made-up data this app exists to avoid.

    /// The three stones drawn for the emptied space. Empty once the bag is.
    var refill: [Stone] = []
    /// The card that moved up, if one was taken.
    var cardDrawn: String? = nil

    var takenField: String {
        DisplayField(stones: placements.map(\.stone)).notation
    }

    /// Everything still to be entered before the turn can be recorded.
    func isComplete(bagEmpty: Bool) -> Bool {
        (bagEmpty || refill.count == 3) && (cardTaken == nil || cardDrawn != nil)
    }

    var notation: String {
        (placements.map { "\($0.stone.rawValue)\($0.cell)" }
         + cubes.map { "T\($0.cell)/\($0.card)" }
         + (cardTaken.map { ["+\($0)"] } ?? [])
         + (refill.isEmpty ? [] : [">" + refill.map(\.rawValue).joined()])
         + (cardDrawn.map { [">\($0)"] } ?? [])).joined(separator: " ")
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


