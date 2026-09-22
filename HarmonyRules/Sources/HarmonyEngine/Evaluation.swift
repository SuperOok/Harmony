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
    /// The chance that her **next** turn finds a space holding a given set
    /// of up to three stones — see `NextTurn`. `nil` where nothing is known
    /// about the spaces, and then the chance falls back to the colour
    /// shares alone.
    let nextTurn: NextTurn?

    public init(perColour: [Stone: Double]) {
        self.perColour = perColour
        nextTurn = nil
    }

    /// What lies there now, counted.
    public init(counting display: [[Stone]]) {
        var counts: [Stone: Double] = [:]
        for space in display {
            for stone in space { counts[stone, default: 0] += 1 }
        }
        perColour = counts
        nextTurn = nil
    }

    /// Colour shares and spaces together: `perColour` as given, and the
    /// next turn worked out from the spaces that stay, the bag and the
    /// number of players.
    public init(perColour: [Stone: Double], spaces: [[Stone]], state: EngineState) {
        self.perColour = perColour
        nextTurn = NextTurn(spaces: spaces, bag: state.bag, players: state.players)
    }

    /// The display of this position, as it lies.
    public init(of state: EngineState) {
        let counted = Availability(counting: state.display)
        self.init(perColour: counted.perColour, spaces: state.display, state: state)
    }

    public var total: Double { perColour.values.reduce(0, +) }
}

/// What her next turn can take, set by set.
///
/// `1 - (1 - p)^(3t)` treats a turn as three stones drawn at random from
/// everything there is. For many turns that is fair; for **one** it is off
/// in both directions. She does not draw, she chooses one of five spaces —
/// if the stones she needs lie together in one of them, the chance is far
/// higher. And whatever she needs in that one turn has to lie **together**,
/// in one space: a green stone here and a red one there is no help, and the
/// formula counts them anyway.
///
/// So the next turn is worked out from the spaces. Those lying now survive
/// until she is on again with a chance that depends on how many others
/// choose before her; what replaces them is a fresh triple from the bag.
/// Worked out once per display, for every set of up to three stones — 83
/// of them — so that the evaluation only looks one up.
struct NextTurn: Sendable {
    /// Indexed by `code`: two bits per colour.
    private let table: [Double]

    /// How likely a space lying now is still there when she is on again.
    ///
    /// **An assumption, not a measurement:** each of the others takes one of
    /// the five spaces, all equally likely. Two players leave it with 0.8,
    /// three with 0.64, four with 0.51. The others choose rather than draw,
    /// so a space holding what is scarce goes sooner than this says.
    static func survival(players: Int) -> Double {
        pow(0.8, Double(max(players - 1, 0)))
    }

    init(spaces: [[Stone]], bag: BagKnowledge, players: Int) {
        let survives = Self.survival(players: players)

        // What a fresh triple holds, as sets with their probability. Drawn
        // with replacement from the bag's shares — one draw more or less
        // hardly moves a bag of dozens.
        //
        // Indexed by code rather than kept in a dictionary: a dictionary
        // hands its entries out in an order that differs from one instance
        // to the next, and the sum below would differ in its last digit —
        // enough for the same position to weigh differently twice.
        var triples = [Double](repeating: 0, count: 1 << 12)
        if bag.count > 0 {
            let share = Stone.allCases.map { bag.chance(of: $0) }
            for a in 0..<6 where share[a] > 0 {
                for b in 0..<6 where share[b] > 0 {
                    for c in 0..<6 where share[c] > 0 {
                        var counts = [0, 0, 0, 0, 0, 0]
                        counts[a] += 1; counts[b] += 1; counts[c] += 1
                        triples[Self.code(counts)] += share[a] * share[b] * share[c]
                    }
                }
            }
        }
        let known = spaces.map { space -> [Int] in
            var counts = [0, 0, 0, 0, 0, 0]
            for stone in space { counts[stone.slot] += 1 }
            return counts
        }
        // Five spaces when she is on: the ones lying now that survive, the
        // rest fresh. An empty bag refills nothing.
        let fresh = bag.count >= 3
            ? max(0, 5 - Double(known.count) * survives)
            : 0

        let sets = Self.allSets()
        let threes = sets.filter { $0.reduce(0, +) == 3 }
        var table = [Double](repeating: 0, count: 1 << 12)
        for needed in sets {
            let code = Self.code(needed)
            var noneKnown = 1.0
            for space in known where Self.holds(space, needed) {
                noneKnown *= 1 - survives
            }
            var inFresh = 0.0
            for triple in threes where Self.holds(triple, needed) {
                inFresh += triples[Self.code(triple)]
            }
            table[code] = 1 - noneKnown * pow(1 - inFresh, fresh)
        }
        self.table = table
    }

