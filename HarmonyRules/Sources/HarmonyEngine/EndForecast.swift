import Foundation
import HarmonyRules

// When the others' boards might end the game. Harmony sees no foreign board,
// but she has seen every stone the others took — every turn passes through
// the display, and the display passes through the input. What she does not
// know is how much of it went onto a stack instead of a free space.
// `docs/06-durchstich.md`, *Das Ende der Partie*, has the reasoning.

/// One way the game could end through a foreign board, and how likely.
public struct EndOutcome: Sendable, Hashable {
    /// Turns after which the game is over, the played-out round included.
    public let endsAfter: Int
    public let chance: Double

    public init(endsAfter: Int, chance: Double) {
        self.endsAfter = endsAfter
        self.chance = chance
    }
}

/// What the others' boards say about the end.
public struct EndForecast: Sendable {
    /// The ends a foreign board could bring, in order. Their chances add up
    /// to at most one; the rest is the chance that no foreign board ends
    /// the game before the bag or her own board does.
    public let outcomes: [EndOutcome]
    /// Per opponent, in seating order: how many spaces are taken now, as
    /// mean and spread. For the log, where it can be held against the
    /// table.
    public let taken: [(seat: Int, mean: Double, spread: Double)]
}

extension EndForecast {
    /// How likely a stone of each colour is put on a stack rather than on a
    /// free space — **if** a stack that takes it is there.
    ///
    /// **Guessed from the scoring, not measured.** A lone red stone scores
    /// nothing, so red goes onto a stack almost always. So does green: a
    /// tree of height one pays 1, of two 3, of three 7. Grey pays by height
    /// as well, but only beside another mountain, and a card may want it at
    /// exactly one. Brown on brown serves nothing but a tree of three.
    /// Blue and yellow never stack.
    public static let stacking: [Stone: Double] = [
        .brick: 0.85, .leaves: 0.85, .stone: 0.6, .wood: 0.35,
    ]

    /// The forecast from what each opponent has taken.
    ///
    /// - Parameter taken: per opponent, their seat and the stones of each
    ///   of their turns so far, in order.
    ///
    /// **Not reporting is information.** The operator says when a foreign
    /// board is down to two free spaces; as long as nobody has, a board the
    /// model already thinks full is not, and that part of the spread goes.
    public static func forecast(taken: [(seat: Int, turns: [[Stone]])],
                                side: BoardSide, players: Int,
                                turnsPlayed: Int, bag: BagKnowledge) -> EndForecast {
        let size = side.board.cells.count
        let lastTurn = roundOut(EngineState.turnsInTheBag + 1, players)
        let bagShare = Stone.allCases.map { bag.chance(of: $0) }

        // For every opponent: the chance that her board has triggered the
        // end by each game turn, indexed by turn.
        var full: [[Double]] = []
        var summary: [(seat: Int, mean: Double, spread: Double)] = []
        for opponent in taken {
            var board = Spread(size: size)
            var mix = [Double](repeating: 0, count: 6)
            for turn in opponent.turns {
                board = board.after(known: turn)
                for stone in turn { mix[stone.slot] += 1 }
            }
            // What she did not report has not happened: a board that would
            // already be full is not, so that part of the spread goes.
            board = board.notFull()
            summary.append((opponent.seat, board.meanCells, board.spreadCells))

            // What she takes next: her own mix so far, with the bag as a
            // prior worth one turn.
            let total = mix.reduce(0, +) + 3
            let share = (0..<6).map { (mix[$0] + 3 * bagShare[$0]) / total }

            var byTurn = [Double](repeating: 0, count: lastTurn + 1)
            var reached = 0.0
            var turn = turnsPlayed
            while turn < lastTurn {
                // Once the board is as good as certainly full, the turns
                // after it need not be worked out.
                if turn % players == opponent.seat, reached < 1 - 1e-9 {
                    board = board.after(unknown: share)
                    reached = board.chanceFull()
                }
                byTurn[turn] = reached
                turn += 1
            }
            full.append(byTurn)
        }

        // The first to trigger ends it, and the round is played out. The
        // boards are taken as independent of each other.
        var outcomes: [Int: Double] = [:]
        var noneYet = 1.0
        for turn in turnsPlayed..<max(lastTurn, turnsPlayed) {
            let stillNone = full.reduce(1.0) { $0 * (1 - $1[turn]) }
            let now = noneYet - stillNone
            if now > 1e-9 {
                outcomes[roundOut(turn + 1, players), default: 0] += now
            }
            noneYet = stillNone
        }

        return EndForecast(
            outcomes: outcomes.keys.sorted().map { EndOutcome(endsAfter: $0, chance: outcomes[$0]!) },
            taken: summary)
    }

