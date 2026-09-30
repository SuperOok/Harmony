import Foundation
import HarmonyRules
import HarmonyEngine

// The whole table, as nobody at a real one sees it: every board, the bag in
// the order it will be drawn, the deck in the order it will be turned up.
// Engines playing each other sit at it, each handed only what Harmony would
// know at a real table (`view(for:)`), and every turn they play passes the
// referee before it touches anything. `docs/06-durchstich.md`, *Engines
// gegeneinander*, has the reasoning.

/// One player's side of the table.
public struct Seat: Sendable {
    public let name: String
    public var stacks: [Int: [Stone]] = [:]
    /// Space to the card whose cube lies there.
    public var cubes: [Int: String] = [:]
    public var hand: [HeldCard] = []
    /// The stones of each of her turns, in order — what the others see her
    /// take, and what their end forecast is made from.
    public var takes: [[Stone]] = []

    public init(name: String) { self.name = name }

    public var unfinished: Int { hand.count { !$0.isFinished } }
}

public struct Table: Sendable {
    public let side: BoardSide
    public var seats: [Seat]
    public var display: [[Stone]]
    public var openCards: [AnimalCard]
    /// Face down, in the order they will be turned up.
    public var deck: [AnimalCard]
    /// In the order it will be drawn.
    public var bag: [Stone]
    /// Everything that has left the bag, per colour.
    public var drawn: [Stone: Int] = [:]
    public var turnsPlayed = 0
    /// The turn count after which the game is over, once an end is set off.
    public var endsAfter: Int?

    /// Every card exactly once, and every stone.
    public static let cardCount = 32
    public static let stoneCount = BagKnowledge.total.values.reduce(0, +)

    /// A fresh table: bag and deck shuffled from the seed, fifteen stones
    /// and five cards laid out. The two come from separate streams, so the
    /// same seed deals the same stones whatever the cards do.
    public init(side: BoardSide, names: [String], cards: [AnimalCard], seed: UInt64) {
        var bagRNG = SplitMix64(seed: seed &* 2 &+ 1)
        var deckRNG = SplitMix64(seed: seed &* 2 &+ 2)
        self.side = side
        seats = names.map(Seat.init)
        bag = BagKnowledge.total.sorted { $0.key.rawValue < $1.key.rawValue }
            .flatMap { Array(repeating: $0.key, count: $0.value) }
        bag.shuffle(using: &bagRNG)
        deck = cards
        deck.shuffle(using: &deckRNG)
        display = []
        openCards = Array(deck.prefix(EngineState.openCardSlots))
        deck.removeFirst(min(EngineState.openCardSlots, deck.count))
        for _ in 0..<EngineState.displaySpaces { display.append(draw()) }
    }

    public var players: Int { seats.count }
    /// Whose turn it is.
    public var mover: Int { turnsPlayed % players }

    /// The bag carries 35 refills; the 36th turn is played from the display
    /// and its refill is the one that fails. The round is played out.
    public var lastTurn: Int { roundOut(EngineState.turnsInTheBag + 1) }

    public var isOver: Bool { turnsPlayed >= min(lastTurn, endsAfter ?? .max) }

    func roundOut(_ turns: Int) -> Int { EngineState.roundOut(turns, players: players) }

    private mutating func draw() -> [Stone] {
        let three = Array(bag.prefix(3))
        bag.removeFirst(three.count)
        for stone in three { drawn[stone, default: 0] += 1 }
        return three
    }

    // MARK: - What a player knows

    /// What the player on this seat knows, as `EngineState` holds it: her
    /// own board and cards, the shared display and cards, the bag as counted
    /// — and of the others only what they took, for the end forecast. No
    /// foreign board, no foreign card. That is what the app gives Harmony,
    /// so an engine here plays as it would at a real table.
    public func view(for seat: Int, forecast: Bool) -> EngineState {
        let own = seats[seat]
        var state = EngineState(side: side, stacks: own.stacks, cubes: own.cubes,
                                hand: own.hand, display: display, openCards: openCards,
                                deck: deck, drawn: drawn, turnsPlayed: turnsPlayed,
                                players: players, seat: seat, endsAfter: endsAfter)
        if forecast {
            let others = seats.indices.filter { $0 != seat }
                .map { (seat: $0, turns: seats[$0].takes) }
            state.endForecast = EndForecast.forecast(
                taken: others, side: side, players: players,
                turnsPlayed: turnsPlayed, bag: state.bag).outcomes
        }
        return state
    }

    // MARK: - Playing a turn

    /// Plays the mover's turn, if the referee lets it. What comes back is
    /// what was wrong: with the turn itself — then nothing was changed — or
    /// with the table afterwards. Empty means all is well.
    public mutating func play(_ move: Move) -> [String] {
        let seat = mover
        let objections = Referee.check(move, by: seat, at: self)
        guard objections.isEmpty else { return objections }

        var player = seats[seat]
        let taken = display.remove(at: move.space)
        player.takes.append(taken)
        for (cell, added) in move.placements {
            player.stacks[cell, default: []].append(contentsOf: added)
        }
        if let name = move.cardTaken, let index = openCards.firstIndex(where: { $0.name == name }) {
            player.hand.append(HeldCard(card: openCards.remove(at: index)))
            if !deck.isEmpty { openCards.append(deck.removeFirst()) }
        }
        for (cell, name) in move.cubes {
            player.cubes[cell] = name
            if let index = player.hand.firstIndex(where: { $0.card.name == name }) {
                player.hand[index].cubesPlaced += 1
            }
        }
        seats[seat] = player

        turnsPlayed += 1
        if bag.count >= 3 { display.append(draw()) }
        // Her own board down to two free spaces ends the game once the
        // round is out — the same trigger the operator reports at a table.
        if endsAfter == nil, side.board.cells.count - player.stacks.count <= 2 {
            endsAfter = roundOut(turnsPlayed)
        }
        return Referee.audit(self)
    }

    // MARK: - The score

    public func landscape(of seat: Int) -> Int {
        BoardScoring(side: side, columns: side.columns, stacks: seats[seat].stacks)
            .breakdown().reduce(0) { $0 + $1.points }
    }

    public func cardPoints(of seat: Int) -> Int {
        seats[seat].hand.reduce(0) { $0 + $1.score }
    }

    public func score(of seat: Int) -> Int { landscape(of: seat) + cardPoints(of: seat) }
}
