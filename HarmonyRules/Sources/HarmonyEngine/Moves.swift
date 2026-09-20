import HarmonyRules

// Every turn Harmony could play from a position. `04-architektur.md`
// estimates ten thousand to a hundred thousand of them; `06-durchstich.md`
// has the measured figure.

/// One turn, as its result rather than as a sequence of actions. Two ways of
/// arriving at the same table are the same move, and the engine must not
/// weigh them twice.
public struct Move: Sendable, Hashable {
    /// Which display space is emptied. Spaces holding the same three stones
    /// are interchangeable — the display is a multiset, see
    /// `04-architektur.md` — so only the first of them is offered.
    public let space: Int
    /// Board space to the stones put there this turn, bottom first.
    public let placements: [Int: [Stone]]
    /// Cubes laid this turn: board space to the card they belong to.
    public let cubes: [Int: String]
    /// The card taken, if one was.
    public let cardTaken: String?

    public init(space: Int, placements: [Int: [Stone]],
                cubes: [Int: String] = [:], cardTaken: String? = nil) {
        self.space = space
        self.placements = placements
        self.cubes = cubes
        self.cardTaken = cardTaken
    }
}

public enum Moves {
    /// Every turn playable from this position.
    public static func all(from state: EngineState) -> [Move] {
        var moves: [Move] = []
        var offeredSpaces: Set<String> = []
        let anchors = standingHabitatCells(of: state)

        for (index, space) in state.display.enumerated() {
            // Two spaces with the same three stones are one choice.
            let signature = space.map(\.rawValue).sorted().joined()
            guard offeredSpaces.insert(signature).inserted else { continue }

            for laying in layings(of: space, on: state) {
                moves.append(contentsOf: turns(space: index, laying: laying,
                                               from: state, anchors: anchors))
            }
        }
        return moves
    }

    /// Spaces of patterns that already stand complete before the turn, with
    /// their cube not yet laid.
    ///
    /// Looking for cubes after every move would mean searching the whole
    /// board thousands of times. A pattern that was not complete before and
    /// is now has to contain a space the turn changed, so those spaces are
    /// enough to look at — except for the ones that were already standing,
    /// and those are found once here.
    public static func standingHabitatCells(of state: EngineState) -> [Int] {
        var cells: Set<Int> = []
        for held in state.hand where !held.isFinished {
            for habitat in Habitat.passed(of: held.card, through: state.stacks,
                                          cubes: state.cubeCells, board: state.board) {
                cells.formUnion(habitat.requirement.keys)
            }
        }
        for card in state.openCards {
            for habitat in Habitat.passed(of: card, through: state.stacks,
                                          cubes: state.cubeCells, board: state.board) {
                cells.formUnion(habitat.requirement.keys)
            }
        }
        return cells.sorted()
    }

    // MARK: - Where the three stones go

    /// One way of laying the three stones: the board once they are down,
    /// together with what went where.
    ///
    /// **Legung**, not Brett: a Spielbrett exists exactly once, while of
    /// these there are thousands per display space — and `Placement` is
    /// taken, it means a single stone on a single space. The level matters
    /// enough to have its own word: six turns share one laying, and
    /// everything that hangs on the board alone is worked out once for all
    /// six. See `docs/06-durchstich.md`.
    public struct Laying: Sendable {
        public var stacks: [Int: [Stone]]
        public var added: [Int: [Stone]]

        /// The spaces this laying changed, each with the **whole** stack
        /// that stands there now — what the candidates have to be grown
        /// forward over. At most three spaces, however many stones went on
        /// them.
        public var grown: [Int: [Stone]] {
            var out: [Int: [Stone]] = [:]
            out.reserveCapacity(added.count)
            for cell in added.keys { out[cell] = stacks[cell] }
            return out
        }
    }

    /// Every distinct laying the three stones can produce.
    ///
    /// The stones are laid in **colour order**, and that is not an arbitrary
    /// choice: every legal stack already stands in colour order, which
    /// `StackTests` pins. Since a stack is a sequence and not a set, there is
    /// exactly one order in which it can be built, and taking the stones in
    /// colour order builds every one of them. So each distinct result comes
    /// out exactly once, without enumerating orderings and throwing the
    /// duplicates away.
    public static func layings(of space: [Stone], on state: EngineState) -> [Laying] {
        let stones = space.sorted { $0.rawValue < $1.rawValue }
        let cells = state.board.cells.filter { !state.cubeCells.contains($0) }
        var results: [Laying] = []

        // Two stones of the same colour are interchangeable, so the second
        // may only go to a space at or after the first's. Without that, the
        // same table comes out once per way of dealing out equal stones.
        func step(_ current: Laying, _ left: ArraySlice<Stone>,
                  _ previous: (Stone, Int)?) {
            guard let stone = left.first else { results.append(current); return }
            for (index, cell) in cells.enumerated() {
                if let previous, previous.0 == stone, index < previous.1 { continue }
                let stack = current.stacks[cell] ?? []
                guard stack.placeable.contains(stone) else { continue }
                var next = current
                next.stacks[cell] = stack + [stone]
                next.added[cell, default: []].append(stone)
                step(next, left.dropFirst(), (stone, index))
            }
        }
        step(Laying(stacks: state.stacks, added: [:]), stones[...], nil)
        return results
    }

