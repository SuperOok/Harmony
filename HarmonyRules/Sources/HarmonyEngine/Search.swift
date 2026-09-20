import Foundation
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


/// The best two turns of one stretch of layings.
///
/// A stretch is what one core works through. Two of them are merged in the
/// order of the stretches and never in the order they happened to finish —
/// see `Search.best`.
struct Stretch: Sendable {
    var bestMove: Move? = nil
    var bestValue = -Double.infinity
    var bestTerms: [Term] = []
    var bestPoints = 0
    var secondMove: Move? = nil
    var secondValue = -Double.infinity
    var weighed = 0
    var stopped = false

    /// One turn, weighed. The same rule as before: strictly better takes
    /// the lead, so of two equal turns the earlier one stays.
    mutating func offer(_ move: Move, _ evaluation: Evaluation) {
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

    /// Take in another stretch's two. Fed in that order, the pair that comes
    /// out is the same one a single run through all of them would have
    /// found, ties included: both are strictly-better comparisons over the
    /// same values in the same order.
    mutating func take(_ other: Stretch) {
        weighed += other.weighed
        stopped = stopped || other.stopped
        if let move = other.bestMove { offerValue(move, other.bestValue,
                                                  other.bestTerms, other.bestPoints) }
        if let move = other.secondMove { offerValue(move, other.secondValue, [], 0) }
    }

    private mutating func offerValue(_ move: Move, _ value: Double,
                                     _ terms: [Term], _ points: Int) {
        if value > bestValue {
            secondMove = bestMove; secondValue = bestValue
            bestMove = move; bestValue = value
            bestTerms = terms; bestPoints = points
        } else if value > secondValue {
            secondMove = move; secondValue = value
        }
    }
}

/// What the cores report while they work: one counter and one turn to show,
/// both under a lock.
///
/// Advisory only. The answer is merged deterministically at the end; this is
/// what the screen gets to see in the meantime, and whether it sees a
/// particular intermediate turn or not changes nothing about the result.
final class Chatter: @unchecked Sendable {
    private let lock = NSLock()
    private var weighed = 0
    private var bestValue = -Double.infinity
    private var bestMove: Move? = nil

    /// Adds to the count and, if this one leads, notes the turn. Gives back
    /// what to report.
    func add(_ count: Int, best move: Move?, value: Double)
        -> (weighed: Int, best: Move?, value: Double?) {
        lock.lock()
        defer { lock.unlock() }
        weighed += count
        if let move, value > bestValue { bestValue = value; bestMove = move }
        return (weighed, bestMove, bestMove == nil ? nil : bestValue)
    }

    var total: Int {
        lock.lock(); defer { lock.unlock() }
        return weighed
    }
}


/// One slot per stretch. Each core writes its own and reads none, so the
/// lock a shared array would need is not needed here — but the compiler
/// cannot see that, hence the promise.
final class Parts: @unchecked Sendable {
    private var slots: [Stretch]
    init(_ count: Int) { slots = Array(repeating: Stretch(), count: count) }
    subscript(index: Int) -> Stretch {
        get { slots[index] }
        set { slots[index] = newValue }
    }
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
                            cancelled: @Sendable () -> Bool = { false },
                            progress: @Sendable (SearchProgress) -> Void = { _ in },
                            cores: Int = ProcessInfo.processInfo.activeProcessorCount)
        -> Suggestion? {
        var overall = Stretch()
        var offeredSpaces: Set<String> = []
        let anchors = Moves.standingHabitatCells(of: state)
        let chatter = Chatter()
        // Die Anwärter der Ausgangsstellung, einmal. Jede Legung wächst aus
        // ihnen hervor, statt das Brett erneut abzusuchen.
        let stock = Evaluator.stock(of: state)

        // Spaces holding the same three stones are one choice, so the number
        // that will actually be worked through is smaller than the display.
        // Counted once here, because a fraction whose denominator grows
        // while one watches is worse than no fraction.
        let spacesTotal = Set(state.display.map { $0.map(\.rawValue).sorted().joined() }).count
        var spacesDone = 0

        progress(SearchProgress(weighed: 0, spacesDone: 0, spacesTotal: spacesTotal,
                                best: nil, bestValue: nil))

        for (index, space) in state.display.enumerated() {
            if overall.stopped { break }
            let signature = space.map(\.rawValue).sorted().joined()
            guard offeredSpaces.insert(signature).inserted else { continue }

            // The chance layer, once per display space rather than once per
            // turn. What is refilled depends on **which space was emptied**
            // and never on where the stones went, so there are five of these
            // in a position and not a quarter of a million.
            let available = availability(after: index, of: state)
            let layings = Moves.layings(of: space, on: state)

            // **Layings are the cut.** There are thousands of them, each
            // costs about the same, and none depends on another. Display
            // spaces would be the wrong cut — at most five, unequal, and
            // equal ones collapse into one. Cards would be the wrong cut
            // too: that is the level on which work is *shared*, not split.
            //
            // Few layings are not worth the handover, so they stay on one
            // core.
            let stretches = layings.count < 64
                ? 1
                : max(1, min(cores, layings.count))
            let size = (layings.count + stretches - 1) / stretches
            let parts = Parts(stretches)

            // Der Stand der fertigen Felder als Wert, nicht als Veränderliche:
            // Ein nebenläufiger Teil darf ihn lesen, nicht mitwachsen sehen.
            let done = spacesDone

            if stretches == 1 {
                parts[0] = weigh(layings[...], space: index, of: state,
                                 weights: weights, available: available,
                                 anchors: anchors, stock: stock, cancelled: cancelled,
                                 chatter: chatter, spacesDone: done,
                                 spacesTotal: spacesTotal, progress: progress)
            } else {
                DispatchQueue.concurrentPerform(iterations: stretches) { part in
                    let lower = min(part * size, layings.count)
                    let upper = min(lower + size, layings.count)
                    guard lower < upper else { return }
                    parts[part] = weigh(layings[lower..<upper], space: index, of: state,
                                        weights: weights, available: available,
                                        anchors: anchors, stock: stock, cancelled: cancelled,
                                        chatter: chatter, spacesDone: done,
                                        spacesTotal: spacesTotal, progress: progress)
                }
            }

            // **In the order of the stretches**, never in the order they
            // finished. `SearchTests` assures that the same position gives
            // the same turn; with equal values that holds only if the
            // merging order is fixed, and the order cores finish in is not.
            for part in 0..<stretches { overall.take(parts[part]) }

            if !overall.stopped { spacesDone += 1 }
            progress(SearchProgress(weighed: overall.weighed,
                                    spacesDone: spacesDone, spacesTotal: spacesTotal,
                                    best: overall.bestMove,
                                    bestValue: overall.bestMove == nil ? nil : overall.bestValue))
        }

        progress(SearchProgress(weighed: overall.weighed,
                                spacesDone: spacesDone, spacesTotal: spacesTotal,
                                best: overall.bestMove,
                                bestValue: overall.bestMove == nil ? nil : overall.bestValue))
        guard let bestMove = overall.bestMove else { return nil }
        return Suggestion(move: bestMove, value: overall.bestValue,
                          pointsNow: overall.bestPoints,
                          terms: overall.bestTerms, runnerUp: overall.secondMove,
                          runnerUpValue: overall.secondMove == nil ? nil : overall.secondValue,
                          weighed: overall.weighed, complete: !overall.stopped)
    }

