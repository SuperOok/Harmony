import Testing
import HarmonyRules
@testable import HarmonyEngine

/// When the others' boards might end the game, from the stones they took.
/// Storey one: the forecast is a plain function over what the log holds.
@Suite("Vorhersage des Spielendes")
struct EndForecastTests {
    private let bag = BagKnowledge(drawn: [.water: 6, .stone: 6, .wood: 6,
                                           .leaves: 6, .field: 6, .brick: 6])

    private func spread(_ turns: [[Stone]]) -> Spread {
        turns.reduce(Spread(size: 23)) { $0.after(known: $1) }
    }

    // MARK: - Was ein Stein belegt

    @Test("Blau und Gelb belegen immer ein Feld")
    func blueAndYellowAlwaysTakeASpace() {
        let board = spread(Array(repeating: [.water, .field, .water], count: 5))
        #expect(board.meanCells == 15)
        #expect(board.spreadCells == 0)
        #expect(board.chance(ofCells: 15) == 1)
    }

    @Test("Ohne Unterlage wird nicht gestapelt")
    func withoutABaseNothingStacks() {
        // Drei Grüne ohne Braun darunter: drei Bäume der Höhe eins, drei
        // Felder. Ebenso der erste braune Stein — er selbst ist die
        // Unterlage und liegt auf einem leeren Feld.
        #expect(spread([[.leaves, .leaves, .leaves]]).meanCells == 3)
        #expect(spread([[.wood, .water, .field]]).meanCells == 3)
    }

    @Test("Braun und Grün im selben Zug werden zum Baum")
    func brownAndGreenInOneTurnBecomeATree() {
        // Der braune Stein kommt zuerst, das Grün darauf mit 0,85.
        let tree = spread([[.wood, .leaves, .water]])
        #expect(abs(tree.meanCells - (3 - 0.85)) < 1e-12)
    }

    @Test("Ein Zug belegt nie mehr als drei Felder und nie weniger als eines")
    func aTurnTakesBetweenOneAndThreeSpaces() {
        for turn: [Stone] in [[.wood, .wood, .leaves], [.stone, .stone, .stone],
                              [.brick, .brick, .brick], [.water, .brick, .leaves]] {
            let board = spread([turn])
            let within = (1...3).reduce(0) { $0 + board.chance(ofCells: $1) }
            #expect(abs(within - 1) < 1e-12, "\(turn)")
        }
    }

    // MARK: - Nicht gemeldet heißt nicht voll

    @Test("Was nicht gemeldet wurde, ist nicht geschehen")
    func whatWasNotReportedHasNotHappened() {
        // Sechs Züge nur Blau und Gelb: 18 Felder. Dann Braun, Grün und
        // Blau: 20 Felder, oder 21, wenn das Grün flach lag. Auf Seite A ist
        // bei 21 Schluss — hätte sie dort gestanden, wäre es gemeldet worden.
        let turns = Array(repeating: [Stone.water, .field, .water], count: 6)
            + [[.wood, .leaves, .water]]
        let board = spread(turns)
        #expect(abs(board.chanceFull() - 0.15) < 1e-12)

        let open = board.notFull()
        #expect(open.chanceFull() == 0)
        #expect(abs(open.meanCells - 20) < 1e-12)
    }

    // MARK: - Die Vorhersage

    @Test("Wer nur flach legt, beendet die Partie bald")
    func whoeverLaysFlatEndsTheGameSoon() {
        // Zu dritt, die Mitspielerin auf Platz 0 hat fünf Züge lang nur Blau
        // und Gelb genommen: 15 Felder. Ihr nächster Zug ist der 16. der
        // Partie; füllt er den Plan, endet die Runde nach dem 18.
        let flat = Array(repeating: [Stone.water, .field, .water], count: 5)
        let forecast = EndForecast.forecast(taken: [(seat: 0, turns: flat)],
                                            side: .a, players: 3,
                                            turnsPlayed: 15, bag: bag)
        let total = forecast.outcomes.reduce(0) { $0 + $1.chance }
        #expect(total <= 1 + 1e-12)
        #expect(total > 0.9)
        #expect(forecast.outcomes.first!.endsAfter >= 18)
        // Sechs Felder in drei Zügen sind ihr nicht zu nehmen: spätestens
        // nach dem dritten eigenen Zug ist der Plan voll, auch wer stapelt,
        // belegt je Zug mindestens ein Feld.
        #expect(forecast.outcomes.allSatisfy { $0.endsAfter <= 36 })
        #expect(forecast.taken.first!.mean == 15)
    }

