import Foundation

// The animal cards as the engine holds them. The source of truth is
// `Resources/animals.json`, maintained by hand; `docs/06-durchstich.md` says
// why it is the source rather than something generated.

/// What a card asks of one space of its pattern.
///
/// A card names **landscapes, not stones** — `04-architektur.md` places the
/// abstraction here on purpose, because that is the level the printed pattern
/// is defined on. `Berg1` wants exactly one grey stone, `Gebäude` a red one
/// on anything it may sit on.
///
/// The raw values are the words from `kartennotation.md` and are German,
/// because they are that document's vocabulary and the file is read by hand.
public enum PatternCell: String, Sendable, CaseIterable {
    case water     = "Wasser"
    case field     = "Feld"
    case tree1     = "Baum1"
    case tree2     = "Baum2"
    case tree3     = "Baum3"
    case mountain1 = "Berg1"
    case mountain2 = "Berg2"
    case mountain3 = "Berg3"
    case building  = "Gebäude"

    /// How many stones the finished space holds. A building is always two
    /// high and carries no height in its name; the rest say theirs.
    public var height: Int {
        switch self {
        case .water, .field, .tree1, .mountain1: 1
        case .tree2, .mountain2, .building:      2
        case .tree3, .mountain3:                 3
        }
    }
}

/// One of the thirty-two cards.
public struct AnimalCard: Sendable, Hashable, Identifiable {
    /// Our label, not the card's — the cards carry no identifier at all, see
    /// `kartennotation.md`. It has to be unique, and a test says so.
    public let name: String
    /// The pattern in **one** orientation, the one printed on the card. The
    /// other five are the engine's business.
    public let pattern: [Int: PatternCell]
    /// Which space of the pattern takes the animal cube.
    public let cube: Int
    /// Read upwards, as on the card. Their number is the number of cubes.
    public let points: [Int]

    public init(name: String, pattern: [Int: PatternCell], cube: Int, points: [Int]) {
        self.name = name
        self.pattern = pattern
        self.cube = cube
        self.points = points
    }

    /// The name is the identity: the cards carry none of their own, and a
    /// test holds the names unique.
    public var id: String { name }

    /// How many cubes the card carries. The same as the length of its
    /// ladder — a separate field would only be able to disagree.
    public var cubeSpaces: Int { points.count }

    /// What the card is worth with this many cubes laid.
    ///
    /// `regeln-basisspiel.md` scores the **highest visible number**, which
    /// is the one under the cube laid last. No cube means no points, and
    /// cubes left on the card cost nothing.
    public func score(cubes: Int) -> Int {
        cubes < 1 ? 0 : points[Swift.min(cubes, points.count) - 1]
    }

    /// The pattern as a form, free of where it sits and which way it faces.
    public var shape: HexShape { HexShape.canonical(of: pattern.keys) }

    /// How many stones the whole pattern costs when built from nothing.
    public var stoneCount: Int { pattern.values.reduce(0) { $0 + $1.height } }
}

// MARK: - Reading the resource

public enum AnimalCards {
    public enum LoadError: Error, CustomStringConvertible {
        case resourceMissing
        case unknownLandscape(card: String, cell: String, value: String)
        case badCell(card: String, cell: String)

        public var description: String {
            switch self {
            case .resourceMissing:
                "animals.json is not in the bundle"
            case let .unknownLandscape(card, cell, value):
                "\(card): space \(cell) asks for \(value), which is not a landscape"
            case let .badCell(card, cell):
                "\(card): \(cell) is not a space name"
            }
        }
    }

    private struct File: Decodable {
        let note: String
        let cards: [Card]
        struct Card: Decodable {
            let name: String
            let pattern: [String: String]
            let cube: String
            let points: [Int]
        }
    }

    /// Reads the resource. Throwing rather than trapping, so that the
    /// storey-one test can name what is wrong instead of taking the process
    /// down with it.
    public static func load() throws -> [AnimalCard] {
        guard let url = Bundle.module.url(forResource: "animals", withExtension: "json") else {
            throw LoadError.resourceMissing
        }
        let file = try JSONDecoder().decode(File.self, from: try Data(contentsOf: url))
        return try file.cards.map { card in
            var pattern: [Int: PatternCell] = [:]
            for (cell, landscape) in card.pattern {
                guard let number = Int(cell) else {
                    throw LoadError.badCell(card: card.name, cell: cell)
                }
                guard let value = PatternCell(rawValue: landscape) else {
                    throw LoadError.unknownLandscape(card: card.name, cell: cell, value: landscape)
                }
                pattern[number] = value
            }
            guard let cube = Int(card.cube) else {
                throw LoadError.badCell(card: card.name, cell: card.cube)
            }
            return AnimalCard(name: card.name, pattern: pattern,
                              cube: cube, points: card.points)
        }
        .sorted { $0.name < $1.name }
    }

    /// The deck, for everything that is not the test that checks it.
    public static let all: [AnimalCard] = {
        do { return try load() }
        catch { fatalError("animals.json cannot be read: \(error)") }
    }()
}