    // MARK: - Cards and cubes on top of that

    /// The turns that end with this laying: which card is taken, which cubes
    /// are laid.
    public static func turns(space: Int, laying: Laying, from state: EngineState,
                             anchors: [Int]) -> [Move] {
        var moves: [Move] = []

        // Taking no card, or one of the open ones. A card taken this turn can
        // still receive a cube in the same turn, so it takes part below.
        var options: [AnimalCard?] = [nil]
        if state.mayTakeACard { options += state.openCards.map { $0 } }

        // What the cards already in hand allow does not depend on which card
        // is taken, so it is worked out once instead of once per option.
        let fromHand = state.hand.filter { !$0.isFinished }.flatMap { held in
            cubePlaces(for: held, laying: laying, state: state, anchors: anchors)
        }

        for taken in options {
            var placeable = fromHand
            if let taken {
                placeable += cubePlaces(for: HeldCard(card: taken), laying: laying,
                                        state: state, anchors: anchors)
            }

            for chosen in cubeSets(placeable) {
                // A fifth card may only be taken while four are unfinished if
                // one of them is finished first, which laying its last cube
                // does. Rare, but it is a legal turn and the generator must
                // not swallow it.
                if taken != nil && !state.mayTakeACard {
                    let finishes = chosen.contains { place in
                        let held = state.hand.first { $0.card.name == place.card }
                        guard let held else { return false }
                        let now = chosen.count { $0.card == place.card }
                        return held.cubesPlaced + now >= held.card.points.count
                    }
                    guard finishes else { continue }
                }
                var cubes: [Int: String] = [:]
                for place in chosen { cubes[place.cell] = place.card }
                moves.append(Move(space: space, placements: laying.added,
                                  cubes: cubes, cardTaken: taken?.name))
            }
        }
        return moves
    }

    /// A cube that could be laid during this turn.
    struct CubePlace: Hashable {
        let card: String
        let cell: Int
        let habitat: Habitat
    }

    /// Where this card's next cube could go, given how the turn ends.
    ///
    /// The timing inside the turn needs no enumerating. Each space grows in
    /// one forced order, and a stone on one space never undoes another, so a
    /// pattern is complete at some moment exactly when every space of it
    /// **passes through** what it asks for. That is: what the pattern wants
    /// there is a beginning of what ends up there.
    ///
    /// The cube's own space is the exception — it may not grow past what the
    /// pattern wants, because a cube on a stone blocks anything going on top,
    /// and laying it earlier would make the space unbuildable.
    static func cubePlaces(for held: HeldCard, laying: Laying,
                           state: EngineState, anchors: [Int]) -> [CubePlace] {
        let touched = Array(Set(laying.added.keys).union(anchors)).sorted()
        return Habitat.passed(of: held.card, through: laying.stacks, cubes: state.cubeCells,
                              board: state.board, covering: touched)
            .map { CubePlace(card: held.card.name, cell: $0.cubeCell, habitat: $0) }
    }

    /// Which cubes are actually laid. Every choice is offered, the empty one
    /// included: laying a cube freezes its space for good, and keeping a
    /// space free for a later turn can be worth more than the points now.
    static func cubeSets(_ places: [CubePlace]) -> [[CubePlace]] {
        guard !places.isEmpty else { return [[]] }
        var sets: [[CubePlace]] = []

        func step(_ index: Int, _ chosen: [CubePlace]) {
            if index == places.count { sets.append(chosen); return }
            step(index + 1, chosen)                 // ohne diesen
            let place = places[index]
            let fits = chosen.allSatisfy { other in
                other.cell != place.cell
                    && Habitat.compatibility(other.habitat, place.habitat) != .conflict
            }
            if fits { step(index + 1, chosen + [place]) }
        }
        step(0, [])
        return sets
    }
}
