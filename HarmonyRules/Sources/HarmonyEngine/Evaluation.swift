import Foundation
import HarmonyRules

// What a position is worth. Separate from the search, in its own file, and
// that is not tidiness: `04-architektur.md` accepts v1 on the runthrough
// rather than on playing strength, and leans on being able to improve this
// without rebuilding anything around it.
//
// Every term carries a name. The reasoning shown to the caretaker names the
// largest contributions, so a nameless summand could not appear in it.

/// One named contribution.
public struct Term: Sendable, Hashable {
    public let name: String
    public let points: Double
    /// Where the number comes from, for the reasoning. An outlook says its
    /// probability here, because a bare expected value looks invented.
    public let detail: String?

    public init(name: String, points: Double, detail: String? = nil) {
        self.name = name
        self.points = points
        self.detail = detail
    }
}

/// What a position is worth, and out of what.
public struct Evaluation: Sendable {
    public let terms: [Term]
    /// Points that would be scored if the game ended now. Kept apart from
    /// the worth on purpose: a turn can score nothing and still be the best
    /// one, so the search compares worth and the caretaker sees both.
    public let pointsNow: Int

    public var value: Double { terms.reduce(0) { $0 + $1.points } }

    /// The largest contributions, for the reasoning.
    public func largest(_ count: Int = 3) -> [Term] {
        terms.filter { $0.points != 0 }
            .sorted { abs($0.points) > abs($1.points) }
            .prefix(count)
            .map { $0 }
    }
}

/// How the four families are weighed against each other.
///
/// **Guessed, not measured.** They belong measured once self-play runs; see
/// the open points in `docs/06-durchstich.md`. They sit in one place so that
/// measuring them later changes one thing.
public struct Weights: Sendable {
    public var pointsNow = 1.0
    public var candidates = 1.0
    public var landscape = 1.0
    public var variety = 0.05

    public init() {}
}

public enum Evaluator {
    public static func evaluate(_ state: EngineState,
                                weights: Weights = Weights()) -> Evaluation {
        let scoring = BoardScoring(side: state.side, columns: state.side.columns,
                                   stacks: state.stacks)
        var terms: [Term] = []

        // (1) Punkte jetzt
        let landscapeNow = scoring.breakdown().reduce(0) { $0 + $1.points }
        let cardsNow = state.hand.reduce(0) { $0 + $1.score }
        terms.append(Term(name: "Landschaften", points: Double(landscapeNow) * weights.pointsNow))
        terms.append(Term(name: "Tierkarten", points: Double(cardsNow) * weights.pointsNow))

        // (2) Aussicht aus Anwärtern
        terms.append(contentsOf: candidateTerms(state, weights: weights))

        // (3) Aussicht aus Landschaften
        terms.append(contentsOf: landscapeTerms(state, scoring: scoring, weights: weights))

        // (4) Optionenvielfalt
        if weights.variety != 0 {
            let live = liveCandidateCount(state)
            terms.append(Term(name: "Offene Möglichkeiten",
                              points: Double(live) * weights.variety,
                              detail: "\(live) Anwärter leben noch"))
        }

        return Evaluation(terms: terms, pointsNow: landscapeNow + cardsNow)
    }

    // MARK: - (2) Was die Anwärter versprechen

    /// The best compatible selection of candidates, and what it is worth.
    ///
    /// One candidate per card: a card needs one habitat for its next cube,
    /// not several. Over those at most four, every subset is tried — sixteen
    /// of them — and the best one that can all come about wins. Adding up
    /// candidates that exclude each other would promise points twice.
    static func candidateTerms(_ state: EngineState, weights: Weights) -> [Term] {
        let best = state.hand.filter { !$0.isFinished }.compactMap { held -> Prospect? in
            Habitat.all(of: held.card, on: state.stacks, cubes: state.cubeCells,
                        board: state.board)
                .compactMap { prospect(held, $0, state) }
                .max { $0.worth < $1.worth }
        }
        guard !best.isEmpty else { return [] }

        var chosen: [Prospect] = []
        var bestWorth = -1.0
        for mask in 0..<(1 << best.count) {
            let subset = best.indices.filter { mask & (1 << $0) != 0 }.map { best[$0] }
            guard Habitat.combinedRequirement(subset.map(\.habitat)) != nil else { continue }
            let worth = sharedWorth(subset, state)
            if worth > bestWorth { bestWorth = worth; chosen = subset }
        }
        guard !chosen.isEmpty else { return [] }

        // The saving from shared spaces belongs to the selection, not to one
        // of its members, so it is handed back in proportion. Every term
        // still names its card, which the reasoning needs.
        let apart = chosen.reduce(0) { $0 + $1.worth }
        let factor = apart > 0 ? bestWorth / apart : 1

        return chosen.map { prospect in
            Term(name: "Aussicht \(prospect.card)",
                 points: prospect.worth * factor * weights.candidates,
                 detail: prospect.detail)
        }
    }

    /// What one candidate promises: the next cube's gain, weighted by the
    /// chance of getting there in the turns Harmony has left.
    struct Prospect {
        let card: String
        let habitat: Habitat
        let gain: Int
        let chance: Double
        var worth: Double { Double(gain) * chance }
            var detail: String {
            "\(gain) Punkte × \(Int((chance * 100).rounded())) %"
        }
    }

    static func prospect(_ held: HeldCard, _ habitat: Habitat,
                         _ state: EngineState) -> Prospect? {
        guard let gain = held.nextCubeGain else { return nil }
        let chance = chance(ofBuilding: missingStones(habitat), state: state)
        guard chance > 0 else { return nil }
        return Prospect(card: held.card.name, habitat: habitat, gain: gain, chance: chance)
    }

