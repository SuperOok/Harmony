import Testing
import HarmonyRules
@testable import HarmonyEngine

/// What Harmony knows between two of her turns, and what she can work out
/// from it. Storey one: plain functions over data structures.
@Suite("Zustand der Engine")
struct EngineStateTests {
    private func card(_ name: String, _ points: [Int]) -> AnimalCard {
        AnimalCard(name: name, pattern: [11: .field, 12: .mountain1],
                   cube: 12, points: points)
    }

    // MARK: - Beutelwissen

    @Test("Die sechs Farben ergeben zusammen hundertzwanzig Steine")
    func thesixColoursMakeAHundredAndTwenty() {
        #expect(BagKnowledge.total.values.reduce(0, +) == 120)
        #expect(BagKnowledge.total[.water] == 23)
        #expect(BagKnowledge.total[.brick] == 15)
    }

    @Test("Nach dem Aufbau liegen hundertfünf im Beutel")
    func ahundredAndFiveAreInTheBagAfterSetup() {
        // `regeln-basisspiel.md`: 120 minus die 15 der Startauslage.
        let drawn: [Stone: Int] = [.water: 3, .stone: 3, .wood: 3, .leaves: 3, .field: 3]
        #expect(BagKnowledge(drawn: drawn).count == 105)
    }

    @Test("Das Beutelwissen ist eine Rechnung, keine Schätzung")
    func whatIsInTheBagIsArithmeticAndNotAGuess() {
        let bag = BagKnowledge(drawn: [.brick: 15])
        #expect(bag.remaining(.brick) == 0)
        #expect(bag.chance(of: .brick) == 0)
        #expect(bag.remaining(.water) == 23)
    }

    @Test("Die Wahrscheinlichkeit einer Farbe ist ihr Anteil am Rest")
    func thechanceOfAColourIsItsShareOfWhatIsLeft() {
        // Nur noch Grau und Rot im Beutel: 23 zu 15.
        var drawn: [Stone: Int] = [:]
        for stone in [Stone.water, .wood, .leaves, .field] {
            drawn[stone] = BagKnowledge.total[stone]
        }
        let bag = BagKnowledge(drawn: drawn)
        #expect(bag.count == 38)
        #expect(abs(bag.chance(of: .stone) - 23.0 / 38.0) < 1e-12)
        #expect(abs(bag.chance(of: .water)) < 1e-12)
    }

    // MARK: - Karten in der Hand

    @Test("Gewertet wird die höchste sichtbare Zahl")
    func thehighestVisibleNumberIsWhatCounts() {
        // Das Beispiel aus `regeln-basisspiel.md`: Pinguine, 4 / 10 / 16.
        let penguin = card("Pinguin", [4, 10, 16])
        #expect(HeldCard(card: penguin, cubesPlaced: 0).score == 0)
        #expect(HeldCard(card: penguin, cubesPlaced: 1).score == 4)
        #expect(HeldCard(card: penguin, cubesPlaced: 2).score == 10)
        #expect(HeldCard(card: penguin, cubesPlaced: 3).score == 16)
    }

    @Test("Der Zuwachs des nächsten Würfels ist nicht die Kartensumme")
    func whatThenextCubeAddsIsNotTheCardsTotal() {
        // `04-architektur.md` besteht auf dem Zuwachs: Karten sind über ihre
        // Gesamtpunktzahl nicht vergleichbar.
        let penguin = card("Pinguin", [4, 10, 16])
        #expect(HeldCard(card: penguin, cubesPlaced: 0).nextCubeGain == 4)
        #expect(HeldCard(card: penguin, cubesPlaced: 1).nextCubeGain == 6)
        #expect(HeldCard(card: penguin, cubesPlaced: 2).nextCubeGain == 6)
        #expect(HeldCard(card: penguin, cubesPlaced: 3).nextCubeGain == nil)
    }

