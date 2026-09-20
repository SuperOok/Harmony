import HarmonyRules

// Which turn to play. Expectimax as `04-architektur.md` chose it: one turn of
// Harmony's own, and under it the chance layer — but summarised rather than
// enumerated, for the reason `docs/06-durchstich.md` measures.

/// A turn with everything the caretaker is owed about it.
///
/// Störfall C asks two questions and this answers both: what the turn is
/// worth, and how much better it is than the next best one. A number without
/// a comparison answers neither.
public struct Suggestion: Sendable {
    public let move: Move
    /// What the position is worth after the turn.
    public let value: Double
    /// What would be scored if the game ended after it. Deliberately apart
    /// from the worth: a turn can score nothing and still be the best.
    public let pointsNow: Int
    /// The largest contributions, named, for the reasoning.
    public let terms: [Term]
    /// The next best turn, and what it is worth.
    public let runnerUp: Move?
    public let runnerUpValue: Double?

    /// How far ahead the chosen turn is. Nothing to compare against means
    /// there was only one turn.
    public var margin: Double? {
        runnerUpValue.map { value - $0 }
    }
}

public enum Search {
    /// The best turn from this position, or none if there is no legal turn.
    ///
    /// Generating and weighing run together. `docs/06-durchstich.md` measures
    /// why: laying out a quarter of a million turns and then weighing them
    /// costs more in the laying out than in the weighing.
    public static func best(from state: EngineState,
                            weights: Weights = Weights()) -> Suggestion? {
        var bestMove: Move? = nil
        var bestValue = -Double.infinity
        var bestTerms: [Term] = []
        var bestPoints = 0
        var secondMove: Move? = nil
        var secondValue = -Double.infinity

        var offeredSpaces: Set<String> = []
        let anchors = Moves.standingHabitatCells(of: state)

        for (index, space) in state.display.enumerated() {
            let signature = space.map(\.rawValue).sorted().joined()
            guard offeredSpaces.insert(signature).inserted else { continue }

            // The chance layer, once per display space rather than once per
            // turn. What is refilled depends on **which space was emptied**
            // and never on where the stones went, so there are five of these
            // in a position and not a quarter of a million.
            let available = availability(after: index, of: state)

            for board in Moves.boards(placing: space, on: state) {
                for move in Moves.turns(space: index, board: board,
                                        from: state, anchors: anchors) {
                    let after = state.applying(move)
                    let evaluation = Evaluator.evaluate(after, weights: weights,
                                                        availability: available)
                    let value = evaluation.value
                    if value > bestValue {
                        secondMove = bestMove; secondValue = bestValue
                        bestMove = move; bestValue = value
                        bestTerms = evaluation.largest()
                        bestPoints = evaluation.pointsNow
                    } else if value > secondValue {
                        secondMove = move; secondValue = value
                    }
                }
            }
        }

        guard let bestMove else { return nil }
        return Suggestion(move: bestMove, value: bestValue, pointsNow: bestPoints,
                          terms: bestTerms, runnerUp: secondMove,
                          runnerUpValue: secondMove == nil ? nil : secondValue)
    }

    /// What the display is expected to offer once this space is taken and
    /// refilled from the bag.
    ///
    /// This **is** the chance layer. Instead of the fifty-six possible
    /// refills, their average: three stones drawn, each of colour *c* with
    /// the share *c* holds in the bag. What is lost is the coupling inside a
    /// single leaf — whether exactly the stone one candidate wants comes up.
    /// The expected value stays right, its spread disappears, and
    /// `docs/06-durchstich.md` names that as an assumption rather than a
    /// fact.
    ///
    /// The second chance source, the card that moves up when one is taken, is
    /// left out for a plainer reason: the evaluation looks at the cards in
    /// hand, never at the open ones, so which card appears changes nothing it
    /// computes.
    public static func availability(after taken: Int, of state: EngineState) -> Availability {
        var counts: [Stone: Double] = [:]
        for (index, space) in state.display.enumerated() where index != taken {
            for stone in space { counts[stone, default: 0] += 1 }
        }
        let bag = state.bag
        if bag.count > 0 {
            for stone in Stone.allCases {
                counts[stone, default: 0] += 3 * bag.chance(of: stone)
            }
        }
        return Availability(perColour: counts)
    }
}

extension EngineState {
    /// The position after a turn. The emptied display space is dropped
    /// rather than refilled — what comes back is the chance layer's business
    /// and is carried as an expectation, not as stones.
    public func applying(_ move: Move) -> EngineState {
        var next = self

        for (cell, added) in move.placements {
            next.stacks[cell] = (next.stacks[cell] ?? []) + added
        }
        for (cell, card) in move.cubes { next.cubes[cell] = card }

        if let taken = move.cardTaken,
           let card = openCards.first(where: { $0.name == taken }) {
            next.hand.append(HeldCard(card: card))
            next.openCards.removeAll { $0.name == taken }
        }
        for (index, held) in next.hand.enumerated() {
            let laid = move.cubes.values.count { $0 == held.card.name }
            if laid > 0 { next.hand[index].cubesPlaced += laid }
        }

        if move.space < next.display.count { next.display.remove(at: move.space) }
        next.turnsPlayed += 1
        return next
    }
}
