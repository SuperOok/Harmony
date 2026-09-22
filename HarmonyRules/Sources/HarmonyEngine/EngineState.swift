import HarmonyRules

// What Harmony knows, as she knows it. Not the game — `04-architektur.md`
// draws the line: no foreign boards, no foreign cubes, and no guessing at
// what the others hold. What she does know, she knows **exactly**, and that
// includes the bag.

// MARK: - The bag

/// What is left in the bag, per colour.
///
/// Not an estimate. Stones leave the bag only through refills, every refill
/// passes through the input, and a stone a player puts on their board was in
/// the display before and is long since accounted for. So the count is
/// arithmetic, and `04-architektur.md` builds the whole chance layer on it.
public struct BagKnowledge: Sendable, Hashable {
    /// `regeln-basisspiel.md`: 23 blue, 23 grey, 21 brown, 19 green,
    /// 19 yellow, 15 red — 120 stones.
    public static let total: [Stone: Int] = [
        .water: 23, .stone: 23, .wood: 21, .leaves: 19, .field: 19, .brick: 15,
    ]

    /// Everything that has ever left the bag: the fifteen of the setup and
    /// three per turn since.
    public let drawn: [Stone: Int]

    public init(drawn: [Stone: Int]) { self.drawn = drawn }

    public func remaining(_ stone: Stone) -> Int {
        (Self.total[stone] ?? 0) - (drawn[stone] ?? 0)
    }

    public var remaining: [Stone: Int] {
        Stone.allCases.reduce(into: [:]) { $0[$1] = remaining($1) }
    }

    public var count: Int { Stone.allCases.reduce(0) { $0 + remaining($1) } }

    /// The chance that a single stone drawn now is this colour.
    public func chance(of stone: Stone) -> Double {
        count > 0 ? Double(remaining(stone)) / Double(count) : 0
    }
}

// MARK: - A card in hand

/// One of Harmony's cards, with how many of its cubes are already on the
/// board.
public struct HeldCard: Sendable, Hashable {
    public let card: AnimalCard
    public var cubesPlaced: Int

    public init(card: AnimalCard, cubesPlaced: Int = 0) {
        self.card = card
        self.cubesPlaced = cubesPlaced
    }

    /// Scored is the **highest visible number**, which is the one under the
    /// cube laid last — `regeln-basisspiel.md`. None laid, nothing scored.
    public var score: Int {
        cubesPlaced < 1 ? 0 : card.points[min(cubesPlaced, card.points.count) - 1]
    }

    /// Finished once the last cube is down. It then stops counting against
    /// the limit of four.
    public var isFinished: Bool { cubesPlaced >= card.points.count }

    /// What laying the next cube would add. This, not the card's total, is
    /// what a move is worth — `04-architektur.md` says so explicitly, because
    /// cards are not comparable by their sums.
    public var nextCubeGain: Int? {
        guard !isFinished else { return nil }
        return card.points[cubesPlaced] - score
    }
}

// MARK: - The position

/// Everything Harmony holds between two of her turns.
public struct EngineState: Sendable {
    public var side: BoardSide
    /// Her own board: space to stack.
    public var stacks: [Int: [Stone]]
    /// Space to the card whose cube lies there. Both questions that
    /// `04-architektur.md` asks are answered from this one map — which
    /// spaces are taken, and how many cubes each card has down. Counting
    /// cubes off the board's patterns would not do: a cube stays when its
    /// pattern is destroyed.
    public var cubes: [Int: String]
    /// Her cards, finished ones included.
    public var hand: [HeldCard]
    /// The five spaces of the shared display, three stones each. Unordered
    /// within a space, and the spaces themselves carry no label — see
    /// `04-architektur.md`. Fewer once the bag runs dry.
    public var display: [[Stone]]
    /// The five cards lying open.
    public var openCards: [AnimalCard]
    /// What no one has seen yet. Known exactly, because every card that ever
    /// lay open was recorded.
    public var deck: [AnimalCard]
    /// Everything that has left the bag, per colour.
    public var drawn: [Stone: Int]
    /// Turns played in the game, by everyone.
    public var turnsPlayed: Int
    /// How many are playing, and where Harmony sits. Only the remaining turn
    /// count needs them.
    public var players: Int
    public var seat: Int
    /// The number of turns after which the game is over, once an end has
    /// been announced — `nil` while none has. The app knows all three
    /// triggers, including the one she cannot see for herself: the operator
    /// reporting that a foreign board is down to two free spaces. The round
    /// being played out is already in the number.
    public var endsAfter: Int?
    /// How the others' boards might end the game, if a forecast is to be
    /// used — see `EndForecast`. Empty means none: the known triggers alone
    /// then decide, as they did before there was a forecast.
    public var endForecast: [EndOutcome]