    /// One stretch of layings, weighed. This is the whole inner loop of the
    /// search; everything above only cuts the work up and puts it together.
    private static func weigh(_ layings: ArraySlice<Moves.Laying>, space: Int,
                              of state: EngineState, weights: Weights,
                              available: Availability, anchors: [Int],
                              stock: Stock,
                              cancelled: @Sendable () -> Bool,
                              chatter: Chatter, spacesDone: Int, spacesTotal: Int,
                              progress: @Sendable (SearchProgress) -> Void) -> Stretch {
        var stretch = Stretch()
        var sinceLastWord = 0

        for laying in layings {
            if cancelled() { stretch.stopped = true; break }

            // Was für alle Züge dieser Legung gilt, einmal. Die sechs Züge
            // darunter unterscheiden sich nur in der Karte, und die rührt
            // das Brett nicht an.
            let laid = state.laying(stacks: laying.stacks, space: space)
            let prepared = Evaluator.prepare(laid, weights: weights,
                                             availability: available,
                                             from: stock, grown: laying.grown)

            for move in Moves.turns(space: space, laying: laying,
                                    from: state, anchors: anchors) {
                stretch.weighed += 1
                sinceLastWord += 1
                let after = state.applying(move)
                // Auch über einen Würfel hinweg: Die Landschaft kennt keine
                // Würfel, und die Anwärter werden gefiltert statt neu
                // gesucht. In der teuersten Stellung legen sechs von zehn
                // Zügen einen Würfel — der Sonderfall ist dort der Regelfall.
                stretch.offer(move, Evaluator.evaluate(
                    after, weights: weights, availability: available,
                    prepared: prepared))
            }

            if sinceLastWord >= 2000 {
                let said = chatter.add(sinceLastWord, best: stretch.bestMove,
                                       value: stretch.bestValue)
                sinceLastWord = 0
                progress(SearchProgress(weighed: said.weighed,
                                        spacesDone: spacesDone, spacesTotal: spacesTotal,
                                        best: said.best, bestValue: said.value))
            }
        }
        _ = chatter.add(sinceLastWord, best: stretch.bestMove, value: stretch.bestValue)
        return stretch
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
    /// The position after the three stones are down, before a card is taken
    /// and before a cube is laid: what every turn from one laying has in
    /// common.
    ///
    /// `applying` is built on this rather than beside it. The two used to be
    /// written out separately, and they disagreed about one thing — this one
    /// forgot to count the turn — which moved the river outlook by a tenth
    /// of a point without anything failing. Sharing the code is the only
    /// assurance that cannot drift.
    public func laying(stacks laid: [Int: [Stone]], space: Int) -> EngineState {
        var next = self
        next.stacks = laid
        if space < next.display.count { next.display.remove(at: space) }
        next.turnsPlayed += 1
        return next
    }

    /// The position after a turn. The emptied display space is dropped
    /// rather than refilled — what comes back is the chance layer's business
    /// and is carried as an expectation, not as stones.
    public func applying(_ move: Move) -> EngineState {
        var stacks = self.stacks
        for (cell, added) in move.placements {
            stacks[cell] = (stacks[cell] ?? []) + added
        }
        var next = laying(stacks: stacks, space: move.space)

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

        return next
    }
}
