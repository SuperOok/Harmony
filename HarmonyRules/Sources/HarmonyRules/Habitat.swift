import Foundation

// Where a card's pattern lies on a board, and where it could still come to
// lie. The second question is the one the engine leans on: a move that
// completes nothing may still be the best one, and without candidates there
// is nothing to tell a preparing move from an aimless one.
//
// This is rule computation, not procedure — it answers "is the pattern
// there?" and "could it get there?", both of which the rules decide. The
// choosing among them is evaluation and lives elsewhere.

extension PatternCell {
    /// The stacks that satisfy this landscape, derived from the list of
    /// legal stacks rather than written out a second time. A building is the
    /// only one with a choice: its lower stone may be red, brown or grey.
    public var stacks: [[Stone]] {
        let wanted: Landscape
        switch self {
        case .water:                        wanted = .water
        case .field:                        wanted = .field
        case .tree1, .tree2, .tree3:        wanted = .tree
        case .mountain1, .mountain2, .mountain3: wanted = .mountain
        case .building:                     wanted = .building
        }
        return [Stone].legal
            .filter { $0.count == height && $0.landscape == wanted }
            .sorted { $0.map(\.rawValue).joined() < $1.map(\.rawValue).joined() }
    }

    /// Can a space that is to become `other` pass through being this one
    /// first? True exactly when some stack of this landscape is the
    /// beginning of some stack of the other.
    ///
    /// Only mountains and the mountain-footed building do this — `Berg1`
    /// into `Berg2` into `Berg3`, and `Berg1` into `Gebäude`. A tree cannot:
    /// `Baum1` is a green stone on nothing, and `Baum2` wants a brown one
    /// underneath, which can no longer be slid in.
    public func canPrecede(_ other: PatternCell) -> Bool {
        guard height < other.height else { return false }
        return stacks.contains { short in
            other.stacks.contains { tall in tall.starts(with: short) }
        }
    }
}

extension Array where Element == Stone {
    /// What still has to go on top for this stack to become that landscape,
    /// one list per way of getting there. Empty list of lists means it never
    /// can — the stack is already too tall, or it took another turn.
    public func waysTo(_ cell: PatternCell) -> [[Stone]] {
        cell.stacks
            .filter { $0.starts(with: self) }
            .map { Array($0.dropFirst(count)) }
    }
}

// MARK: - A placement of one card

/// One card's pattern, laid on definite spaces of a definite board.
///
/// Complete when nothing is missing — then a cube may go on `cubeCell`.
/// Otherwise a **candidate**: it says what it still needs, and the engine
/// weighs whether that is worth building towards.
public struct Habitat: Sendable, Hashable {
    public let card: AnimalCard
    /// Board space to the landscape the card asks for there.
    public let requirement: [Int: PatternCell]
    /// Where the animal cube goes. Always one of `requirement`'s spaces.
    public let cubeCell: Int
    /// Board space to the stones still to be put on it, one entry per way of
    /// getting there. Spaces that already match do not appear.
    public let missing: [Int: [[Stone]]]

    public var isComplete: Bool { missing.isEmpty }

    /// How many stones are still wanted. Unambiguous even where the colours
    /// are not: what a space needs is the difference in height, and a
    /// building's lower stone may be any of three without changing that.
    public var missingStoneCount: Int {
        missing.values.reduce(0) { $0 + ($1.first?.count ?? 0) }
    }
}

extension Habitat {
    /// Every way this card's pattern lies or could still lie on this board.
    ///
    /// All six orientations, every position, and for each the spaces are
    /// checked one by one. Placements that cannot happen any more are left
    /// out: a stone never comes off again, so a space that took the wrong
    /// turn is final, and a space under a cube can no longer grow at all.
    public static func all(of card: AnimalCard,
                           on stacks: [Int: [Stone]],
                           cubes: Set<Int> = [],
                           board: Board) -> [Habitat] {
        // Sorted, not in dictionary order: the placements come out in the
        // same sequence on every run, which the snapshots in
        // `pruefverfahren.md` depend on.
        let pattern = card.pattern.keys.sorted().map {
            (Hex(cell: $0), card.pattern[$0]!, $0 == card.cube)
        }
        var found: [Habitat] = []
        var seen: Set<String> = []

        var turned = pattern
        for _ in 0..<6 {
            defer { turned = turned.map { ($0.0.rotated, $0.1, $0.2) } }
            guard let anchor = turned.first?.0 else { continue }

            for target in board.cells {
                let shift = Hex(cell: target) - anchor
                var requirement: [Int: PatternCell] = [:]
                var missing: [Int: [[Stone]]] = [:]
                var cubeCell: Int? = nil
                var possible = true

                for (place, wanted, isCube) in turned {
                    let cell = (place + shift).cell
                    guard board.contains(cell) else { possible = false; break }

                    let stack = stacks[cell] ?? []
                    let satisfied = wanted.stacks.contains(stack)
                    if !satisfied {
                        // A cube freezes its space: nothing goes on top of it.
                        let ways = cubes.contains(cell) ? [] : stack.waysTo(wanted)
                        guard !ways.isEmpty else { possible = false; break }
                        missing[cell] = ways
                    }
                    requirement[cell] = wanted
                    if isCube { cubeCell = cell }
                }

                // The cube's own space has to be free of one; at most one
                // cube lies on a stone. Other spaces of the pattern may
                // carry cubes, see `regeln-basisspiel.md`.
                guard possible, let cube = cubeCell, !cubes.contains(cube) else { continue }

                let key = requirement.keys.sorted()
                    .map { "\($0)\(requirement[$0]!.rawValue)" }
                    .joined() + "T\(cube)"
                guard seen.insert(key).inserted else { continue }

                found.append(Habitat(card: card, requirement: requirement,
                                     cubeCell: cube, missing: missing))
            }
        }
        return found
    }

