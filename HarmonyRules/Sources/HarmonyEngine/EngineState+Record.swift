import HarmonyRules

// Entering what has happened. `applying(_:)` looks ahead — it drops the
// emptied space and leaves the refill to the chance layer. These functions
// are for what **did** happen: someone took a space, and the table says what
// was drawn for it and which card moved up. The app calls them for every
// event it is told of.
//
// Everyone learns the same public facts by the same rules, whoever played:
// which space went, what came into it, which card was taken and which took
// its place. Only the board, the cubes and the hand are one player's own.

extension EngineState {
    /// What any player's turn does to what all of them know.
    ///
    /// - Parameters:
    ///   - space: the display space that was emptied.
    ///   - refill: the stones drawn for it. Empty once the bag is dry — the
    ///     space is then gone from the display, and an empty space is not
    ///     offered again: the search would weigh stones nobody can take.
    ///   - cardTaken: the open card that was taken, by name.
    ///   - cardDrawn: the card that moved up in its place, by name. Taken from
    ///     the cards no one had seen, and put where the taken one lay.
    /// - Returns: the card that was taken, so that the player who took it can
    ///   put it in her hand. `nil` if none was taken, or none of that name
    ///   lay open.
    @discardableResult
    public mutating func recordTurn(space: Int, refill: [Stone],
                                    cardTaken: String? = nil,
                                    cardDrawn: String? = nil) -> AnimalCard? {
        if display.indices.contains(space) {
            if refill.isEmpty {
                display.remove(at: space)
            } else {
                display[space] = refill
            }
        }
        for stone in refill { drawn[stone, default: 0] += 1 }

        var taken: AnimalCard?
        if let name = cardTaken, let index = openCards.firstIndex(where: { $0.name == name }) {
            taken = openCards[index]
            if let moved = cardDrawn, let position = deck.firstIndex(where: { $0.name == moved }) {
                openCards[index] = deck.remove(at: position)
            } else {
                openCards.remove(at: index)
            }
        }
        turnsPlayed += 1
        return taken
    }

    /// Her own turn: what everyone learns, and then her board.
    ///
    /// - Parameters:
    ///   - placements: the stones put on each space, bottom first.
    ///   - cubes: the cubes laid, space to the card they belong to.
    public mutating func recordOwnTurn(space: Int,
                                       placements: [Int: [Stone]],
                                       cubes laid: [Int: String],
                                       refill: [Stone],
                                       cardTaken: String? = nil,
                                       cardDrawn: String? = nil) {
        if let taken = recordTurn(space: space, refill: refill,
                                  cardTaken: cardTaken, cardDrawn: cardDrawn) {
            hand.append(HeldCard(card: taken))
        }
        for (cell, added) in placements {
            stacks[cell, default: []].append(contentsOf: added)
        }
        for (cell, card) in laid { cubes[cell] = card }
        recountCubes()
    }

    /// Störfall B: one space set to what really lies on the table. Not a
    /// turn — nothing is drawn, nobody has moved.
    ///
    /// - Parameters:
    ///   - stack: bottom first; empty clears the space.
    ///   - cube: the card the cube belongs to; `nil` for none.
    public mutating func correct(cell: Int, stack: [Stone], cube: String?) {
        stacks[cell] = stack.isEmpty ? nil : stack
        cubes[cell] = cube
        recountCubes()
    }

    /// How many cubes each held card carries, counted off the board. The
    /// board is the one place that says so — a cube stays where it lies, and
    /// a correction may move one from a card to another.
    public mutating func recountCubes() {
        for index in hand.indices {
            let name = hand[index].card.name
            hand[index].cubesPlaced = cubes.values.count { $0 == name }
        }
    }
}
