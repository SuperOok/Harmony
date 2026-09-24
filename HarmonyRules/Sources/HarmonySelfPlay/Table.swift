import Foundation
import HarmonyRules
import HarmonyEngine

// One game at a simulated table: Harmony against opponents who choose at
// random. Not a second engine and not a model of good play — the others
// matter to Harmony only through what they leave in the display, which card
// they take and when their boards end the game, and each of those needs a
// dice roll rather than a decision. `docs/06-durchstich.md`, *Der Preis eines
// Kartenplatzes*, gives the reasoning and what it costs.

/// A small, seedable generator. `SystemRandomNumberGenerator` cannot be
/// seeded, and a game that cannot be replayed cannot be compared.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func chance(_ p: Double) -> Bool {
        Double.random(in: 0..<1, using: &self) < p
    }
}

/// How the opponents behave. Every figure is a guess, and the point of
/// running several is to see whether the answer depends on it.
struct Opponents: Sendable {
    /// The chance that an opponent with a free card space takes a card.
    var takesCard: Double
    /// The chance per turn that one of her unfinished cards is finished.
    var finishesCard = 0.12
}

/// How one game went, from Harmony's side.
struct GameResult: Sendable {
    var landscape = 0
    var cards = 0
    var total: Int { landscape + cards }
    /// Her own turn number (from 1) on which each card was taken.
    var takenOnTurn: [Int] = []
    var cardsFinished = 0
    var cardsUnfinished = 0
    /// Cubes laid in all.
    var cubes = 0
    var ownTurns = 0
    /// Turns on which the search found nothing to play.
    var stuck = 0
    var searchSeconds = 0.0
    var problems: [String] = []
}

/// One opponent's board, as far as the end of the game needs it: how many
/// spaces are taken. Where the stones went does not matter to anyone.
struct OpponentBoard {
    var taken = 0
    var unfinished = 0

    /// Three stones, each onto a stack with the chance the forecast assumes
    /// for its colour, else onto a free space. The same guess the forecast
    /// makes — a simulation that checked the forecast would need a better
    /// one, but this one only has to end the game at a plausible time.
    mutating func place(_ stones: [Stone], using rng: inout SplitMix64) {
        for stone in stones {
            let stacks = EndForecast.stacking[stone] ?? 0
            if taken > 0, rng.chance(stacks) { continue }
            taken += 1
        }
    }
}

struct Game {
    let seed: UInt64
    let players: Int
    let seat: Int
    let side: BoardSide
    let weights: Weights
    let opponents: Opponents
    let forecast: Bool

    /// Three streams, so that Harmony's choices do not shift what the bag
    /// or the others do. Two variants played on the same seed then meet the
    /// same stones in the same order, and their difference is not drowned
    /// in the luck of the draw.
    func play(cards all: [AnimalCard]) -> GameResult {
        var bagRNG = SplitMix64(seed: seed &* 3 &+ 1)
        var deckRNG = SplitMix64(seed: seed &* 3 &+ 2)
        var othersRNG = SplitMix64(seed: seed &* 3 &+ 3)

        var bag: [Stone] = BagKnowledge.total.sorted { $0.key.rawValue < $1.key.rawValue }
            .flatMap { Array(repeating: $0.key, count: $0.value) }
        bag.shuffle(using: &bagRNG)
        var deck = all
        deck.shuffle(using: &deckRNG)

        var drawn: [Stone: Int] = [:]
        func draw() -> [Stone] {
            let three = Array(bag.prefix(3))
            bag.removeFirst(min(3, bag.count))
            for stone in three { drawn[stone, default: 0] += 1 }
            return three
        }

        var state = EngineState(side: side, players: players, seat: seat)
        state.display = (0..<5).map { _ in draw() }
        state.openCards = Array(deck.prefix(5))
        deck.removeFirst(5)
        state.deck = deck
        state.drawn = drawn

        var boards = Array(repeating: OpponentBoard(), count: players)
        var takes: [Int: [[Stone]]] = [:]
        var result = GameResult()
        let lastTurn = (EngineState.turnsInTheBag + 1 + players - 1) / players * players

        func refillCard() {
            if !deck.isEmpty { state.openCards.append(deck.removeFirst()) }
            state.deck = deck
        }

        func refill() {
            if bag.count >= 3 { state.display.append(draw()) }
            state.drawn = drawn
        }

        while state.turnsPlayed < min(lastTurn, state.endsAfter ?? .max) {
            let turn = state.turnsPlayed
            let mover = turn % players

            if mover == seat {
                result.ownTurns += 1
                var position = state
                if forecast {
                    let seen = takes.keys.sorted().map { (seat: $0, turns: takes[$0]!) }
                    position.endForecast = EndForecast.forecast(
                        taken: seen, side: side, players: players,
                        turnsPlayed: turn, bag: state.bag).outcomes
                }
                let started = Date()
                // One core per game: the games run side by side, and that
                // uses the machine better than one game on all of them.
                let suggestion = Search.best(from: position, weights: weights, cores: 1)
                result.searchSeconds += Date().timeIntervalSince(started)

                guard let move = suggestion?.move else {
                    // Nothing legal: the stones cannot go anywhere. It should
                    // not happen before the end, and it is counted if it does.
                    result.stuck += 1
                    state.display.removeFirst()
                    state.turnsPlayed += 1
                    refill()
                    continue
                }
                if move.cardTaken != nil { result.takenOnTurn.append(result.ownTurns) }
                result.cubes += move.cubes.count

                let tookCard = move.cardTaken != nil
                state = state.applying(move)
                if tookCard { refillCard() }
                refill()

                if state.boardIsFull, state.endsAfter == nil {
                    state.endsAfter = (state.turnsPlayed + players - 1) / players * players
                }
            } else {
                var board = boards[mover]
                let space = Int.random(in: 0..<state.display.count, using: &othersRNG)
                let stones = state.display.remove(at: space)
                board.place(stones, using: &othersRNG)
                takes[mover, default: []].append(stones)

                for _ in 0..<board.unfinished where othersRNG.chance(opponents.finishesCard) {
                    board.unfinished -= 1
                }
                if board.unfinished < 4, !state.openCards.isEmpty,
                   othersRNG.chance(opponents.takesCard) {
                    let card = Int.random(in: 0..<state.openCards.count, using: &othersRNG)
                    state.openCards.remove(at: card)
                    board.unfinished += 1
                    refillCard()
                }
                boards[mover] = board
                state.turnsPlayed += 1
                refill()

                // The operator's report: this board is down to two spaces.
                if side.board.cells.count - board.taken <= 2, state.endsAfter == nil {
                    state.endsAfter = (state.turnsPlayed + players - 1) / players * players
                }
            }

            result.problems += state.inconsistencies
        }

        result.landscape = BoardScoring(side: side, columns: side.columns, stacks: state.stacks)
            .breakdown().reduce(0) { $0 + $1.points }
        result.cards = state.hand.reduce(0) { $0 + $1.score }
        result.cardsFinished = state.hand.count { $0.isFinished }
        result.cardsUnfinished = state.hand.count { !$0.isFinished }
        return result
    }
}
