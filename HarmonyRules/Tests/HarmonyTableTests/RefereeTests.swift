import Testing
import HarmonyRules
import HarmonyEngine
@testable import HarmonyTable

/// The referee: what it lets through and what it stops. Every forbidden
/// turn here is one an engine with a fault in its move generator could
/// play, and would then look stronger than it is.
@Suite("Schiedsrichter")
struct RefereeTests {
    private let cards = AnimalCards.all

    private func card(_ name: String, _ pattern: [Int: PatternCell],
                      cube: Int, _ points: [Int] = [6, 13]) -> AnimalCard {
        AnimalCard(name: name, pattern: pattern, cube: cube, points: points)
    }

    /// Two players; the first to move has water everywhere but the named
    /// spaces, and the first display space holds the given stones.
    private func table(empty: Set<Int>, filled: [Int: [Stone]] = [:],
                       space: [Stone] = [.stone, .water, .water]) -> Table {
        var table = Table(side: .a, names: ["Anke", "Bernd"], cards: cards, seed: 7)
        var stacks: [Int: [Stone]] = [:]
        for cell in table.side.board.cells where !empty.contains(cell) && filled[cell] == nil {
            stacks[cell] = [.water]
        }
        for (cell, stack) in filled { stacks[cell] = stack }
        // The water above comes from nowhere, so this table fails the
        // balance; the tests using it ask the referee about turns only.
        table.seats[0].stacks = stacks
        table.display[0] = space
        return table
    }

    // MARK: - Der Tisch

    @Test("Ein frischer Tisch ist vollständig: 120 Steine, 32 Karten")
    func aFreshTableIsComplete() {
        let table = Table(side: .a, names: ["Anke", "Bernd", "Clara"], cards: cards, seed: 1)
        #expect(table.display.count == 5)
        #expect(table.display.allSatisfy { $0.count == 3 })
        #expect(table.openCards.count == 5)
        #expect(table.deck.count == Table.cardCount - 5)
        #expect(table.bag.count == Table.stoneCount - 15)
        #expect(Referee.audit(table).isEmpty)
    }

    @Test("Derselbe Startwert gibt denselben Tisch")
    func theSameSeedGivesTheSameTable() {
        let one = Table(side: .a, names: ["A", "B"], cards: cards, seed: 42)
        let two = Table(side: .a, names: ["A", "B"], cards: cards, seed: 42)
        #expect(one.display == two.display)
        #expect(one.bag == two.bag)
        #expect(one.openCards.map(\.name) == two.openCards.map(\.name))
    }

    @Test("Die Partie dauert höchstens 36 Züge, zu jeder Spielerzahl")
    func theGameLastsAtMost36Turns() {
        for players in 2...4 {
            let table = Table(side: .a, names: (0..<players).map { "S\($0)" },
                              cards: cards, seed: 1)
            #expect(table.lastTurn == 36)
        }
    }

    @Test("Eine Spielerin sieht nur ihren eigenen Spielplan")
    func aPlayerSeesOnlyHerOwnBoard() {
        var table = Table(side: .a, names: ["Anke", "Bernd"], cards: cards, seed: 3)
        table.seats[0].stacks = [11: [.water]]
        table.seats[1].stacks = [12: [.field]]
        #expect(table.view(for: 1, forecast: false).stacks == [12: [.field]])
        #expect(table.view(for: 0, forecast: false).stacks == [11: [.water]])
    }

    // MARK: - Was durchgeht

    @Test("Jeder Zug, den die Engine erzeugt, geht durch")
    func everyTurnTheEngineGeneratesPasses() {
        // Ein Muster, das sich in diesem Zug vollenden lässt, damit auch
        // Würfel und Kartennahme darunter sind.
        let meerkat = card("Erdmännchen", [11: .field, 12: .mountain1], cube: 12)
        var table = table(empty: [12, 13, 14], filled: [11: [.field]])
        table.openCards[0] = meerkat
        let moves = Moves.all(from: table.view(for: 0, forecast: false))
        #expect(moves.count > 10)
        #expect(moves.contains { !$0.cubes.isEmpty }, "auch Würfel werden geprüft")
        for move in moves {
            let objections = Referee.check(move, by: 0, at: table)
            #expect(objections.isEmpty, "\(move): \(objections)")
        }
    }