    /// The chance for this set, or `nil` if it is more than one turn holds.
    func chance(of needed: [Stone: Int]) -> Double? {
        var code = 0
        var total = 0
        for (stone, count) in needed {
            total += count
            guard total <= 3 else { return nil }
            code |= count << (2 * stone.slot)
        }
        return table[code]
    }

    static func code(_ counts: [Int]) -> Int {
        counts.indices.reduce(0) { $0 | counts[$1] << (2 * $1) }
    }

    static func holds(_ space: [Int], _ needed: [Int]) -> Bool {
        needed.indices.allSatisfy { space[$0] >= needed[$0] }
    }

    /// Every set of one to three stones.
    static func allSets() -> [[Int]] {
        var sets: [[Int]] = []
        func grow(_ counts: [Int], from colour: Int, left: Int) {
            if counts.reduce(0, +) > 0 { sets.append(counts) }
            guard left > 0 else { return }
            for next in colour..<6 {
                var more = counts
                more[next] += 1
                grow(more, from: next, left: left - 1)
            }
        }
        grow([0, 0, 0, 0, 0, 0], from: 0, left: 3)
        return sets
    }
}

extension Stone {
    /// A fixed position per colour, for tables indexed by colour.
    var slot: Int {
        switch self {
        case .water: 0
        case .stone: 1
        case .wood: 2
        case .leaves: 3
        case .field: 4
        case .brick: 5
        }
    }
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
    /// The river or the islands. The sleeping landscapes are kept apart,
    /// because what they get depends on what the turn's cards take first.
    let landscapeTerms: [Term]
    let sleepers: Evaluator.Sleepers
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
        let available = availability ?? Availability(of: state)
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
            sleepers: sleepers(state, weights: weights, available: available),
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
        let available = availability ?? Availability(of: state)
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

