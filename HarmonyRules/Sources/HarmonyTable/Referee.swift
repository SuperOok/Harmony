import Foundation
import HarmonyRules
import HarmonyEngine

/// Checks every turn against the whole table, before it is played, and the
/// table after it.
///
/// The engines generate their own turns and could only ever be checked
/// against themselves. The referee asks the rules directly wherever it can —
/// which stones lie in the space, whether a stack can stand, whether a card
/// lies open, whether a pattern stands — so that a fault in the move
/// generator shows up as an objection instead of as a quietly strong
/// player. Every answer is German, because it ends up in the log a person
/// reads.
public enum Referee {
    /// What is wrong with this turn. Empty means it may be played.
    public static func check(_ move: Move, by seat: Int, at table: Table) -> [String] {
        guard !table.isOver else { return ["Die Partie ist schon vorbei."] }
        guard seat == table.mover else { return ["Nicht am Zug."] }
        guard table.display.indices.contains(move.space) else {
            return ["Auslagefeld \(move.space) gibt es nicht — es liegen \(table.display.count)."]
        }

        var objections: [String] = []
        let player = table.seats[seat]
        let board = table.side.board

        // The three stones of the space, all of them, and nothing else.
        let offered = table.display[move.space].map(\.rawValue).sorted()
        let placed = move.placements.values.flatMap { $0 }.map(\.rawValue).sorted()
        if placed != offered {
            objections.append("Gelegt \(placed.joined()), im Auslagefeld lagen \(offered.joined()).")
        }

        // Every stone onto a space that exists, carries no cube, and takes it.
        var stacks = player.stacks
        for (cell, added) in move.placements.sorted(by: { $0.key < $1.key }) {
            guard board.contains(cell) else {
                objections.append("Feld \(cell) gibt es auf dem Spielplan nicht.")
                continue
            }
            if player.cubes[cell] != nil {
                objections.append("Feld \(cell) trägt schon einen Tierwürfel.")
            }
            var stack = stacks[cell] ?? []
            for stone in added {
                guard stack.placeable.contains(stone) else {
                    objections.append("\(stone.name) auf \(stack.map(\.rawValue).joined()) "
                                      + "(Feld \(cell)) geht nicht.")
                    break
                }
                stack.append(stone)
            }
            stacks[cell] = stack
        }

        // The card: open, and a free space for it.
        var hand = player.hand
        if let name = move.cardTaken {
            if let card = table.openCards.first(where: { $0.name == name }) {
                hand.append(HeldCard(card: card))
            } else {
                objections.append("\(name) liegt nicht offen aus.")
            }
        }

        // The cubes: a held card with cubes left, a free space, a pattern.
        let before = Set(player.cubes.keys)
        var laid: [String: Int] = [:]
        for (cell, name) in move.cubes.sorted(by: { $0.key < $1.key }) {
            guard let held = hand.first(where: { $0.card.name == name }) else {
                objections.append("Würfel für \(name), aber die Karte liegt nicht bei ihr.")
                continue
            }
            if before.contains(cell) {
                objections.append("Feld \(cell) trägt schon einen Tierwürfel.")
            }
            laid[name, default: 0] += 1
            if held.cubesPlaced + laid[name]! > held.card.points.count {
                objections.append("\(name) hat keinen Würfel mehr frei.")
            }
            if !patternStands(for: held.card, cube: cell, stacks: stacks,
                              before: player.stacks, cubes: before, board: board) {
                objections.append("Kein Lebensraum von \(name) mit Würfel auf Feld \(cell).")
            }
        }

        // A fifth card only if one of the four is finished in the same turn.
        if move.cardTaken != nil, player.unfinished >= EngineState.cardLimit {
            let finishes = player.hand.contains { held in
                !held.isFinished
                    && held.cubesPlaced + (laid[held.card.name] ?? 0) >= held.card.points.count
            }
            if !finishes {
                objections.append("Vier unfertige Karten — eine fünfte darf sie nicht nehmen.")
            }
        }
        return objections
    }

    /// Whether the card's pattern stands with its cube on this space.
    ///
    /// Asked of the finished board first, which needs nothing but the
    /// pattern search. Only where that fails is the moment inside the turn
    /// asked for — a pattern complete while the stones went down and then
    /// built over — and that answer comes from the same function the move
    /// generator uses, so it is not an independent one.
    static func patternStands(for card: AnimalCard, cube cell: Int,
                              stacks: [Int: [Stone]], before: [Int: [Stone]],
                              cubes: Set<Int>, board: Board) -> Bool {
        let standing = Habitat.all(of: card, covering: cell, on: stacks, cubes: cubes, board: board)
        if standing.contains(where: { $0.missing.isEmpty && $0.cubeCell == cell }) { return true }
        return Habitat.passed(of: card, through: stacks, from: before, cubes: cubes,
                              board: board, covering: [cell])
            .contains { $0.cubeCell == cell }
    }

    /// What does not add up on the table as a whole. Empty means consistent.
    ///
    /// The full balance from `pruefverfahren.md`, which Harmony herself can
    /// never check because she does not see the other boards: every stone
    /// is on a board, in the display or in the bag, and every card lies
    /// open, face down or with a player — each exactly once.
    public static func audit(_ table: Table) -> [String] {
        var problems: [String] = []

        var counts: [Stone: Int] = [:]
        for seat in table.seats {
            for (stone, n) in stoneCounts(seat.stacks) { counts[stone, default: 0] += n }
        }
        for space in table.display { for stone in space { counts[stone, default: 0] += 1 } }
        for stone in table.bag { counts[stone, default: 0] += 1 }
        for stone in Stone.allCases where counts[stone] ?? 0 != BagKnowledge.total[stone] ?? 0 {
            problems.append("\(stone.name): \(counts[stone] ?? 0) statt \(BagKnowledge.total[stone] ?? 0).")
        }

        let names = table.openCards.map(\.name) + table.deck.map(\.name)
            + table.seats.flatMap { $0.hand.map(\.card.name) }
        if names.count != Table.cardCount || Set(names).count != names.count {
            problems.append("\(names.count) Karten, \(Set(names).count) verschiedene — "
                            + "es sind \(Table.cardCount).")
        }
        if table.openCards.count > EngineState.openCardSlots { problems.append("\(table.openCards.count) offene Karten.") }

        for seat in table.seats {
            for (cell, stack) in seat.stacks where !stack.isLegal {
                problems.append("\(seat.name): Stapel \(stack.map(\.rawValue).joined()) auf Feld \(cell).")
            }
            for (cell, _) in seat.cubes where seat.stacks[cell] == nil {
                problems.append("\(seat.name): Würfel auf leerem Feld \(cell).")
            }
            for held in seat.hand where seat.cubes.values.count(where: { $0 == held.card.name })
                != held.cubesPlaced {
                problems.append("\(seat.name): \(held.card.name) zählt \(held.cubesPlaced) Würfel.")
            }
            if seat.unfinished > EngineState.cardLimit {
                problems.append("\(seat.name): \(seat.unfinished) unfertige Karten.")
            }
            if seat.takes.count * 3 != seat.stacks.values.reduce(0, { $0 + $1.count }) {
                problems.append("\(seat.name): \(seat.takes.count) Züge, aber "
                                + "\(seat.stacks.values.reduce(0) { $0 + $1.count }) Steine.")
            }
        }
        return problems
    }
}