    @Test("Ein gespielter Zug lässt den Tisch stimmig")
    func aPlayedTurnLeavesTheTableConsistent() {
        var table = Table(side: .a, names: ["Anke", "Bernd"], cards: cards, seed: 5)
        let space = table.display[2]
        let cells = table.side.board.cells
        let move = Move(space: 2, placements: [cells[0]: [space[0]], cells[1]: [space[1]],
                                               cells[2]: [space[2]]],
                        cardTaken: table.openCards[1].name)
        let problems = table.play(move)
        #expect(problems.isEmpty, "\(problems)")
        #expect(table.turnsPlayed == 1)
        #expect(table.mover == 1)
        #expect(table.display.count == 5, "nachgefüllt")
        #expect(table.openCards.count == 5, "nachgerückt")
        #expect(table.seats[0].hand.count == 1)
        #expect(table.seats[0].takes == [space])
    }

    @Test("Wer den eigenen Spielplan füllt, beendet die Partie nach der Runde")
    func fillingOnesBoardEndsTheGameAfterTheRound() {
        var table = table(empty: [12, 13, 14], space: [.field, .field, .field])
        let move = Move(space: 0, placements: [12: [.field], 13: [.field], 14: [.field]])
        #expect(Referee.check(move, by: 0, at: table).isEmpty)
        _ = table.play(move)
        #expect(table.turnsPlayed == 1)
        #expect(table.endsAfter == 2, "die Runde wird zu Ende gespielt")
        #expect(!table.isOver)
    }

    // MARK: - Was nicht durchgeht

    @Test("Ein Auslagefeld, das es nicht gibt")
    func aDisplaySpaceThatDoesNotExist() {
        let table = table(empty: [12, 13, 14])
        let move = Move(space: 9, placements: [12: [.stone]])
        #expect(!Referee.check(move, by: 0, at: table).isEmpty)
    }

    @Test("Andere Steine, als im Feld lagen")
    func otherStonesThanLayInTheSpace() {
        let table = table(empty: [12, 13, 14])
        let move = Move(space: 0, placements: [12: [.brick], 13: [.water], 14: [.water]])
        #expect(Referee.check(move, by: 0, at: table).contains { $0.hasPrefix("Gelegt") })
    }

    @Test("Zwei Steine statt drei")
    func twoStonesInsteadOfThree() {
        let table = table(empty: [12, 13, 14])
        let move = Move(space: 0, placements: [12: [.stone], 13: [.water]])
        #expect(Referee.check(move, by: 0, at: table).contains { $0.hasPrefix("Gelegt") })
    }

    @Test("Ein Stapel, den es nicht gibt")
    func aStackThatCannotStand() {
        let table = table(empty: [12, 13])
        // Wasser auf Wasser — Feld 11 ist Wasser.
        let move = Move(space: 0, placements: [11: [.water], 12: [.stone], 13: [.water]])
        #expect(Referee.check(move, by: 0, at: table).contains { $0.contains("geht nicht") })
    }

    @Test("Ein Stein auf einem Tierwürfel")
    func aStoneOnACube() {
        var table = table(empty: [12, 13], filled: [14: [.stone]])
        table.seats[0].cubes[14] = "Irgendwer"
        let move = Move(space: 0, placements: [14: [.stone], 12: [.water], 13: [.water]])
        #expect(Referee.check(move, by: 0, at: table).contains { $0.contains("Tierwürfel") })
    }

    @Test("Ein Feld außerhalb des Spielplans")
    func aSpaceOffTheBoard() {
        let table = table(empty: [12, 13])
        let move = Move(space: 0, placements: [999: [.stone], 12: [.water], 13: [.water]])
        #expect(Referee.check(move, by: 0, at: table).contains { $0.contains("gibt es auf dem") })
    }