    @Test("Eine abgeschlossene Karte zählt nicht mehr gegen die Grenze von vier")
    func afinishedCardStopsCountingAgainstTheLimitOfFour() {
        let done = HeldCard(card: card("Fertig", [5, 9]), cubesPlaced: 2)
        let open = HeldCard(card: card("Offen", [5, 9]), cubesPlaced: 1)
        #expect(done.isFinished)
        #expect(!open.isFinished)

        var state = EngineState(hand: [done, open, open, open, open])
        #expect(state.unfinishedCards.count == 4)
        #expect(!state.mayTakeACard)

        state.hand = [done, done, open, open, open]
        #expect(state.mayTakeACard)
    }

    // MARK: - Restlaufzeit

    @Test("Der Beutel trägt fünfunddreißig Züge")
    func thebagCarriesThirtyFiveTurns() {
        // `regeln-basisspiel.md` rechnet es vor: 105 durch 3.
        #expect(EngineState.turnsInTheBag == 35)
        #expect(EngineState(turnsPlayed: 0).turnsLeftInGame == 35)
        #expect(EngineState(turnsPlayed: 35).turnsLeftInGame == 0)
        #expect(EngineState(turnsPlayed: 40).turnsLeftInGame == 0)
    }

    @Test("Von den verbleibenden Zügen gehört Harmony nur jeder soundsovielte")
    func onlyEveryNthOfTheRemainingTurnsIsHers() {
        // Drei Spielerinnen, Harmony auf dem dritten Platz: die Züge 2, 5,
        // 8 … der Partie sind ihre.
        let state = EngineState(turnsPlayed: 0, players: 3, seat: 2)
        #expect(state.ownTurnsInTheBag == 11)      // 2, 5, 8 … 32, also elf
        #expect(state.ownTurnsPlayed == 0)
        #expect(EngineState(turnsPlayed: 33, players: 3, seat: 2).ownTurnsInTheBag == 0)
        #expect(EngineState(turnsPlayed: 0, players: 1, seat: 0).ownTurnsInTheBag == 35)
        #expect(EngineState(turnsPlayed: 34, players: 3, seat: 2).ownTurnsPlayed == 11)
    }

    @Test("Der eigene Spielplan endet die Partie früher als der Beutel")
    func herOwnBoardRunsOutBeforeTheBagDoes() {
        // Leeres Brett, Seite A: 23 Felder, Schluss bei 21 belegten, drei
        // Steine je Zug — sieben eigene Züge. Der Beutel verspricht elf.
        let empty = EngineState(turnsPlayed: 0, players: 3, seat: 2)
        #expect(empty.ownTurnsUntilFull == 7)
        #expect(empty.ownTurnsLeft == 7)

        // Wer stapelt, verbraucht weniger Felder und hat länger Zeit. Nach
        // zwei eigenen Zügen liegen sechs Steine, aber nur drei Felder sind
        // belegt: anderthalb je Zug, also achtzehn zu füllende Felder in
        // zwölf Zügen — gedeckelt auf die neun, die der Beutel noch hergibt.
        let board = BoardSide.a.board
        let stacked = EngineState(stacks: Dictionary(uniqueKeysWithValues:
                                      board.cells.prefix(3).map { ($0, [Stone.wood, .leaves]) }),
                                  turnsPlayed: 6, players: 3, seat: 2)
        #expect(stacked.ownTurnsPlayed == 2)
        #expect(stacked.ownTurnsUntilFull == 12)
        #expect(stacked.ownTurnsInTheBag == 9)
        #expect(stacked.ownTurnsLeft == 9)
    }

    // MARK: - Das Brett

    @Test("Zwei oder weniger freie Felder beenden die Partie")
    func twoOrFewerFreeSpacesEndTheGame() {
        var stacks: [Int: [Stone]] = [:]
        let board = BoardSide.a.board
        for cell in board.cells.prefix(20) { stacks[cell] = [.field] }
        var state = EngineState(stacks: stacks)
        #expect(state.freeCells == 3)
        #expect(!state.boardIsFull)

        stacks[board.cells[20]] = [.field]
        state.stacks = stacks
        #expect(state.freeCells == 2)
        #expect(state.boardIsFull)
    }

    @Test("Ein Würfel friert sein Feld ein, und der Zustand sagt welche")
    func acubeFreezesItsSpaceAndTheStateSaysWhich() {
        let state = EngineState(stacks: [11: [.field], 12: [.stone]],
                                cubes: [12: "Erdmännchen"],
                                hand: [HeldCard(card: card("Erdmännchen", [2, 5]), cubesPlaced: 1)])
        #expect(state.cubeCells == [12])
        #expect(state.cubesPlaced == 1)
    }

