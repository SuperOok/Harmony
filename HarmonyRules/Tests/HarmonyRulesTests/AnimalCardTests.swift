import Testing
@testable import HarmonyRules

/// The card data, checked where it can be checked. `04-architektur.md` names
/// six conditions and asks for them here, implemented apart from
/// `tools/pruefe-tierkarten.py`, which checks the same file in Python.
///
/// The form classes at the end are the one target value that does not come
/// out of the data: they were found by hand while capturing and are written
/// down in `docs/06-durchstich.md`.
@Suite("Tierkarten")
struct AnimalCardTests {
    /// The template from `kartennotation.md`: four columns of three.
    private let template = Board(columns: [3, 3, 3, 3])

    private var cards: [AnimalCard] {
        get throws { try AnimalCards.load() }
    }

    // MARK: - Die sechs Bedingungen aus Phase 4

    @Test("Die Datei enthält zweiunddreißig Karten")
    func thirtyTwoCards() throws {
        #expect(try cards.count == 32)
    }

    @Test("Jede Musterzelle nennt eine bekannte Landschaft")
    func everyPatternCellNamesAKnownLandscape() throws {
        // Unbekannte Wörter kommen gar nicht erst durch das Laden; dass es
        // durchläuft, ist die Aussage. Der Fehler nennt sonst Karte und Zelle.
        #expect(throws: Never.self) { try AnimalCards.load() }
    }

    @Test("Jedes Muster liegt in der Schablone")
    func everyPatternFitsTheTemplate() throws {
        for card in try cards {
            for cell in card.pattern.keys {
                #expect(template.contains(cell), "\(card.name): Zelle \(cellName(cell))")
            }
        }
    }

    @Test("Jedes Muster hängt zusammen")
    func everyPatternIsConnected() throws {
        for card in try cards {
            let cells = Set(card.pattern.keys)
            var reached: Set<Int> = [cells.min()!]
            var frontier = [cells.min()!]
            while let cell = frontier.popLast() {
                for neighbour in template.neighbours(cell)
                where cells.contains(neighbour) && !reached.contains(neighbour) {
                    reached.insert(neighbour); frontier.append(neighbour)
                }
            }
            #expect(reached == cells,
                    "\(card.name): \(cells.subtracting(reached).map(cellName)) hängt ab")
        }
    }

    @Test("Die Würfelzelle kommt im Muster vor")
    func theCubeSitsOnAPatternCell() throws {
        for card in try cards {
            #expect(card.pattern[card.cube] != nil,
                    "\(card.name): Würfel auf \(cellName(card.cube))")
        }
    }

    @Test("Jede Punktleiste steigt streng")
    func everyPointsListRisesStrictly() throws {
        for card in try cards {
            #expect(card.points == card.points.sorted() && Set(card.points).count == card.points.count,
                    "\(card.name): \(card.points)")
        }
    }

    @Test("Die Namen sind eindeutig")
    func theNamesAreUnique() throws {
        let names = try cards.map(\.name)
        #expect(Set(names).count == names.count)
    }

    // MARK: - Was beim Erfassen beobachtet wurde

    @Test("Jede Karte trägt zwei bis fünf Tierwürfel")
    func everyCardCarriesTwoToFiveCubes() throws {
        // `kartennotation.md`: beobachtet wurden 3 und 4, laut Hauke bis 5.
        for card in try cards {
            #expect((2...5).contains(card.points.count),
                    "\(card.name): \(card.points.count)")
        }
    }

    @Test("Keine zwei Karten sind dieselbe Karte")
    func noTwoCardsAreTheSameCard() throws {
        var seen: [String: String] = [:]
        for card in try cards {
            let signature = card.pattern.keys.sorted()
                .map { "\($0)=\(card.pattern[$0]!.rawValue)" }
                .joined(separator: " ") + " T\(card.cube) P\(card.points)"
            #expect(seen[signature] == nil, "\(card.name) gleicht \(seen[signature] ?? "")")
            seen[signature] = card.name
        }
    }

    // MARK: - Die fünf Formklassen

    /// The target value from `docs/06-durchstich.md`, written out. It was
    /// found at the table, not computed — which is the whole point: a value
    /// that came out of a program run would only say what the program does.
    private static let formClasses: [(cells: [Int], cards: Set<String>)] = [
        ([11, 12], ["Erdmännchen", "Frosch", "Marienkäfer", "Koala", "Ente",
                    "Lachs", "Fledermaus", "Schwein", "Adler", "Eichhörnchen"]),
        ([11, 12, 13], ["Wüstenfuchs", "Otter", "Hase", "Echse", "Lama",
                        "Panther", "Krokodil"]),
        ([11, 12, 21], ["Rochen", "Flamingo", "Affe", "Papagei", "Bär",
                        "Wolf", "Igel"]),
        ([12, 21, 32], ["Pinguin", "Eisfuchs", "Pfau", "Maus", "Eisvogel", "Rabe"]),
        ([12, 21, 22, 32], ["Waschbär", "Biene"]),
    ]

    @Test("Alle zweiunddreißig Karten fallen in die fünf erfassten Formen")
    func allThirtyTwoFallIntoTheFiveRecordedShapes() throws {
        var grouped: [HexShape: Set<String>] = [:]
        for card in try cards { grouped[card.shape, default: []].insert(card.name) }

        #expect(grouped.count == 5, "\(grouped.count) Formen statt fünf")

        for (cells, expected) in Self.formClasses {
            let shape = HexShape.canonical(of: cells)
            #expect(grouped[shape] == expected,
                    "Form \(cells): \(grouped[shape]?.sorted() ?? []) statt \(expected.sorted())")
        }
    }

    @Test("Die Lage des Würfels folgt der Form")
    func whereTheCubeSitsFollowsFromTheShape() throws {
        // `06-durchstich.md`: bei der Dreierkette liegt der Würfel an einem
        // Ende, nie in der Mitte; bei allen anderen Formen auf einer Zelle,
        // die jede andere des Musters berührt.
        let chain = HexShape.canonical(of: [11, 12, 13])
        for card in try cards {
            let others = Set(card.pattern.keys).subtracting([card.cube])
            let touched = Set(template.neighbours(card.cube)).intersection(others)
            if card.shape == chain {
                #expect(touched.count == 1, "\(card.name): Würfel in der Mitte der Kette")
            } else {
                #expect(touched == others,
                        "\(card.name): Würfel berührt \(touched.map(cellName)) statt alles")
            }
        }
    }
}