    /// Shared spaces are paid once, so a selection is worth more than its
    /// parts suggest. The saving is handed back to the terms in proportion,
    /// which keeps the reasoning honest: every term still names its card.
    static func sharedWorth(_ subset: [Prospect], _ state: EngineState) -> Double {
        guard !subset.isEmpty else { return 0 }
        let together = Habitat.missingStoneCount(for: subset.map(\.habitat), on: state.stacks)
        let apart = subset.reduce(0) { $0 + $1.habitat.missingStoneCount }
        guard let together, apart > 0 else { return subset.reduce(0) { $0 + $1.worth } }
        // Fewer stones for the same cubes: the saving raises the chance of
        // getting there, and that is where the synergy shows.
        let saving = Double(apart - together) / Double(apart)
        return subset.reduce(0) { $0 + $1.worth } * (1 + saving)
    }

    /// The stones a candidate still needs, by colour. Where a space allows
    /// several ways — only a building's lower stone does — the first is
    /// taken; the number is the same either way.
    static func missingStones(_ habitat: Habitat) -> [Stone: Int] {
        var needed: [Stone: Int] = [:]
        for ways in habitat.missing.values {
            for stone in ways.first ?? [] { needed[stone, default: 0] += 1 }
        }
        return needed
    }

    /// How likely those stones arrive in time.
    ///
    /// **A first model, not a measurement.** Each stone is treated as
    /// arriving independently: with `p` its colour's share of the bag and
    /// three stones placed per own turn, the chance of seeing it at least
    /// once in `t` turns is `1 - (1 - p)^(3t)`. It overstates, because the
    /// stones are needed together and the display is shared with everyone
    /// else. What it does get right is the direction: scarcer colour, less
    /// time or more stones missing all lower it, and that is what the
    /// ranking rests on. The shape belongs measured once self-play runs.
    static func chance(ofBuilding needed: [Stone: Int], state: EngineState) -> Double {
        let total = needed.values.reduce(0, +)
        guard total > 0 else { return 1 }
        let turns = state.ownTurnsLeft
        guard turns > 0, total <= 3 * turns else { return 0 }

        let bag = state.bag
        var chance = 1.0
        for (stone, count) in needed {
            let inDisplay = state.display.reduce(0) { $0 + $1.count { $0 == stone } }
            let share = bag.count > 0
                ? Double(bag.remaining(stone) + inDisplay) / Double(bag.count + 15)
                : 0
            guard share > 0 else { return 0 }
            let once = 1 - pow(1 - share, Double(3 * turns))
            chance *= pow(once, Double(count))
        }
        return chance
    }

    // MARK: - (3) Was die Landschaften noch hergeben

    /// The outlook of the general scoring, which carries the early game.
    ///
    /// On an empty board nearly every candidate is alive, so family (2) is
    /// flat and tells the moves apart not at all. The river on side A and the
    /// islands on side B are the largest single items of the final score and
    /// hang on where the stones lie, not on which cards are held.
    ///
    /// What is needed is the **outlook** of that scoring, not its value
    /// today — today it is zero everywhere on an empty board.
    static func landscapeTerms(_ state: EngineState, scoring: BoardScoring,
                               weights: Weights) -> [Term] {
        var terms: [Term] = []
        let free = Set(state.board.cells.filter { state.stacks[$0] == nil })
        let water = Set(state.board.cells.filter {
            (state.stacks[$0] ?? []).landscape == .water
        })

        switch state.side {
        case .a:
            // How long the river could still become: the longest path
            // through what is water already together with what is still
            // empty. An upper bound, discounted by the blue stones it would
            // take and how likely they are.
            let reachable = scoring.longestReachableRiver(water: water, free: free)
            let now = scoring.longestRiver(water: water)
            let gain = BoardScoring.riverPoints(reachable.length) - BoardScoring.riverPoints(now)
            if gain > 0 {
                let chance = chance(ofBuilding: [.water: reachable.missing], state: state)
                terms.append(Term(name: "Fluss",
                                  points: Double(gain) * chance * weights.landscape,
                                  detail: "Länge \(now) → \(reachable.length), "
                                      + "\(reachable.missing) blaue Steine"))
            }

        case .b:
            // Each island counts five, and the cheapest new one is a space
            // ringed with water. Near a corner that is two or three stones,
            // in the middle six — so the outlook tells the places apart from
            // the first turn on, which the river does on side A.
            if let cut = scoring.cheapestIslandCut(water: water) {
                let chance = chance(ofBuilding: [.water: cut.cost], state: state)
                terms.append(Term(name: "Inseln",
                                  points: 5 * chance * weights.landscape,
                                  detail: "\(cut.cost) blaue Steine um "
                                      + "\(cellName(cut.cell)) ergäben eine Insel"))
            }
        }
        return terms
    }

    // MARK: - (4) Wie viel noch offen ist

    /// How many candidates survive. The fallback when the families above
    /// tell the moves apart not at all, which on the first turn is the rule.
    ///
    /// A stone in the middle leaves more patterns possible than one at the
    /// edge. That is the rule of thumb "start in the middle" — but read off
    /// as a number rather than set as a maxim, so it stays right on a filled
    /// board, where the middle has long since stopped being the best place.
    static func liveCandidateCount(_ state: EngineState) -> Int {
        state.hand.filter { !$0.isFinished }.reduce(0) { total, held in
            total + Habitat.all(of: held.card, on: state.stacks,
                                cubes: state.cubeCells, board: state.board).count
        }
    }
}
