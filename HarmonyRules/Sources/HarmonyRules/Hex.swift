import Foundation

// The geometry, in one place. `04-architektur.md` asks for cube coordinates
// and gives the reason: neighbourhood becomes an addition and a rotation
// becomes a rotation of the three axes. Both boards and the card template in
// `kartennotation.md` share the same outward naming, so the same conversion
// serves all three.

/// A place in cube coordinates. The three axes always sum to zero; that is
/// what makes a rotation a permutation of them rather than a case analysis.
public struct Hex: Hashable, Sendable {
    public let x: Int, y: Int, z: Int

    public init(x: Int, y: Int, z: Int) {
        precondition(x + y + z == 0, "cube coordinates must sum to zero")
        self.x = x; self.y = y; self.z = z
    }

    /// From the outward name `<column><row>`, both counted from one.
    ///
    /// The spaces are flat-top hexagons in columns, and the **even** columns
    /// sit half a cell lower — `regeln-basisspiel.md` for the boards,
    /// `kartennotation.md` for the card template, in the same words. Counted
    /// from zero that means the odd columns are the lowered ones, and the
    /// row index has to be corrected by half a column index to become a
    /// straight axis.
    public init(cell: Int) {
        let column = cell / 10 - 1, row = cell % 10 - 1
        let z = row - (column - (column & 1)) / 2
        self.init(x: column, y: -column - z, z: z)
    }

    /// Back to `<column><row>`. Only meaningful for places that lie on a
    /// board; the caller checks that.
    public var cell: Int {
        let row = z + (x - (x & 1)) / 2
        return (x + 1) * 10 + (row + 1)
    }

    /// The six steps to a touching space.
    public static let directions: [Hex] = [
        Hex(x:  1, y: -1, z:  0), Hex(x:  1, y:  0, z: -1),
        Hex(x:  0, y:  1, z: -1), Hex(x: -1, y:  1, z:  0),
        Hex(x: -1, y:  0, z:  1), Hex(x:  0, y: -1, z:  1),
    ]

    public static func + (a: Hex, b: Hex) -> Hex {
        Hex(x: a.x + b.x, y: a.y + b.y, z: a.z + b.z)
    }

    public static func - (a: Hex, b: Hex) -> Hex {
        Hex(x: a.x - b.x, y: a.y - b.y, z: a.z - b.z)
    }

    /// Every touching place, on a board or not.
    public var neighbours: [Hex] { Hex.directions.map { self + $0 } }

    /// One sixth of a full turn about the origin. Six of these are the
    /// identity, which is the whole reason the rules can say "in any
    /// orientation" and the engine can take them at their word.
    public var rotated: Hex { Hex(x: -z, y: -x, z: -y) }
}

// MARK: - Shapes

/// A pattern as a **form**, free of where it sits. `kartennotation.md`:
/// "ein Muster ist eine Form, kein Ort".
public struct HexShape: Hashable, Comparable, Sendable {
    /// Normalised and sorted, so that equal forms are equal values.
    public let offsets: [Hex]

    /// Shifted so that the smallest x and the smallest z are both zero. A
    /// shift is itself a cube vector, so this stays inside the coordinate
    /// system rather than leaving it.
    init(normalising places: some Sequence<Hex>) {
        let all = Array(places)
        guard let minX = all.map(\.x).min(), let minZ = all.map(\.z).min() else {
            offsets = []; return
        }
        let shift = Hex(x: -minX, y: minX + minZ, z: -minZ)
        offsets = all.map { $0 + shift }.sorted { ($0.x, $0.z) < ($1.x, $1.z) }
    }

    public static func < (a: HexShape, b: HexShape) -> Bool {
        for (p, q) in zip(a.offsets, b.offsets) where p != q {
            return (p.x, p.z) < (q.x, q.z)
        }
        return a.offsets.count < b.offsets.count
    }

    /// The same form turned by a sixth.
    public var rotated: HexShape { HexShape(normalising: offsets.map(\.rotated)) }

    /// All six orientations, from this one.
    public var orientations: [HexShape] {
        var all = [self], current = self
        for _ in 1..<6 { current = current.rotated; all.append(current) }
        return all
    }

    /// One representative for all six orientations, so that two patterns
    /// which are the same up to turning compare equal. Which of the six is
    /// picked does not matter as long as the choice is the same every time.
    public var canonical: HexShape { orientations.min()! }

    /// The canonical form of a set of named cells.
    public static func canonical(of cells: some Sequence<Int>) -> HexShape {
        HexShape(normalising: cells.map { Hex(cell: $0) }).canonical
    }
}

// MARK: - Board

/// Which spaces exist on one side of a personal board, and which of them
/// touch. Nothing about stones or scoring — that is `BoardScoring`, which
/// asks its questions here rather than answering them itself.
public struct Board: Sendable {
    /// How many spaces each column holds, from the left.
    public let columns: [Int]

    public init(columns: [Int]) { self.columns = columns }

    /// Every space, empty ones included — the island scoring on side B
    /// counts them.
    public var cells: [Int] {
        columns.enumerated().flatMap { index, count in
            (1...count).map { (index + 1) * 10 + $0 }
        }
    }

    public func contains(_ cell: Int) -> Bool {
        let column = cell / 10 - 1, row = cell % 10 - 1
        return column >= 0 && column < columns.count && row >= 0 && row < columns[column]
    }

    /// The touching spaces that are on this board.
    public func neighbours(_ cell: Int) -> [Int] {
        Hex(cell: cell).neighbours
            .map(\.cell)
            .filter { contains($0) }
    }
}

extension BoardSide {
    public var board: Board { Board(columns: columns) }
}