    static func roundOut(_ turns: Int, _ players: Int) -> Int {
        guard players > 0 else { return turns }
        return (turns + players - 1) / players * players
    }
}

/// One board, as a spread over what might lie on it.
///
/// The state is what matters for the next stone: how many spaces are taken,
/// and how many stacks are open for what. A single brown stone takes brown,
/// green or red; two browns take only green; a single grey takes grey or
/// red; two greys only grey; a single red only red. Everything else is
/// closed. Cubes close a stack too, and the others' cubes are not recorded
/// — so this can see a stack as open that is not, which errs towards more
/// stacking and a later end.
///
/// Open stacks are counted up to two of each kind. A turn brings three
/// stones, so more rarely matters, and the cap keeps the spread small
/// enough to work out in a moment. Where it does matter it undercounts the
/// stacks, which errs the other way — towards an earlier end. A full board
/// is one state, whatever lies on it: nothing after that matters.
///
/// Kept in a plain array rather than a dictionary, for speed and because a
/// dictionary hands its entries out in an order that differs from one
/// instance to the next — every sum over it would differ in its last digit,
/// and a tie in the search could then go either way.
struct Spread {
    /// Open stacks, two bits' worth each: a single brown, two browns, a
    /// single grey, two greys, a single red.
    struct Open: Hashable {
        var brown = 0, brownBrown = 0, grey = 0, greyGrey = 0, red = 0

        static let cap = 2
        static let count = 243          // 3^5

        var code: Int { brown + 3 * brownBrown + 9 * grey + 27 * greyGrey + 81 * red }

        init() {}
        init(code: Int) {
            brown = code % 3; brownBrown = code / 3 % 3; grey = code / 9 % 3
            greyGrey = code / 27 % 3; red = code / 81 % 3
        }

        mutating func add(_ count: WritableKeyPath<Open, Int>) {
            self[keyPath: count] = min(self[keyPath: count] + 1, Self.cap)
        }
    }

    /// What one stone does to one state: where it can go, and how likely.
    struct Step {
        let open: Int
        let cells: Int
        let chance: Double
    }

    /// Two free spaces or fewer end the game: this many taken is full.
    let full: Int
    /// Chance per state, at `cells * Open.count + open`. The full state is
    /// `full * Open.count`.
    var mass: [Double]

    init(size: Int) {
        full = size - 2
        mass = [Double](repeating: 0, count: (full + 1) * Open.count)
        mass[0] = 1
    }

    /// The order in which the stones of one turn are laid. A player who
    /// takes brown and green builds the tree in the same turn, so the
    /// stacks come first and what goes on them after.
    static let order: [Stone] = [.wood, .stone, .brick, .leaves, .water, .field]

    /// Per colour and open-stack state, where one stone of that colour goes.
    static let steps: [[[Step]]] = Stone.allCases.map { stone in
        (0..<Open.count).map { code in steps(stone, Open(code: code)) }
    }

    static func steps(_ stone: Stone, _ open: Open) -> [Step] {
        var flat = open
        var onTop: Open? = nil
        switch stone {
        case .water, .field:
            break
        case .leaves:
            // The higher tree first: it pays seven.
            if open.brownBrown > 0 { onTop = open; onTop!.brownBrown -= 1 }
            else if open.brown > 0 { onTop = open; onTop!.brown -= 1 }
        case .wood:
            flat.add(\.brown)
            if open.brown > 0 { onTop = open; onTop!.brown -= 1; onTop!.add(\.brownBrown) }
        case .stone:
            flat.add(\.grey)
            if open.greyGrey > 0 { onTop = open; onTop!.greyGrey -= 1 }
            else if open.grey > 0 { onTop = open; onTop!.grey -= 1; onTop!.add(\.greyGrey) }
        case .brick:
            flat.add(\.red)
            // A lone red stone first — it is worth nothing alone — then
            // grey, and brown last, since brown could still be a tree.
            if open.red > 0 { onTop = open; onTop!.red -= 1 }
            else if open.grey > 0 { onTop = open; onTop!.grey -= 1 }
            else if open.brown > 0 { onTop = open; onTop!.brown -= 1 }
        }
        guard let onTop else { return [Step(open: flat.code, cells: 1, chance: 1)] }
        let stacks = EndForecast.stacking[stone] ?? 0
        return [Step(open: onTop.code, cells: 0, chance: stacks),
                Step(open: flat.code, cells: 1, chance: 1 - stacks)]
    }

