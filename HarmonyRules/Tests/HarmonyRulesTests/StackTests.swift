import Testing
@testable import HarmonyRules

/// The two rules the correction path leans on, from `05-ui.md`.
@Suite("Stapel und Steinbilanz")
struct StackTests {
    // MARK: - Zulässige Stapel

    @Test("Jeder zulässige Stapel steht in Farbreihenfolge")
    func everyLegalStackStandsInColourOrder() {
        // Darauf ruht die Zuggenerierung: Ein Stapel ist eine Folge, keine
        // Menge, es gibt also genau eine Reihenfolge, in der er gebaut
        // werden kann. Weil jeder zulässige Stapel zugleich in der
        // Reihenfolge der Steinkürzel steht, baut ein Generator, der die
        // drei Steine nach Farbe sortiert legt, jeden von ihnen — und jedes
        // Ergebnis genau einmal. Fällt diese Eigenschaft weg, muss
        // `Moves.layings` wieder Reihenfolgen aufzählen.
        for stack in [Stone].legal {
            #expect(stack == stack.sorted { $0.rawValue < $1.rawValue },
                    "\(stack.map(\.rawValue).joined())")
        }
    }

    @Test("Die vollständige Liste hat vierzehn Stapel")
    func fourteenLegalStacks() {
        // `regeln-basisspiel.md`: 6 einzelne, 6 Zweier, 2 Dreier.
        #expect([Stone].legal.count == 14)
    }

    @Test("Jeder einzelne Stein ist zulässig, auch rot und braun allein")
    func everySingleStoneIsLegal() {
        for stone in Stone.allCases { #expect([stone].isLegal) }
    }

    @Test("Auf Blau und Gelb kann nichts gestapelt werden")
    func nothingStacksOnWaterOrField() {
        #expect([Stone.water].placeable.isEmpty)
        #expect([Stone.field].placeable.isEmpty)
    }

    @Test("Drei braune Steine übereinander gibt es nicht")
    func noThreeBrowns() {
        #expect([Stone.wood, .wood, .wood].isLegal == false)
        #expect([Stone.wood, .wood].placeable == [.leaves])
    }

    @Test("SHW ist unmöglich und schon im zweiten Schritt unerreichbar")
    func mixedStackIsImpossible() {
        // Der Fall aus der Rückmeldung: Stein, Holz, Wasser.
        #expect([Stone.stone, .wood, .water].isLegal == false)
        #expect([Stone.stone].placeable.contains(.wood) == false)
    }

    @Test("Auf einen grauen Stein kommen nur Grau und Rot")
    func onGreyOnlyGreyOrRed() {
        #expect([Stone.stone].placeable == [.stone, .brick])
    }

    @Test("Die Liste ist präfixabgeschlossen")
    func legalStacksArePrefixClosed() {
        // Darauf beruht, dass die Palette in einem Schritt entscheiden
        // kann: Bauen von unten führt nie durch etwas Unausdrückbares.
        for stack in [Stone].legal {
            for length in 1..<stack.count {
                #expect(Array(stack.prefix(length)).isLegal,
                        "Präfix von \(stack.map(\.rawValue).joined()) fehlt")
            }
        }
    }

    @Test("Was die Palette anbietet, ist danach zulässig")
    func placeableStaysLegal() {
        for stack in [Stone].legal + [[]] {
            for stone in stack.placeable {
                #expect((stack + [stone]).isLegal)
            }
        }
    }

    // MARK: - Steinbilanz

    @Test("Ein Stein versetzt: die Bilanz geht auf")
    func movingAStoneKeepsTheBalance() {
        let before: [Int: [Stone]] = [43: [.wood, .wood]]
        let after: [Int: [Stone]] = [43: [.wood], 44: [.wood]]
        #expect(stoneBalance(from: before, to: after).isEmpty)
    }

    @Test("Ein Stein verschwunden: die Bilanz meldet ihn")
    func losingAStoneShows() {
        let before: [Int: [Stone]] = [43: [.wood, .wood]]
        let after: [Int: [Stone]] = [43: [.wood]]
        #expect(stoneBalance(from: before, to: after) == [.wood: -1])
    }

    @Test("Ein Stein erfunden: die Bilanz meldet ihn ebenso")
    func inventingAStoneShows() {
        let before: [Int: [Stone]] = [:]
        let after: [Int: [Stone]] = [11: [.stone]]
        #expect(stoneBalance(from: before, to: after) == [.stone: 1])
    }

    @Test("Ein Tausch zweier Farben meldet beide Seiten")
    func swappingColoursShowsBoth() {
        let before: [Int: [Stone]] = [11: [.stone], 12: [.field]]
        let after: [Int: [Stone]] = [11: [.field], 12: [.field]]
        #expect(stoneBalance(from: before, to: after) == [.stone: -1, .field: 1])
    }

    @Test("Umlegen über mehrere Felder bleibt ausgeglichen")
    func rearrangingManyStaysBalanced() {
        let before: [Int: [Stone]] = [11: [.stone, .stone, .stone], 12: [.water]]
        let after: [Int: [Stone]] = [11: [.stone], 21: [.stone, .stone], 13: [.water]]
        #expect(stoneBalance(from: before, to: after).isEmpty)
        #expect(stoneCounts(after)[.stone] == 3)
    }
}