    public init(side: BoardSide = .a,
                stacks: [Int: [Stone]] = [:],
                cubes: [Int: String] = [:],
                hand: [HeldCard] = [],
                display: [[Stone]] = [],
                openCards: [AnimalCard] = [],
                deck: [AnimalCard] = [],
                drawn: [Stone: Int] = [:],
                turnsPlayed: Int = 0,
                players: Int = 3,
                seat: Int = 0,
                endsAfter: Int? = nil,
                endForecast: [EndOutcome] = []) {
        self.side = side
        self.stacks = stacks
        self.cubes = cubes
        self.hand = hand
        self.display = display
        self.openCards = openCards
        self.deck = deck
        self.drawn = drawn
        self.turnsPlayed = turnsPlayed
        self.players = players
        self.seat = seat
        self.endsAfter = endsAfter
        self.endForecast = endForecast
    }
}

// MARK: - What follows from it

extension EngineState {
    public var board: Board { side.board }

    public var bag: BagKnowledge { BagKnowledge(drawn: drawn) }

    /// The spaces carrying a cube — what the pattern search has to treat as
    /// frozen, because nothing goes on top of a stone with a cube on it.
    public var cubeCells: Set<Int> { Set(cubes.keys) }

    public var cubesPlaced: Int { cubes.count }

    /// Cards still waiting for cubes. `regeln-basisspiel.md` allows at most
    /// four, and a fifth may not be taken while they are held.
    public var unfinishedCards: [HeldCard] { hand.filter { !$0.isFinished } }

    public var mayTakeACard: Bool { unfinishedCards.count < 4 }

    public var freeCells: Int { board.cells.count - stacks.count }

    /// The second trigger: two or fewer free spaces end the game.
    public var boardIsFull: Bool { freeCells <= 2 }

    /// `regeln-basisspiel.md` counts it out: 105 stones in the bag, three a
    /// turn, so the bag carries exactly 35 turns. The 36th is still played —
    /// from the display — and its refill is the one that fails.
    public static let turnsInTheBag = 35

    public var turnsLeftInGame: Int { max(0, Self.turnsInTheBag - turnsPlayed) }

    /// The turn count after which the round is over: whoever triggers the
    /// end, everyone gets the same number of turns.
    func roundOut(_ turns: Int) -> Int {
        guard players > 0 else { return turns }
        return (turns + players - 1) / players * players
    }

    /// How many turns are left for Harmony herself. The evaluation needs
    /// this one, not the game's: whether a candidate is still reachable is a
    /// question about **her** remaining turns.
    ///
    /// **Every trigger counts, not just the bag.** `regeln-basisspiel.md`
    /// calls the bag an upper bound and says plainly that a full board can
    /// cut the game short — and her own board almost always does: side A
    /// holds 23 spaces and ends at 21 filled, which is seven turns of three
    /// stones, while the bag promises twelve at a table of three. Counting
    /// the bag alone she believed all game long that she had roughly twice
    /// the turns she had, and `chance(ofBuilding:)` inherited the error,
    /// since it raises every prospect by `1 - (1 - p)^(3t)`. Nothing then
    /// pressed her to finish anything.
    ///
    /// A foreign board she cannot see; she learns of it once the operator
    /// reports it, through `endsAfter`. Whether that report still leaves her
    /// a turn depends on where she sits: after the player who triggered it
    /// she gets one more, before them none — as starting player, never.
    public var ownTurnsLeft: Int {
        let left = min(ownTurnsInTheBag, ownTurnsUntilFull)
        guard let endsAfter else { return left }
        return min(left, max(0, ownTurns(before: endsAfter) - ownTurnsPlayed))
    }

    /// Her remaining turns as a spread, for a forecast end: each foreign end
    /// the forecast holds possible, cut down further by the known triggers,
    /// and the rest at `ownTurnsLeft`. Without a forecast, that alone.
    ///
    /// Handed to `body` rather than returned: `chance(ofBuilding:)` asks
    /// this millions of times per search, and an array per question would
    /// cost more than the answer. `chances[t]` is the chance of exactly `t`
    /// turns, for `t` up to `ownTurnsLeft`.
    func withTurnsLeft<Result>(_ body: (UnsafeBufferPointer<Double>) -> Result) -> Result {
        let certain = ownTurnsLeft
        return withUnsafeTemporaryAllocation(of: Double.self, capacity: certain + 1) { chances in
            chances.initialize(repeating: 0)
            var rest = 1.0
            if endsAfter == nil {
                for outcome in endForecast {
                    let turns = min(certain,
                                    max(0, ownTurns(before: outcome.endsAfter) - ownTurnsPlayed))
                    chances[turns] += outcome.chance
                    rest -= outcome.chance
                }
            }
            chances[certain] += max(0, rest)
            return body(UnsafeBufferPointer(chances))
        }
    }