    @Test("Wer viel stapeln kann, braucht länger")
    func whoeverCanStackALotTakesLonger() {
        let flat = Array(repeating: [Stone.water, .field, .water], count: 6)
        let stacked = Array(repeating: [Stone.wood, .leaves, .brick], count: 6)
        func expected(_ turns: [[Stone]]) -> Double {
            let forecast = EndForecast.forecast(taken: [(seat: 0, turns: turns)],
                                                side: .a, players: 3,
                                                turnsPlayed: 18, bag: bag)
            return forecast.outcomes.reduce(0) { $0 + Double($1.endsAfter) * $1.chance }
                / max(forecast.outcomes.reduce(0) { $0 + $1.chance }, 1e-12)
        }
        #expect(expected(stacked) > expected(flat))
    }

    @Test("Zweimal dieselbe Vorhersage gibt zweimal dasselbe")
    func thesameForecastTwiceGivesTheSameTwice() {
        // Spät in der Partie, damit der Debug-Bau nicht lange rechnet: Was
        // hier geprüft wird, ist die Reihenfolge der Summen, nicht die Länge.
        let turns: [[Stone]] = [[.wood, .leaves, .brick], [.stone, .stone, .water],
                                [.wood, .wood, .field], [.brick, .stone, .leaves],
                                [.water, .field, .water], [.field, .water, .leaves]]
        let a = EndForecast.forecast(taken: [(seat: 0, turns: turns), (seat: 1, turns: turns)],
                                     side: .a, players: 3, turnsPlayed: 30, bag: bag)
        let b = EndForecast.forecast(taken: [(seat: 0, turns: turns), (seat: 1, turns: turns)],
                                     side: .a, players: 3, turnsPlayed: 30, bag: bag)
        #expect(!a.outcomes.isEmpty)
        #expect(a.outcomes == b.outcomes)
    }

    // MARK: - In der Bewertung

    /// Three players, Harmony on the last seat, twelve turns in, the board
    /// nearly empty: the known triggers leave her seven turns.
    private func harmony(_ forecast: [EndOutcome] = [],
                         endsAfter: Int? = nil) -> EngineState {
        EngineState(stacks: [11: [.stone]], drawn: [.stone: 6, .water: 6, .wood: 6],
                    turnsPlayed: 12, players: 3, seat: 2,
                    endsAfter: endsAfter, endForecast: forecast)
    }

    @Test("Eine Vorhersage verteilt die Restzüge, statt eine Zahl zu setzen")
    func aForecastSpreadsTheTurnsLeftRatherThanSettingOne() {
        // Halb und halb: Schluss nach dem 18. Zug, dann bleiben ihr die
        // Züge 14 und 17, oder keine fremde Beendigung.
        let plain = harmony()
        let forecast = harmony([EndOutcome(endsAfter: 18, chance: 0.5)])
        #expect(forecast.ownTurnsLeft == plain.ownTurnsLeft)
        let spread = forecast.withTurnsLeft { Array($0) }
        #expect(spread[2] == 0.5)
        #expect(spread[plain.ownTurnsLeft] == 0.5)

        // Das Budget rechnet vorsichtig: mit dem Wert, den sie mit drei zu
        // vier Chancen erreicht.
        #expect(forecast.ownTurnsBudgeted == 2)
        #expect(plain.ownTurnsBudgeted == plain.ownTurnsLeft)
    }

    @Test("Die Chance mit Vorhersage liegt zwischen den beiden Enden")
    func thechanceWithAForecastLiesBetweenBothEnds() {
        let need: [Stone: Int] = [.stone: 3, .brick: 2]
        let plain = Evaluator.chance(ofBuilding: need, state: harmony())
        let soon = Evaluator.chance(ofBuilding: need,
                                    state: harmony([EndOutcome(endsAfter: 18, chance: 1)]))
        let half = Evaluator.chance(ofBuilding: need,
                                    state: harmony([EndOutcome(endsAfter: 18, chance: 0.5)]))
        #expect(soon < half)
        #expect(half < plain)
        #expect(abs(half - (soon + plain) / 2) < 1e-12)
    }

    @Test("Ein gemeldetes Ende schlägt jede Vorhersage")
    func anAnnouncedEndBeatsAnyForecast() {
        let announced = harmony([EndOutcome(endsAfter: 30, chance: 1)], endsAfter: 15)
        #expect(announced.ownTurnsLeft == 1)
        #expect(announced.ownTurnsBudgeted == 1)
        let need: [Stone: Int] = [.stone: 2]
        #expect(Evaluator.chance(ofBuilding: need, state: announced)
                == Evaluator.chance(ofBuilding: need, state: harmony(endsAfter: 15)))
    }
}
