import Testing
import HarmonyRules
import HarmonyEngine
@testable import HarmonyTable

/// Two independent routes to the same knowledge. The table knows everything
/// and hands a player her view (`Table.view(for:)`); the app is told each
/// event and enters it (`EngineState.recordTurn`, `recordOwnTurn`). Played
/// through the same game, both must end with the same view — up to the order
/// in which the table lays out its display and its open cards, which the
/// table appends and the entry puts in place.
@Suite("Eintragen gegen den Tisch")
struct RecordEquivalenceTests {
    private let cards = AnimalCards.all

    /// The turn `index` of a game: some space, some laying, and every third
    /// turn a card if one may be taken. Deterministic, and legal because the
    /// engine's own generator makes it.
    private func move(at index: Int, on table: Table) -> Move? {
        let view = table.view(for: table.mover, forecast: false)
        guard !view.display.isEmpty else { return nil }
        let space = (index * 3) % view.display.count
        let layings = Moves.layings(of: view.display[space], on: view)
        guard !layings.isEmpty else { return nil }
        let laying = layings[(index * 7919) % layings.count]
        let turns = Moves.turns(space: space, laying: laying, from: view,
                                anchors: Moves.standingHabitatCells(of: view))
        if index % 3 == 0, let withCard = turns.first(where: { $0.cardTaken != nil }) {
            return withCard
        }
        return turns.first
    }

    /// Order-free: a space is a multiset of stones, the display a multiset of
    /// spaces.
    private func shape(_ display: [[Stone]]) -> [String] {
        display.map { $0.map(\.rawValue).sorted().joined() }.sorted()
    }

    private func compare(_ known: EngineState, _ view: EngineState, turn: Int,
                         sourceLocation: SourceLocation = #_sourceLocation) {
        let at = "nach Zug \(turn)"
        #expect(shape(known.display) == shape(view.display), Comment(rawValue: "Auslage \(at)"), sourceLocation: sourceLocation)
        #expect(known.openCards.map(\.name).sorted() == view.openCards.map(\.name).sorted(),
                Comment(rawValue: "offene Karten \(at)"), sourceLocation: sourceLocation)
        #expect(known.deck.map(\.name) == view.deck.map(\.name),
                Comment(rawValue: "Stapel \(at)"), sourceLocation: sourceLocation)
        #expect(known.drawn == view.drawn, Comment(rawValue: "Beutel \(at)"), sourceLocation: sourceLocation)
        #expect(known.turnsPlayed == view.turnsPlayed, Comment(rawValue: "Zugzahl \(at)"), sourceLocation: sourceLocation)
        #expect(known.stacks == view.stacks, Comment(rawValue: "Brett \(at)"), sourceLocation: sourceLocation)
        #expect(known.cubes == view.cubes, Comment(rawValue: "Würfel \(at)"), sourceLocation: sourceLocation)
        #expect(known.hand.map(\.card.name) == view.hand.map(\.card.name),
                Comment(rawValue: "Hand \(at)"), sourceLocation: sourceLocation)
        #expect(known.hand.map(\.cubesPlaced) == view.hand.map(\.cubesPlaced),
                Comment(rawValue: "Würfel je Karte \(at)"), sourceLocation: sourceLocation)
    }

    @Test("Eine Partie, eingetragen, ergibt Zug für Zug dieselbe Sicht wie der Tisch",
          arguments: [2, 3, 4], [0, 1])
    func aGameEnteredGivesTheTablesViewTurnForTurn(players: Int, seat: Int) {
        var table = Table(side: .a, names: (0..<players).map { "S\($0)" },
                          cards: cards, seed: UInt64(100 + players * 10 + seat))
        var known = table.view(for: seat, forecast: false)
        compare(known, table.view(for: seat, forecast: false), turn: 0)

        var played = 0
        var tookCards = 0
        while !table.isOver, let move = move(at: played, on: table) {
            let mover = table.mover
            let deckBefore = table.deck
            let displayCount = table.display.count
            // An event names the space by what lay on it — the table's own
            // index says nothing about where the entry keeps that space.
            let taken = table.display[move.space].map(\.rawValue).sorted()
            let space = known.display.firstIndex { $0.map(\.rawValue).sorted() == taken }!
            #expect(table.play(move).isEmpty, "Zug \(played + 1) muss der Schiedsrichter durchlassen")

            // What the table then says: what was drawn, which card moved up.
            let refill = table.display.count == displayCount ? Array(table.display.last!) : []
            let moved = move.cardTaken != nil && !deckBefore.isEmpty ? table.openCards.last?.name : nil
            if move.cardTaken != nil { tookCards += 1 }

            if mover == seat {
                known.recordOwnTurn(space: space, placements: move.placements,
                                    cubes: move.cubes, refill: refill,
                                    cardTaken: move.cardTaken, cardDrawn: moved)
            } else {
                known.recordTurn(space: space, refill: refill,
                                 cardTaken: move.cardTaken, cardDrawn: moved)
            }
            played += 1
            compare(known, table.view(for: seat, forecast: false), turn: played)
        }
        #expect(played >= 12, "die Partie muss lange genug laufen, um etwas zu zeigen")
        #expect(tookCards > 0, "es muss auch Karten gegeben haben")
    }
}