    // MARK: - Der Zustand prüft sich selbst

    @Test("Ein stimmiger Zustand meldet nichts")
    func aconsistentStateReportsNothing() {
        let meerkat = card("Erdmännchen", [2, 5, 9, 14])
        let state = EngineState(stacks: [11: [.field], 12: [.stone]],
                                cubes: [12: "Erdmännchen"],
                                hand: [HeldCard(card: meerkat, cubesPlaced: 1)],
                                display: [[.water, .water, .field]],
                                openCards: [card("Otter", [3, 8])],
                                drawn: [.water: 6, .field: 6, .stone: 3],
                                turnsPlayed: 0)
        #expect(state.inconsistencies.isEmpty, "\(state.inconsistencies)")
    }

    @Test("Mehr Steine einer Farbe, als es gibt, fällt auf")
    func morestonesOfAColourThanExistIsNoticed() {
        let state = EngineState(drawn: [.brick: 16], turnsPlayed: 35)
        #expect(state.inconsistencies.contains { $0.contains("Ziegel") })
    }

    @Test("Mehr gezogene Steine, als Züge gespielt wurden, fällt auf")
    func morestonesDrawnThanTurnsPlayedIsNoticed() {
        let state = EngineState(drawn: [.water: 23, .stone: 23], turnsPlayed: 0)
        #expect(state.inconsistencies.contains { $0.contains("höchstens") })
    }

    @Test("Ein Stapel, den es nicht gibt, fällt auf")
    func astackThatCannotExistIsNoticed() {
        let state = EngineState(stacks: [11: [.stone, .wood, .water]])
        #expect(state.inconsistencies.contains { $0.contains("gibt es nicht") })
    }

    @Test("Ein Würfel ohne Stein darunter fällt auf")
    func acubeWithNoStoneUnderItIsNoticed() {
        let state = EngineState(cubes: [11: "Erdmännchen"],
                                hand: [HeldCard(card: card("Erdmännchen", [2, 5]), cubesPlaced: 1)])
        #expect(state.inconsistencies.contains { $0.contains("leerem Feld") })
    }

    @Test("Ein Würfel einer Karte, die gar nicht hier liegt, fällt auf")
    func acubeOfACardThatIsNotHereIsNoticed() {
        let state = EngineState(stacks: [11: [.stone]], cubes: [11: "Fremdtier"])
        #expect(state.inconsistencies.contains { $0.contains("Fremdtier") })
    }

    @Test("Eine Karte, die mehr Würfel zählt als auf dem Brett liegen, fällt auf")
    func acardCountingMoreCubesThanLieOnTheBoardIsNoticed() {
        let state = EngineState(stacks: [11: [.stone]],
                                cubes: [11: "Erdmännchen"],
                                hand: [HeldCard(card: card("Erdmännchen", [2, 5]), cubesPlaced: 2)])
        #expect(state.inconsistencies.contains { $0.contains("gezählt") })
    }

    @Test("Eine Karte, die zweimal vorkommt, fällt auf")
    func acardAppearingTwiceIsNoticed() {
        let otter = card("Otter", [3, 8])
        let state = EngineState(hand: [HeldCard(card: otter)], openCards: [otter])
        #expect(state.inconsistencies.contains { $0.contains("doppelt") })
    }

    // MARK: - An den echten Karten

    @Test("Ein Aufbau aus dem echten Stapel ist stimmig")
    func asetupFromTheRealDeckIsConsistent() throws {
        let deck = try AnimalCards.load()
        #expect(deck.count == 32)
        let state = EngineState(display: Array(repeating: [.water, .stone, .wood], count: 5),
                                openCards: Array(deck.prefix(5)),
                                deck: Array(deck.dropFirst(5)),
                                drawn: [.water: 5, .stone: 5, .wood: 5],
                                turnsPlayed: 0)
        #expect(state.inconsistencies.isEmpty, "\(state.inconsistencies)")
        #expect(state.reachableCards.count == 32)
        #expect(state.mayTakeACard)
    }
}
