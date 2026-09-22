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

    /// Points in prospect are worth less than points in hand, **even when
    /// the prospect is certain**.
    ///
    /// Without this the engine never lays a cube. A finished but uncubed
    /// habitat is a candidate needing nothing, so its chance is one and it
    /// promises exactly what laying the cube would score — the two positions
    /// weigh the same, and the one that keeps the space free even weighs a
    /// little more. But realising a prospect still costs a future action and
    /// can be overtaken by the game ending, which the turn counter alone does
    /// not capture.
    public var outlook = 0.85

    public init() {}
}

/// What the display is expected to hold, colour by colour.
///
/// Not a count but an expectation: after a space is emptied it is refilled
/// from the bag, and rather than enumerating all fifty-six refills the
/// engine carries their average. `docs/06-durchstich.md` measures why —
/// enumerating them puts an empty board at thirteen million leaves.
public struct Availability: Sendable {
    public let perColour: [Stone: Double]

    public init(perColour: [Stone: Double]) { self.perColour = perColour }

    /// What lies there now, counted.
    public init(counting display: [[Stone]]) {
        var counts: [Stone: Double] = [:]
        for space in display {
            for stone in space { counts[stone, default: 0] += 1 }
        }
        perColour = counts
    }

    public var total: Double { perColour.values.reduce(0, +) }
}

/// What a whole laying's worth of turns has in common, worked out once.
///
/// Six turns share one laying: they differ in which card is taken, and the
/// card does not touch the board — `docs/06-durchstich.md` counts exactly
/// 6,0. Everything that hangs on the board alone was nevertheless computed
/// six times: the landscape scoring, the river outlook, and the pattern
/// search, which is the single most expensive thing the evaluation does and
/// which ran **twice** per turn on top of that, once for the candidates and
/// once for the variety.
///
/// Valid for exactly one board — and in two parts, because a cube spoils
/// only one of them.
public struct Prepared: Sendable {
    let landscapeNow: Int
    let landscapeTerms: [Term]
    /// Card name to every way its pattern could still lie on this board.
    /// Held for the cards in hand **and** for the open ones, because the
    /// turn may take one of those and it is then in hand.
    let habitats: [String: [Habitat]]
    /// The best candidate per card, already weighed.
    ///
    /// The six turns of a laying differ in the card they take and in nothing
    /// else, so what a **held** card promises is the same in all six — and
    /// the same for each open card, whichever turn takes it. Weighed once
    /// here rather than up to four times per turn.
    let prospects: [String: Evaluator.Prospect]
    /// How many cubes each card carried when the prospects were weighed. A
    /// turn that lays one changes what the next cube is worth, and then the
    /// prospect is no longer that card's.
    let cubesPlaced: [String: Int]
    /// Which spaces carried a cube when this was worked out. A turn that
    /// lays one more does not throw the stock away — see `Evaluator.habitats`.
    let cubes: Set<Int>
}

/// The candidates of the position a turn starts from.
///
/// Every laying of that turn grows at most three spaces out of this, so the
/// search works the pattern out **once per position** and derives the rest.
/// Before that it was worked out once per laying — thousands of times, and
/// measured at 92 to 98 percent of everything a laying costs.
public struct Stock: Sendable {
    let habitats: [String: [Habitat]]
    /// What lay when this was worked out. A laying does not lay cubes, so
    /// this must match; if it ever does not, the stock is not for this
    /// position and is not used.
    let cubes: Set<Int>
}

public enum Evaluator {
    /// The candidates of this position, for the cards in hand and for the
    /// open ones — the turn may take one of those.
    public static func stock(of state: EngineState) -> Stock {
        var habitats: [String: [Habitat]] = [:]
        for card in cardsInPlay(of: state) {
            guard habitats[card.name] == nil else { continue }
            habitats[card.name] = Habitat.all(of: card, on: state.stacks,
                                              cubes: state.cubeCells, board: state.board)
        }
        return Stock(habitats: habitats, cubes: state.cubeCells)
    }

    static func cardsInPlay(of state: EngineState) -> [AnimalCard] {
        state.hand.filter { !$0.isFinished }.map(\.card) + state.openCards
    }

