import Foundation

// The rule core, lifted out of the Phase 5 dummy. Identifiers and comments
// are English; there is no user-facing text in here at all.

/// A stone is a colour, nothing more. The raw values are the shorthand
/// letters from `pruefverfahren.md`; they are mnemonics for the German
/// material names and stay as they are, because the recorded fixtures and
/// transcripts use them.
public enum Stone: String, CaseIterable, Identifiable, Sendable {
    case water = "W", stone = "S", wood = "H", leaves = "L", field = "F", brick = "Z"

    public var id: String { rawValue }


    /// Shown on screen, therefore German.
    public var name: String {
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
public enum Landscape: Sendable, Hashable, CaseIterable {
    case water, field, tree, mountain, building
}

extension Array where Element == Stone {
    /// `nil` means no landscape. A bare brown or red stone forms none and
    /// scores zero.
    public var landscape: Landscape? {
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

    /// Is this a stack the game can produce at all?
    ///
    /// The complete list from `regeln-basisspiel.md` — fourteen stacks,
    /// written bottom first. It is spelled out rather than derived because
    /// the rules spell it out; a reconstruction from "a stone may go onto
    /// one or two others" would have to re-derive that nothing stacks on
    /// blue or yellow and that three browns do not exist.
    ///
    /// This is about what **can lie on the table**, not about what scores.
    /// `HH` earns nothing and is legal; `SHW` is not a stack anybody could
    /// have built.
    public static let legal: Set<[Stone]> = [
        // Height 1 — every single stone, red and brown included
        [.water], [.field], [.stone], [.wood], [.brick], [.leaves],
        // Height 2
        [.stone, .stone], [.brick, .brick], [.wood, .brick],
        [.stone, .brick], [.wood, .wood], [.wood, .leaves],
        // Height 3
        [.stone, .stone, .stone], [.wood, .wood, .leaves],
    ]

    public var isLegal: Bool { isEmpty || Self.legal.contains(self) }

    /// Which stones may go on top next.
    ///
    /// The set above is **prefix-closed** — every beginning of a legal
    /// stack is itself a legal stack — so building from the bottom up
    /// never has to pass through something inexpressible, and asking
    /// whether the result is legal is the whole test.
    public var placeable: [Stone] {
        Stone.allCases.filter { Self.legal.contains(self + [$0]) }
    }
}

/// How many stones of each colour a board holds.
///
/// The counting side of the invariant in `pruefverfahren.md`: across bag,
/// display and all boards there must always be 23/23/21/19/19/15 stones
/// per colour. Harmony's board holds exactly what she has taken — three
/// stones per turn, all three placed — so any change to it that alters
/// these counts has lost a stone or invented one.
public func stoneCounts(_ board: [Int: [Stone]]) -> [Stone: Int] {
    var counts: [Stone: Int] = [:]
    for stack in board.values {
        for stone in stack { counts[stone, default: 0] += 1 }
    }
    return counts
}

/// What a correction would change about those counts, colour by colour.
/// Empty means the stones only moved, which is the only thing a
/// correction may do.
public func stoneBalance(from before: [Int: [Stone]],
                         to after: [Int: [Stone]]) -> [Stone: Int] {
    let old = stoneCounts(before), new = stoneCounts(after)
    return Stone.allCases.reduce(into: [:]) { result, stone in
        let difference = (new[stone] ?? 0) - (old[stone] ?? 0)
        if difference != 0 { result[stone] = difference }
    }
}