    /// One stone more.
    func after(_ stone: Stone) -> Spread {
        var next = self
        next.mass = [Double](repeating: 0, count: mass.count)
        next.mass[full * Open.count] = mass[full * Open.count]
        let steps = Self.steps[stone.slot]
        for cells in 0..<full {
            for open in 0..<Open.count {
                let p = mass[cells * Open.count + open]
                // Chances too small to matter are dropped, or the spread
                // grows with every stone without saying anything more.
                guard p > 1e-12 else { continue }
                for step in steps[open] {
                    let taken = cells + step.cells
                    let index = taken >= full ? full * Open.count : taken * Open.count + step.open
                    next.mass[index] += p * step.chance
                }
            }
        }
        return next
    }

    func after(known turn: [Stone]) -> Spread {
        var spread = self
        for stone in Self.order {
            for _ in 0..<turn.count(where: { $0 == stone }) {
                spread = spread.after(stone)
            }
        }
        return spread
    }

    /// A turn whose three stones are not known, only how likely each colour
    /// is.
    ///
    /// Worked out colour by colour in laying order rather than over the 56
    /// possible triples: how many of the first colour are in it is binomial,
    /// how many of the next among the rest is binomial again, and so on.
    /// The same answer, a fraction of the work.
    func after(unknown share: [Double]) -> Spread {
        // By how many stones of this turn are still to come.
        var waiting: [Spread?] = [nil, nil, nil, self]
        var left = 1.0
        for stone in Self.order {
            let p = share[stone.slot]
            let q = left > 1e-12 ? min(1, p / left) : 1
            left -= p
            var next: [Spread?] = [nil, nil, nil, nil]
            for remaining in 0...3 {
                guard var spread = waiting[remaining] else { continue }
                for these in 0...remaining {
                    let chance = Self.binomial(remaining, these, q)
                    if chance > 0 {
                        next[remaining - these] = next[remaining - these]
                            .map { $0.adding(spread, times: chance) }
                            ?? spread.scaled(chance)
                    }
                    spread = spread.after(stone)
                }
            }
            waiting = next
        }
        // Whatever the rounding left over sits with the last colour, which
        // takes all that remain.
        return waiting[0] ?? self
    }

    static func binomial(_ n: Int, _ k: Int, _ p: Double) -> Double {
        let ways = [[1], [1, 1], [1, 2, 1], [1, 3, 3, 1]][n][k]
        return Double(ways) * pow(p, Double(k)) * pow(1 - p, Double(n - k))
    }

    func scaled(_ factor: Double) -> Spread {
        var next = self
        for index in next.mass.indices { next.mass[index] *= factor }
        return next
    }

    func adding(_ other: Spread, times factor: Double) -> Spread {
        var next = self
        for index in next.mass.indices { next.mass[index] += other.mass[index] * factor }
        return next
    }

    func chanceFull() -> Double { mass[full * Open.count] }

    /// The chance that exactly this many spaces are taken, below full.
    func chance(ofCells cells: Int) -> Double {
        guard cells < full else { return cells == full ? chanceFull() : 0 }
        return mass[(cells * Open.count)..<((cells + 1) * Open.count)].reduce(0, +)
    }

    /// The spread without the full board, scaled back to one. If nothing is
    /// left the model is wrong about this board and the spread stays as it
    /// was, rather than claiming nothing.
    func notFull() -> Spread {
        let total = 1 - chanceFull()
        guard total > 1e-12 else { return self }
        var next = self
        next.mass[full * Open.count] = 0
        return next.scaled(1 / total)
    }

    var meanCells: Double {
        (0...full).reduce(0) { $0 + Double($1) * chance(ofCells: $1) }
    }

    var spreadCells: Double {
        let mean = meanCells
        let variance = (0...full).reduce(0) {
            $0 + (Double($1) - mean) * (Double($1) - mean) * chance(ofCells: $1)
        }
        return variance.squareRoot()
    }
}