    /// `withTurnsLeft` as an array, for the log and for tests. Not for the
    /// search, which asks too often to allocate.
    public var turnsLeftSpread: [Double] { withTurnsLeft { Array($0) } }

    /// The turns the stone budget is reckoned in: with a forecast, the
    /// count she reaches with three chances in four — cautious, because
    /// promising stones that never come costs points, and promising too few
    /// costs only chances.
    public var ownTurnsBudgeted: Int {
        guard !endForecast.isEmpty, endsAfter == nil else { return ownTurnsLeft }
        return withTurnsLeft { chances in
            var below = 0.0
            for turns in chances.indices {
                below += chances[turns]
                if below >= 0.25 { return turns }
            }
            return chances.count - 1
        }
    }

    /// How many of the game's first `limit` turns are hers — those at
    /// `seat`, `seat + players`, and so on.
    ///
    /// Counted rather than enumerated, because `chance(ofBuilding:)` asks
    /// for the remaining turns once per candidate per move, which is
    /// millions of times per search.
    func ownTurns(before limit: Int) -> Int {
        guard players > 0, limit > seat else { return 0 }
        return (limit - seat + players - 1) / players
    }

    /// Her own turns still covered by the bag, the 36th turn and the round
    /// it ends included.
    public var ownTurnsInTheBag: Int {
        max(0, ownTurns(before: roundOut(Self.turnsInTheBag + 1)) - ownTurnsPlayed)
    }

    /// Turns she has played herself.
    public var ownTurnsPlayed: Int { ownTurns(before: turnsPlayed) }

    /// How many more turns her own board holds before it triggers the end.
    ///
    /// Three stones a turn take **at most** three new spaces, and fewer as
    /// soon as she stacks — so the rate is measured rather than assumed:
    /// spaces filled per own turn so far. Before her first turn there is
    /// nothing to measure and the fastest case is taken.
    public var ownTurnsUntilFull: Int {
        let toFill = max(0, freeCells - 2)
        let perTurn = ownTurnsPlayed > 0
            ? Double(stacks.count) / Double(ownTurnsPlayed)
            : 3
        guard perTurn > 0 else { return Self.turnsInTheBag }
        return Int((Double(toFill) / perTurn).rounded(.up))
    }

    /// The cards she could still draw or take — everything not already hers
    /// and not already gone.
    public var reachableCards: [AnimalCard] { openCards + deck }
}

// MARK: - Checking itself

extension EngineState {
    /// What does not add up. Empty means consistent.
    ///
    /// Only what Harmony can actually check: she does not see the others'
    /// boards, so the full stone balance from `pruefverfahren.md` is out of
    /// reach. What is in reach is that nothing was invented — no colour
    /// drawn more often than it exists, no card carrying more cubes than it
    /// has, no stack that could not lie on a table.
    public var inconsistencies: [String] {
        var found: [String] = []

        for stone in Stone.allCases where bag.remaining(stone) < 0 {
            found.append("\(stone.name): \(-bag.remaining(stone)) mehr gezogen als es gibt")
        }

        let expected = 15 + 3 * turnsPlayed
        let actual = Stone.allCases.reduce(0) { $0 + (drawn[$1] ?? 0) }
        if actual > expected {
            found.append("\(actual) Steine gezogen, höchstens \(expected) möglich")
        }

        for (cell, stack) in stacks where !stack.isLegal {
            found.append("\(cellName(cell)): \(stack.map(\.rawValue).joined()) gibt es nicht")
        }

        for (cell, _) in cubes where stacks[cell] == nil {
            found.append("\(cellName(cell)): Würfel auf leerem Feld")
        }

        let held = Set(hand.map(\.card.name))
        for name in Set(cubes.values) where !held.contains(name) {
            found.append("Würfel von \(name), aber die Karte liegt nicht hier")
        }

        for card in hand {
            let onBoard = cubes.values.count { $0 == card.card.name }
            if onBoard != card.cubesPlaced {
                found.append("\(card.card.name): \(card.cubesPlaced) gezählt, \(onBoard) auf dem Brett")
            }
            if card.cubesPlaced > card.card.points.count {
                found.append("\(card.card.name): mehr Würfel als Felder")
            }
        }

        if unfinishedCards.count > 4 {
            found.append("\(unfinishedCards.count) unabgeschlossene Karten, erlaubt sind 4")
        }

        if openCards.count > 5 {
            found.append("\(openCards.count) offene Karten, es sind fünf")
        }

        let names = openCards.map(\.name) + deck.map(\.name) + hand.map(\.card.name)
        if Set(names).count != names.count {
            found.append("eine Karte kommt doppelt vor")
        }

        return found
    }
}