    @Test("Eine Karte, die nicht offen liegt")
    func aCardThatIsNotOpen() {
        let table = table(empty: [12, 13, 14])
        let move = Move(space: 0, placements: [12: [.stone], 13: [.water], 14: [.water]],
                        cardTaken: "Einhorn")
        #expect(Referee.check(move, by: 0, at: table).contains { $0.contains("nicht offen") })
    }

    @Test("Eine fünfte unfertige Karte")
    func aFifthUnfinishedCard() {
        var table = table(empty: [12, 13, 14])
        table.seats[0].hand = (1...4).map {
            HeldCard(card: card("Tot\($0)", [11: .tree3, 12: .tree3], cube: 12))
        }
        let move = Move(space: 0, placements: [12: [.stone], 13: [.water], 14: [.water]],
                        cardTaken: table.openCards[0].name)
        #expect(Referee.check(move, by: 0, at: table).contains { $0.contains("fünfte") })
    }

    @Test("Ein Würfel ohne Lebensraum")
    func aCubeWithoutAHabitat() {
        let meerkat = card("Erdmännchen", [11: .field, 12: .mountain1], cube: 12)
        var table = table(empty: [12, 13, 14])
        table.seats[0].hand = [HeldCard(card: meerkat)]
        // Grau auf 12, aber kein Feld daneben: Feld 11 ist Wasser.
        let move = Move(space: 0, placements: [12: [.stone], 13: [.water], 14: [.water]],
                        cubes: [12: "Erdmännchen"])
        #expect(Referee.check(move, by: 0, at: table).contains { $0.contains("Kein Lebensraum") })
    }

    @Test("Ein Würfel für eine Karte, die sie nicht hat")
    func aCubeForACardSheDoesNotHold() {
        let table = table(empty: [12, 13, 14], filled: [11: [.field]])
        let move = Move(space: 0, placements: [12: [.stone], 13: [.water], 14: [.water]],
                        cubes: [12: "Erdmännchen"])
        #expect(Referee.check(move, by: 0, at: table).contains { $0.contains("nicht bei ihr") })
    }

    @Test("Ein Würfel zu viel")
    func oneCubeTooMany() {
        let meerkat = card("Erdmännchen", [11: .field, 12: .mountain1], cube: 12, [6])
        var table = table(empty: [12, 13, 14], filled: [11: [.field], 15: [.stone]])
        table.seats[0].hand = [HeldCard(card: meerkat, cubesPlaced: 1)]
        table.seats[0].cubes[15] = "Erdmännchen"
        let move = Move(space: 0, placements: [12: [.stone], 13: [.water], 14: [.water]],
                        cubes: [12: "Erdmännchen"])
        #expect(Referee.check(move, by: 0, at: table).contains { $0.contains("keinen Würfel mehr") })
    }

    @Test("Wer nicht am Zug ist, spielt nicht")
    func whoeverIsNotToMoveDoesNotPlay() {
        let table = table(empty: [12, 13, 14])
        let move = Move(space: 0, placements: [12: [.stone], 13: [.water], 14: [.water]])
        #expect(Referee.check(move, by: 1, at: table) == ["Nicht am Zug."])
    }

    @Test("Ein abgewiesener Zug ändert nichts")
    func aRejectedTurnChangesNothing() {
        var table = table(empty: [12, 13, 14])
        let before = table.seats[0].stacks
        let move = Move(space: 0, placements: [12: [.brick], 13: [.water], 14: [.water]])
        #expect(!table.play(move).isEmpty)
        #expect(table.seats[0].stacks == before)
        #expect(table.turnsPlayed == 0)
    }

    @Test("Die Bilanz merkt einen verlorenen Stein")
    func theBalanceNoticesALostStone() {
        var table = Table(side: .a, names: ["Anke", "Bernd"], cards: cards, seed: 2)
        table.bag.removeLast()
        #expect(Referee.audit(table).contains { $0.contains("statt") })
    }

    @Test("Die Bilanz merkt eine doppelte Karte")
    func theBalanceNoticesADoubledCard() {
        var table = Table(side: .a, names: ["Anke", "Bernd"], cards: cards, seed: 2)
        table.seats[0].hand = [HeldCard(card: table.openCards[0])]
        #expect(Referee.audit(table).contains { $0.contains("Karten") })
    }
}
