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

    /// How many turns were weighed before this came out.
    public let weighed: Int
    /// Whether every turn was weighed. A search that was stopped gives the
    /// best it had found, which is worth more than nothing — but it is not
    /// the best turn, and saying so is the difference between an answer and
    /// a claim.
    public let complete: Bool

    /// How far ahead the chosen turn is. Nothing to compare against means
    /// there was only one turn.
    public var margin: Double? {
        runnerUpValue.map { value - $0 }
    }
}

/// What a running search can say about itself while it runs.
///
/// A search that takes minutes has to be watchable, or the screen in front
/// of it is indistinguishable from a hung one. Reported is only what is
/// cheap to keep: a counter, which display space is being worked through,
/// and the best turn so far.
public struct SearchProgress: Sendable {
    /// How many turns have been weighed so far. There is no total to
    /// compare it against — that would mean generating them all first,
    /// which is the very thing the search avoids.
    public let weighed: Int
    /// How many display spaces are finished, and how many there are. The
    /// only honest measure of how far along a search is: within one space
    /// nothing is countable in advance, between them everything is.
    public let spacesDone: Int
    public let spacesTotal: Int
    /// The best turn found so far and what it is worth. This is what a
    /// stopped search hands back, so showing it beforehand says what
    /// stopping now would cost.
    public let best: Move?
    public let bestValue: Double?
}

public enum Search {
    /// The best turn from this position, or none if there is no legal turn.
    ///
    /// Generating and weighing run together. `docs/06-durchstich.md` measures
    /// why: laying out a quarter of a million turns and then weighing them
    /// costs more in the laying out than in the weighing.
    /// - Parameters:
    ///   - cancelled: asked every so often. A search that runs for minutes
    ///     has to be stoppable, or the interface in front of it looks hung.
    ///   - progress: called as the search advances, and once before it
    ///     begins so that a screen has something to show at zero seconds.
    ///     See `SearchProgress` for what is reported and why it is so
    ///     little.
    public static func best(from state: EngineState,
                            weights: Weights = Weights(),
                            cancelled: () -> Bool = { false },
                            progress: (SearchProgress) -> Void = { _ in }) -> Suggestion? {
        var bestMove: Move? = nil
        var bestValue = -Double.infinity
        var bestTerms: [Term] = []
        var bestPoints = 0
        var secondMove: Move? = nil
        var secondValue = -Double.infinity

        var weighed = 0
        var stopped = false
        var offeredSpaces: Set<String> = []
        let anchors = Moves.standingHabitatCells(of: state)

        // Spaces holding the same three stones are one choice, so the number
        // that will actually be worked through is smaller than the display.
        // Counted once here, because a fraction whose denominator grows
        // while one watches is worse than no fraction.
        let spacesTotal = Set(state.display.map { $0.map(\.rawValue).sorted().joined() }).count
        var spacesDone = 0

        func report() {
            progress(SearchProgress(weighed: weighed,
                                    spacesDone: spacesDone, spacesTotal: spacesTotal,
                                    best: bestMove,
                                    bestValue: bestMove == nil ? nil : bestValue))
        }
        report()

        for (index, space) in state.display.enumerated() {
            if stopped { break }
            let signature = space.map(\.rawValue).sorted().joined()
            guard offeredSpaces.insert(signature).inserted else { continue }

            // The chance layer, once per display space rather than once per
            // turn. What is refilled depends on **which space was emptied**
            // and never on where the stones went, so there are five of these
            // in a position and not a quarter of a million.
            let available = availability(after: index, of: state)

            for board in Moves.boards(placing: space, on: state) {
                if cancelled() { stopped = true; break }
                for move in Moves.turns(space: index, board: board,
                                        from: state, anchors: anchors) {
                    weighed += 1
                    if weighed % 2000 == 0 { report() }
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
            if !stopped { spacesDone += 1 }
            report()
        }

        report()
        guard let bestMove else { return nil }
        return Suggestion(move: bestMove, value: bestValue, pointsNow: bestPoints,
                          terms: bestTerms, runnerUp: secondMove,
                          runnerUpValue: secondMove == nil ? nil : secondValue,
                          weighed: weighed, complete: !stopped)
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