    /// The placements that are finished, where a cube may go now.
    public static func complete(of card: AnimalCard,
                                on stacks: [Int: [Stone]],
                                cubes: Set<Int> = [],
                                board: Board) -> [Habitat] {
        all(of: card, on: stacks, cubes: cubes, board: board).filter(\.isComplete)
    }
}

// MARK: - Two candidates at once

/// How two placements get along on the spaces they share.
public enum Compatibility: Sendable, Equatable {
    /// They ask nothing contradictory; any order will do.
    case compatible
    /// One has to be finished, and its cube laid, before the other grows
    /// past it. A mountain of one takes its cube, then goes on rising.
    case ordered(HabitatOrder)
    /// A shared space cannot be both.
    case conflict
}

public enum HabitatOrder: Sendable, Equatable { case aFirst, bFirst }

extension Habitat {
    /// Whether two placements can both come about, and in which order.
    ///
    /// Two rules of the game make this possible at all, and
    /// `regeln-basisspiel.md` states both: a stone may belong to **several**
    /// habitats, and a cube once laid is **never** taken back even if its
    /// pattern is destroyed later. So a mountain of height one can take its
    /// cube and then grow into the mountain of height two that another card
    /// wants — unless that first cube lies on the growing space itself, in
    /// which case nothing more goes on top and the two exclude each other.
    public static func compatibility(_ a: Habitat, _ b: Habitat) -> Compatibility {
        var order: HabitatOrder? = nil

        for (cell, wantedByA) in a.requirement {
            guard let wantedByB = b.requirement[cell], wantedByA != wantedByB else { continue }

            let needed: HabitatOrder
            if wantedByA.canPrecede(wantedByB) {
                guard a.cubeCell != cell else { return .conflict }
                needed = .aFirst
            } else if wantedByB.canPrecede(wantedByA) {
                guard b.cubeCell != cell else { return .conflict }
                needed = .bFirst
            } else {
                return .conflict
            }

            if let already = order, already != needed { return .conflict }
            order = needed
        }
        return order.map { .ordered($0) } ?? .compatible
    }

    /// What a set of placements asks of each space together — per space the
    /// tallest landscape any of them wants. `nil` when they cannot all come
    /// about, which is the cheap way to ask about a whole set at once.
    public static func combinedRequirement(_ habitats: [Habitat]) -> [Int: PatternCell]? {
        for (i, a) in habitats.enumerated() {
            for b in habitats[(i + 1)...] where compatibility(a, b) == .conflict {
                return nil
            }
        }
        var combined: [Int: PatternCell] = [:]
        for habitat in habitats {
            for (cell, wanted) in habitat.requirement {
                if let already = combined[cell], already.height >= wanted.height { continue }
                combined[cell] = wanted
            }
        }
        return combined
    }

    /// How many stones a set of placements still costs **together**, shared
    /// spaces paid once.
    ///
    /// This is where the saving shows: two cubes out of largely the same
    /// stones is the cheapest thing the game offers, and a sum over the
    /// placements one by one would hide it.
    public static func missingStoneCount(for habitats: [Habitat],
                                         on stacks: [Int: [Stone]]) -> Int? {
        guard let combined = combinedRequirement(habitats) else { return nil }
        var total = 0
        for (cell, wanted) in combined {
            let height = (stacks[cell] ?? []).count
            guard height <= wanted.height else { return nil }
            total += wanted.height - height
        }
        return total
    }
}