        // (2) Aussicht aus Anwärtern und (3) aus Landschaften — die
        // Anwärter und die schlafenden Landschaften aus einem Steinbudget.
        let promises = candidateTerms(state, weights: weights,
                                      available: available, prepared: prepared)
        let sleepers = prepared?.sleepers
            ?? sleepers(state, weights: weights, available: available)
        let river = prepared?.landscapeTerms
            ?? landscapeTerms(state, scoring: scoring!, weights: weights,
                              available: available)
        let (cards, asleep) = share(promises, sleepers, weights: weights)
        terms.append(contentsOf: cards)
        terms.append(contentsOf: river)
        terms.append(contentsOf: asleep)

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
                               prepared: Prepared? = nil) -> [Promise] {
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
            Promise(term: Term(name: "Aussicht \(prospect.card)",
                               points: prospect.worth * factor * weights.candidates
                                   * weights.outlook,
                               detail: prospect.detail),
                    stones: prospect.habitat.missingStoneCount)
        }
    }

    /// A candidate's term, with the stones it still has to be paid in.
    struct Promise: Sendable {
        let term: Term
        /// Counted on its own. Where two chosen candidates share a space the
        /// stone is counted twice — the cautious direction.
        let stones: Int
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
    ///
    /// **Her next turn is worked out from the display** (`NextTurn`), and
    /// with a single turn left that alone decides — it is where the formula
    /// is furthest off and where the answer matters most. With more turns
    /// the formula stands, but never below what the next turn already
    /// offers: more time is never worse than less. Without that floor, a
    /// turn that fills the board and so cuts her time to one would be
    /// rewarded for landing in the kinder model.
    static func chance(ofBuilding needed: [Stone: Int], state: EngineState,
                       available: Availability? = nil) -> Double {
        let available = available ?? Availability(of: state)
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

        let next = available.nextTurn?.chance(of: needed)
        if turns == 1, let next { return next }

        let bag = state.bag
        let pool = Double(bag.count) + available.total
        var chance = 1.0
        for (stone, count) in needed {
            let inDisplay = available.perColour[stone] ?? 0
            let share = pool > 0 ? (Double(bag.remaining(stone)) + inDisplay) / pool : 0
            guard share > 0 else { chance = 0; break }
            let once = 1 - pow(1 - share, Double(3 * turns))
            chance *= pow(once, Double(count))
        }
        return max(chance, next ?? 0)
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

        return terms
    }

    // MARK: - (3b) Landschaften, die noch schlafen

    /// One way a landscape that earns nothing yet could come to earn.
    struct Dormant: Sendable {
        /// What it will be once it wakes. A brown stack is on its way to a
        /// tree, so it answers `.tree` although it is no landscape today.
        let kind: Landscape
        /// What it pays then.
        let gain: Int
        /// Which stones have to arrive. Each one needs a space of its own.
        let needed: [Stone: Int]
        /// How many spaces are still open for them — free neighbours, or
        /// the room left on the stack where the way is to build upwards.
        let free: Int

        /// Enough room for what is missing. Where there is not, no sequence
        /// of draws can ever make this landscape score.
        var isPossible: Bool { needed.values.reduce(0, +) <= free }
    }

    /// The ways this space could come to score, if it does not already.
    ///
    /// **Four of the six scoring sources have a dormant phase**, and they
    /// share one shape: some stones have to arrive on spaces that are still
    /// open, after which the landscape pays its full points. Only which
    /// stones, where they go and what it pays differ.
    ///
    /// | Landschaft | zahlt | wartet auf |
    /// | --- | --- | --- |
    /// | Berg ohne Bergnachbarn | 1/3/7 nach Höhe | einen grauen Stein daneben |
    /// | einzelner gelber Stein | 5 | einen gelben Stein daneben |
    /// | Gebäude ohne drei Farben | 5 | die fehlenden Farben ringsum |
    /// | brauner Stapel | 3 oder 7 | sein Grün, **obendrauf** |
    ///
    /// Several ways can lead out of one space — the caller takes the best,
    /// not their sum, since a space is built once.
    ///
    /// The river and the islands are not here; they have their own outlook
    /// above. Neither is a finished tree: nothing stacks on green, so a
    /// tree never grows, and the only prospect a tree ever has is the one
    /// before its green stone.
    ///
    /// Neighbours already standing count as fixed. A stack can be built
    /// over, so this understates — the cheap direction.
    static func dormant(at cell: Int, on state: EngineState,
                        supply: (Stone) -> Double) -> [Dormant] {
        guard let stack = state.stacks[cell] else { return [] }
        let ring = state.board.neighbours(cell)
        let free = ring.count { state.stacks[$0] == nil }

        switch stack.landscape {
        case .mountain:
            guard !ring.contains(where: { (state.stacks[$0] ?? []).landscape == .mountain })
            else { return [] }
            // A lone grey stone is a mountain of height one, so one stone
            // on one free space is the whole requirement. It wakes the
            // neighbour too, which this does not count — the new mountain
            // brings its own points with it.
            return [Dormant(kind: .mountain, gain: BoardScoring.heightPoints(stack.count),
                            needed: [.stone: 1], free: free)]

        case .field:
            // A group of two or more already scores, and a group of one is
            // a space without a yellow neighbour — so asking the ring is
            // the same question as asking the group, and cheaper.
            guard !ring.contains(where: { (state.stacks[$0] ?? []).landscape == .field })
            else { return [] }
            return [Dormant(kind: .field, gain: 5, needed: [.field: 1], free: free)]

        case .building:
            let colours = Set(ring.compactMap { state.stacks[$0]?.last })
            guard colours.count < 3 else { return [] }
            // Which colours are missing is decided by supply — the largest
            // stocks first, since those are the ones she will see.
            let wanted = Stone.allCases
                .filter { !colours.contains($0) }
                .sorted { supply($0) > supply($1) }
                .prefix(3 - colours.count)
            return [Dormant(kind: .building, gain: 5,
                            needed: Dictionary(uniqueKeysWithValues: wanted.map { ($0, 1) }),
                            free: free)]

        case .tree, .water:
            return []

        case nil:
            // No landscape at all: a brown stack waiting for its green
            // stone, which is where the whole tree ladder is decided. `HH`
            // scores nothing and is two thirds of the way to seven points,
            // the densest single space in the game — and the evaluation
            // used to value it exactly like bare ground.
            //
            // A lone red stone is left out although it is dormant too: it
            // becomes a building only with a second red one, and that
            // building then still wants three colours around it. Two
            // uncertain steps chained, and rare on the table.
            guard stack.allSatisfy({ $0 == .wood }) else { return [] }
            // A cube freezes the space, and nothing more goes on top.
            guard !state.cubeCells.contains(cell) else {
                return [Dormant(kind: .tree,
                                gain: BoardScoring.heightPoints(stack.count + 1),
                                needed: [.leaves: 1], free: 0)]
            }
            let room = 3 - stack.count
            var ways = [Dormant(kind: .tree,
                                gain: BoardScoring.heightPoints(stack.count + 1),
                                needed: [.leaves: 1], free: room)]
            // Going one brown higher first pays seven instead of three, so
            // waiting is usually worth more than finishing — until the
            // clock makes the second stone unlikely, and then it is not.
            if room >= 2 {
                ways.append(Dormant(kind: .tree, gain: BoardScoring.heightPoints(3),
                                    needed: [.wood: 1, .leaves: 1], free: room))
            }
            return ways
        }
    }

    /// A sleeping landscape's best way out, weighed.
    struct Waiting: Sendable, Hashable {
        let kind: Landscape
        let worth: Double
        let stones: Int
    }

    /// The sleeping landscapes of one board, weighed but not yet paid for.
    ///
    /// Worked out once per laying, like the rest of the landscape. Which of
    /// them the stones still stretch to depends on the turn's cards, and
    /// that part is left to `share`.
    struct Sleepers: Sendable, Equatable {
        /// Their best ways out, in order of worth per stone.
        let waiting: [Waiting]
        let asleep: [Landscape: Int]
        let hopeless: [Landscape: Int]
        /// Three stones for each turn she has left.
        let budget: Int
        /// What they come to with the whole budget to themselves.
        let terms: [Term]
        /// And what that leaves over. A turn whose candidates need no more
        /// than this changes nothing here.
        let leftover: Int
    }

    /// What the sleeping landscapes promise, one term per kind.
    ///
    /// Before this the evaluation promised them nothing, and that is not a
    /// small omission: scoring zero today and nothing in prospect, every
    /// space for them was worth the same, so family (4) decided — and it
    /// prefers the edge, where a stone spoils the fewest candidates. The
    /// dormant landscapes were driven into the corners, where the
    /// neighbours they wait for cannot exist. Measured before the term was
    /// built, a lone mountain in the middle and one in a corner came out
    /// equal to three decimals, and so did a lone yellow stone.
    ///
    /// One term per kind rather than one for all three: the reasoning names
    /// the largest contributions, and "Berge" says something there that a
    /// collective name would not.
    static func sleepers(_ state: EngineState, weights: Weights,
                         available: Availability) -> Sleepers {
        let supply: (Stone) -> Double = {
            Double(state.bag.remaining($0)) + (available.perColour[$0] ?? 0)
        }
        var asleep: [Landscape: Int] = [:]
        var hopeless: [Landscape: Int] = [:]
        var waiting: [Waiting] = []

        // Over the board's spaces rather than over the stacks: a dictionary
        // hands them out in no fixed order, and summing doubles in a
        // different order each time would make the same position weigh
        // differently.
        for cell in state.board.cells {
            let ways = dormant(at: cell, on: state, supply: supply)
            guard let kind = ways.first?.kind else { continue }
            asleep[kind, default: 0] += 1
            // The best way out, not the sum of them: a space is built once,
            // and a brown stack that could take either a green stone now or
            // a brown one first will do one of the two.
            let best = ways.filter(\.isPossible).map { way in
                (worth: Double(way.gain) * chance(ofBuilding: way.needed, state: state,
                                                  available: available),
                 stones: way.needed.values.reduce(0, +))
            }.max { $0.worth < $1.worth }
            guard let best else {
                hopeless[kind, default: 0] += 1
                continue
            }
            waiting.append(Waiting(kind: kind, worth: best.worth, stones: best.stones))
        }

        // **They compete for the same stones**, and there are three a turn
        // and no more. Added up without that cap, nine brown stacks promised
        // 34 points — nine finished trees, which would take eighteen stones
        // she does not have. Each one on its own is right; the sum is the
        // lie.
        //
        // Taken in order of worth per stone until the budget runs out. A
        // greedy pass, not an optimum: the exact answer is a knapsack, and
        // paying for one per laying would not be worth what it buys.
        waiting.sort { $0.worth * Double($1.stones) > $1.worth * Double($0.stones) }
        let budget = 3 * state.ownTurnsLeft
        var left = budget
        var worth: [Landscape: Double] = [:]
        var unaffordable: [Landscape: Int] = [:]
        for one in waiting {
            guard one.stones <= left else {
                unaffordable[one.kind, default: 0] += 1
                continue
            }
            left -= one.stones
            worth[one.kind, default: 0] += one.worth
        }

        return Sleepers(waiting: waiting, asleep: asleep, hopeless: hopeless,
                        budget: budget,
                        terms: sleeperTerms(asleep: asleep, hopeless: hopeless,
                                            worth: worth, unaffordable: unaffordable,
                                            weights: weights),
                        leftover: left)
    }

    static func sleeperTerms(asleep: [Landscape: Int], hopeless: [Landscape: Int],
                             worth: [Landscape: Double], unaffordable: [Landscape: Int],
                             weights: Weights) -> [Term] {
        [Landscape.mountain, .field, .building, .tree].compactMap { landscape in
            guard let count = asleep[landscape] else { return nil }
            var detail = "\(count) \(waitingFor(landscape, count))"
            if let blind = hopeless[landscape] { detail += ", \(blind) davon ohne Aussicht" }
            if let short = unaffordable[landscape] { detail += ", für \(short) fehlt die Zeit" }
            return Term(name: name(of: landscape),
                        points: (worth[landscape] ?? 0) * weights.landscape * weights.outlook,
                        detail: detail)
        }
    }

    /// The candidates and the sleeping landscapes, out of **one** budget.
    ///
    /// The sleepers had shared their stones among themselves since the
    /// nine brown stacks; the candidates of family (2) each checked the
    /// limit on their own. In the last turn two cards and a mountain could
    /// together promise nine stones where three come — the same lie as
    /// the nine stacks, only across two families.
    ///
    /// Nothing changes while the turn's candidates fit into what the
    /// sleepers leave over, and that is the common case: the terms worked
    /// out once per laying stand as they are. Only where the stones run
    /// short does one greedy pass by worth per stone go over both, and a
    /// candidate that does not fit then promises nothing.
    static func share(_ promises: [Promise], _ sleepers: Sleepers,
                      weights: Weights) -> (cards: [Term], asleep: [Term]) {
        let wanted = promises.reduce(0) { $0 + $1.stones }
        guard wanted > sleepers.leftover else {
            return (promises.map(\.term), sleepers.terms)
        }

        // Compared in points, since the two families carry different weights.
        let scale = weights.landscape * weights.outlook
        enum Item { case card(Int), asleep(Int) }
        var items: [(item: Item, points: Double, stones: Int)] =
            promises.indices.map { (.card($0), promises[$0].term.points, promises[$0].stones) }
        items += sleepers.waiting.indices.map {
            (.asleep($0), sleepers.waiting[$0].worth * scale, sleepers.waiting[$0].stones)
        }
        items.sort { $0.points * Double($1.stones) > $1.points * Double($0.stones) }

        var left = sleepers.budget
        var kept = Set<Int>()
        var worth: [Landscape: Double] = [:]
        var unaffordable: [Landscape: Int] = [:]
        for one in items {
            let fits = one.stones <= left
            if fits { left -= one.stones }
            switch one.item {
            case let .card(index):
                if fits { kept.insert(index) }
            case let .asleep(index):
                let kind = sleepers.waiting[index].kind
                if fits { worth[kind, default: 0] += sleepers.waiting[index].worth }
                else { unaffordable[kind, default: 0] += 1 }
            }
        }

        let cards = promises.indices.filter(kept.contains).map { promises[$0].term }
        return (cards, sleeperTerms(asleep: sleepers.asleep, hopeless: sleepers.hopeless,
                                    worth: worth, unaffordable: unaffordable,
                                    weights: weights))
    }

    static func name(of landscape: Landscape) -> String {
        switch landscape {
        case .mountain: "Berge"
        case .field: "Felder"
        case .building: "Gebäude"
        case .tree: "Bäume"
        case .water: "Wasser"
        }
    }

    static func waitingFor(_ landscape: Landscape, _ count: Int) -> String {
        switch landscape {
        case .mountain: "Berg\(count == 1 ? "" : "e") ohne Bergnachbarn"
        case .field: "einzelne\(count == 1 ? "r" : "") gelbe\(count == 1 ? "r" : "") Stein\(count == 1 ? "" : "e")"
        case .building: "Gebäude ohne drei Farben"
        case .tree: "braune\(count == 1 ? "r" : "") Stapel ohne Grün"
        case .water: ""
        }
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