    /// What holds for every turn from this laying. `state` is the position
    /// after the three stones are down and before a card or a cube.
    ///
    /// - Parameters:
    ///   - stock: the candidates of the position before the stones. Given
    ///     one, the pattern is not searched for again but grown forward.
    ///   - grown: the spaces this laying changed, each with the whole stack
    ///     that stands there now.
    public static func prepare(_ state: EngineState,
                               weights: Weights = Weights(),
                               availability: Availability? = nil,
                               from stock: Stock? = nil,
                               grown: [Int: [Stone]] = [:]) -> Prepared {
        let available = availability ?? Availability(counting: state.display)
        let scoring = BoardScoring(side: state.side, columns: state.side.columns,
                                   stacks: state.stacks)

        var habitats: [String: [Habitat]] = [:]
        if let stock, stock.cubes == state.cubeCells {
            for card in cardsInPlay(of: state) {
                guard habitats[card.name] == nil else { continue }
                guard let before = stock.habitats[card.name] else {
                    habitats[card.name] = Habitat.all(of: card, on: state.stacks,
                                                      cubes: state.cubeCells,
                                                      board: state.board)
                    continue
                }
                habitats[card.name] = before.compactMap {
                    $0.after(grown, cubes: state.cubeCells)
                }
            }
        } else {
            for card in cardsInPlay(of: state) {
                guard habitats[card.name] == nil else { continue }
                habitats[card.name] = Habitat.all(of: card, on: state.stacks,
                                                  cubes: state.cubeCells, board: state.board)
            }
        }

        // Die beste Aussicht je Karte, einmal für die ganze Legung. Für die
        // Handkarten mit ihren gelegten Würfeln, für die offenen mit keinem —
        // so kommt eine genommene Karte in die Hand.
        var prospects: [String: Prospect] = [:]
        var cubesPlaced: [String: Int] = [:]
        let held = Dictionary(state.hand.map { ($0.card.name, $0) },
                              uniquingKeysWith: { first, _ in first })
        for card in cardsInPlay(of: state) {
            guard cubesPlaced[card.name] == nil else { continue }
            let card = held[card.name] ?? HeldCard(card: card)
            cubesPlaced[card.card.name] = card.cubesPlaced
            guard !card.isFinished else { continue }
            prospects[card.card.name] = (habitats[card.card.name] ?? [])
                .compactMap { prospect(card, $0, state, available) }
                .max { $0.worth < $1.worth }
        }

        return Prepared(
            landscapeNow: scoring.breakdown().reduce(0) { $0 + $1.points },
            landscapeTerms: landscapeTerms(state, scoring: scoring, weights: weights,
                                           available: available),
            habitats: habitats,
            prospects: prospects,
            cubesPlaced: cubesPlaced,
            cubes: state.cubeCells)
    }

    /// - Parameter prepared: what was worked out once for this laying. Must
    ///   belong to **this** board, or the evaluation answers about another
    ///   position; the search hands it on only where that holds.
    public static func evaluate(_ state: EngineState,
                                weights: Weights = Weights(),
                                availability: Availability? = nil,
                                prepared: Prepared? = nil) -> Evaluation {
        let available = availability ?? Availability(counting: state.display)
        // Die Brettwertung wird nur noch gebraucht, wenn nichts vorliegt.
        let scoring = prepared == nil
            ? BoardScoring(side: state.side, columns: state.side.columns,
                           stacks: state.stacks)
            : nil
        var terms: [Term] = []

        // (1) Punkte jetzt
        let landscapeNow = prepared?.landscapeNow
            ?? scoring!.breakdown().reduce(0) { $0 + $1.points }
        let cardsNow = state.hand.reduce(0) { $0 + $1.score }
        terms.append(Term(name: "Landschaften", points: Double(landscapeNow) * weights.pointsNow))
        terms.append(Term(name: "Tierkarten", points: Double(cardsNow) * weights.pointsNow))

        // (2) Aussicht aus Anwärtern
        terms.append(contentsOf: candidateTerms(state, weights: weights,
                                                available: available, prepared: prepared))

        // (3) Aussicht aus Landschaften
        terms.append(contentsOf: prepared?.landscapeTerms
            ?? landscapeTerms(state, scoring: scoring!, weights: weights,
                              available: available))

        // (4) Optionenvielfalt
        if weights.variety != 0 {
            let live = liveCandidateCount(state, prepared: prepared)
            terms.append(Term(name: "Offene Möglichkeiten",
                              points: Double(live) * weights.variety,
                              detail: "\(live) Anwärter leben noch"))
        }

        return Evaluation(terms: terms, pointsNow: landscapeNow + cardsNow)
    }

