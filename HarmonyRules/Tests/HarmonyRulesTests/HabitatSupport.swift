@testable import HarmonyRules

extension Habitat {
    /// The placements that are finished, where a cube may go now. Only the
    /// tests ask this: the engine wants the whole set with what is missing,
    /// and takes the finished ones out of it itself.
    static func complete(of card: AnimalCard, on stacks: [Int: [Stone]],
                         cubes: Set<Int> = [], board: Board) -> [Habitat] {
        all(of: card, on: stacks, cubes: cubes, board: board).filter(\.isComplete)
    }
}