    /// Every way this card could still lie — from the laying's stock if it
    /// is there, freshly otherwise.
    ///
    /// **A cube laid this turn does not spoil the stock; it thins it.**
    /// `Habitat.append` turns a candidate away over a cube on space *x* for
    /// exactly two reasons: *x* belongs to the pattern and would still have
    /// to grow there — which is what `missing[x]` records — or *x* is the
    /// candidate's own cube space. Nothing else in that function looks at
    /// the cubes. So the candidates for one more cube are exactly those of
    /// the stock that neither applies to, in the same order, and filtering
    /// answers what searching again would.
    ///
    /// The case that could undo this does not arise: two candidates with the
    /// same key are the same placement — same spaces, same requirement, same
    /// cube space — so a cube that turns the first away turns the second
    /// away as well. Nothing that was dropped could be let back in.
    static func habitats(of card: AnimalCard, on state: EngineState,
                         _ prepared: Prepared?) -> [Habitat] {
        guard let prepared, let stock = prepared.habitats[card.name] else {
            return Habitat.all(of: card, on: state.stacks, cubes: state.cubeCells,
                               board: state.board)
        }
        let laid = state.cubeCells.subtracting(prepared.cubes)
        guard !laid.isEmpty else { return stock }
        return stock.filter { habitat in
            !laid.contains { habitat.missing[$0] != nil || habitat.cubeCell == $0 }
        }
    }

    // MARK: - (2) Was die Anwärter versprechen

    /// The best compatible selection of candidates, and what it is worth.
    ///
    /// One candidate per card: a card needs one habitat for its next cube,
    /// not several. Over those at most four, every subset is tried — sixteen
    /// of them — and the best one that can all come about wins. Adding up
    /// candidates that exclude each other would promise points twice.
    static func candidateTerms(_ state: EngineState, weights: Weights,
                               available: Availability,
                               prepared: Prepared? = nil) -> [Term] {
        let laid = prepared.map { state.cubeCells.subtracting($0.cubes) } ?? []
        let best = state.hand.filter { !$0.isFinished }.compactMap { held -> Prospect? in
            // Vorgewogen gilt, solange diese Karte seither keinen Würfel
            // bekommen hat und der damals beste Anwärter noch steht. Ein
            // Würfel auf einem seiner Felder nimmt ihn heraus, und dann
            // könnte ein anderer der beste sein.
            if let ready = prepared?.prospects[held.card.name],
               prepared?.cubesPlaced[held.card.name] == held.cubesPlaced,
               !laid.contains(where: { ready.habitat.missing[$0] != nil
                                       || ready.habitat.cubeCell == $0 }) {
                return ready
            }
            return habitats(of: held.card, on: state, prepared)
                .compactMap { prospect(held, $0, state, available) }
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
                 points: prospect.worth * factor * weights.candidates * weights.outlook,
                 detail: prospect.detail)
        }
    }

    /// What one candidate promises: the next cube's gain, weighted by the
    /// chance of getting there in the turns Harmony has left.
    struct Prospect: Sendable {
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
                         _ state: EngineState,
                         _ available: Availability) -> Prospect? {
        guard let gain = held.nextCubeGain else { return nil }
        let chance = chance(ofBuilding: missingStones(habitat), state: state,
                            available: available)
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
    static func chance(ofBuilding needed: [Stone: Int], state: EngineState,
                       available: Availability? = nil) -> Double {
        let available = available ?? Availability(counting: state.display)
        let turns = state.ownTurnsLeft
        // The turn count is asked **before** the missing stones, and that
        // order is the point. A candidate that stands complete needs nothing
        // and used to answer 1 here whatever the clock said — so on her last
        // turn an uncubed pattern still promised its full gain and she left
        // the cube unlaid. Realising it takes a turn of her own; with none
        // left it promises nothing.
        guard turns > 0 else { return 0 }
        let total = needed.values.reduce(0, +)
        guard total > 0 else { return 1 }
        guard total <= 3 * turns else { return 0 }

        let bag = state.bag
        var chance = 1.0
        for (stone, count) in needed {
            let inDisplay = available.perColour[stone] ?? 0
            let pool = Double(bag.count) + available.total
            let share = pool > 0 ? (Double(bag.remaining(stone)) + inDisplay) / pool : 0
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
                               weights: Weights, available: Availability) -> [Term] {
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
                let chance = chance(ofBuilding: [.water: reachable.missing], state: state,
                                    available: available)
                terms.append(Term(name: "Fluss",
                                  points: Double(gain) * chance * weights.landscape
                                      * weights.outlook,
                                  detail: "Länge \(now) → \(reachable.length), "
                                      + "\(reachable.missing) blaue Steine"))
            }

        case .b:
            // Each island counts five, and the cheapest new one is a space
            // ringed with water. Near a corner that is two or three stones,
            // in the middle six — so the outlook tells the places apart from
            // the first turn on, which the river does on side A.
            if let cut = scoring.cheapestIslandCut(water: water) {
                let chance = chance(ofBuilding: [.water: cut.cost], state: state,
                                    available: available)
                terms.append(Term(name: "Inseln",
                                  points: 5 * chance * weights.landscape * weights.outlook,
                                  detail: "\(cut.cost) blaue Steine um "
                                      + "\(cellName(cut.cell)) ergäben eine Insel"))
            }
        }

        terms.append(contentsOf: buildingTerm(state, weights: weights, available: available))
        return terms
    }

    /// What the buildings that do not score yet could still be worth.
    ///
    /// A building pays five for three differently coloured neighbours and
    /// nothing at all below that, so it is worth exactly what the colours
    /// that can still reach it are worth. Without this the evaluation knew
    /// **no difference at all** between a building in the middle and one in
    /// a corner — both score zero the turn they are laid, and neither
    /// promised anything. Family (4) then decided, and it prefers the edge,
    /// where a stone spoils the fewest candidates. So the evaluation drove
    /// the building into the corner, where four spaces on either side have
    /// two neighbours and three colours can never stand.
    ///
    /// Which colours are still missing is decided by supply: the largest
    /// stocks first, because those are the ones she will actually see. The
    /// neighbours already standing are taken as fixed, although a stack can
    /// be built over — an understatement, and the cheap direction.
    static func buildingTerm(_ state: EngineState, weights: Weights,
                             available: Availability) -> [Term] {
        let supply: (Stone) -> Double = {
            Double(state.bag.remaining($0)) + (available.perColour[$0] ?? 0)
        }
        var worth = 0.0
        var open = 0
        var hopeless = 0

        for (cell, stack) in state.stacks where stack.landscape == .building {
            let ring = state.board.neighbours(cell)
            let colours = Set(ring.compactMap { state.stacks[$0]?.last })
            guard colours.count < 3 else { continue }
            open += 1
            let needed = 3 - colours.count
            let free = ring.count { state.stacks[$0] == nil }
            guard free >= needed else { hopeless += 1; continue }
            let wanted = Stone.allCases
                .filter { !colours.contains($0) }
                .sorted { supply($0) > supply($1) }
                .prefix(needed)
            let odds = chance(ofBuilding: Dictionary(uniqueKeysWithValues: wanted.map { ($0, 1) }),
                              state: state, available: available)
            worth += 5 * odds
        }

        guard open > 0 else { return [] }
        var detail = "\(open) Gebäude ohne drei Farben"
        if hopeless > 0 { detail += ", \(hopeless) davon ohne Aussicht" }
        return [Term(name: "Gebäude",
                     points: worth * weights.landscape * weights.outlook,
                     detail: detail)]
    }

    // MARK: - (4) Wie viel noch offen ist

    /// How many candidates survive. The fallback when the families above
    /// tell the moves apart not at all, which on the first turn is the rule.
    ///
    /// A stone in the middle leaves more patterns possible than one at the
    /// edge. That is the rule of thumb "start in the middle" — but read off
    /// as a number rather than set as a maxim, so it stays right on a filled
    /// board, where the middle has long since stopped being the best place.
    static func liveCandidateCount(_ state: EngineState,
                                   prepared: Prepared? = nil) -> Int {
        state.hand.filter { !$0.isFinished }.reduce(0) { total, held in
            total + habitats(of: held.card, on: state, prepared).count
        }
    }
}
