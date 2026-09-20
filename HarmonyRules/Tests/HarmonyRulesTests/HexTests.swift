import Testing
@testable import HarmonyRules

/// The geometry from `04-architektur.md`, and the one check on it that does
/// not come out of the same head as the code: the neighbourhood is worked out
/// a second time, from the picture in `regeln-basisspiel.md` rather than from
/// cube coordinates, and the two have to agree everywhere.
@Suite("Geometrie")
struct HexTests {
    // MARK: - Hin und zurück

    @Test("Jedes Feld beider Seiten übersteht die Umrechnung")
    func everyCellSurvivesTheRoundTrip() {
        for side in [BoardSide.a, .b] {
            for cell in side.board.cells {
                #expect(Hex(cell: cell).cell == cell,
                        "Feld \(cellName(cell)) auf Seite \(side)")
            }
        }
    }

    @Test("Die drei Achsen summieren sich immer zu null")
    func theThreeAxesAlwaysSumToZero() {
        for cell in BoardSide.b.board.cells {
            let hex = Hex(cell: cell)
            #expect(hex.x + hex.y + hex.z == 0)
        }
    }

    // MARK: - Nachbarschaft, zweimal gerechnet

    /// The neighbourhood straight off the drawing in `regeln-basisspiel.md`:
    /// columns of flat-top hexagons, the even ones half a cell lower. Written
    /// in rows and columns on purpose — it must not share a line of reasoning
    /// with `Hex`, or the comparison below would prove nothing.
    private func neighboursByOffset(_ cell: Int, columns: [Int]) -> Set<Int> {
        let column = cell / 10 - 1, row = cell % 10 - 1
        // A lowered column reaches up to its left and right, a raised one down.
        let sideways = (column % 2 == 0) ? -1 : 1
        var candidates = [(column, row - 1), (column, row + 1)]
        for step in [-1, 1] {
            candidates.append((column + step, row))
            candidates.append((column + step, row + sideways))
        }
        return Set(candidates.compactMap { c, r in
            (c >= 0 && c < columns.count && r >= 0 && r < columns[c])
                ? (c + 1) * 10 + (r + 1) : nil
        })
    }

    @Test("Würfelkoordinaten und Zeilenrechnung nennen dieselben Nachbarn")
    func cubeAndOffsetAgreeOnEveryCell() {
        for side in [BoardSide.a, .b] {
            let board = side.board
            for cell in board.cells {
                #expect(Set(board.neighbours(cell)) == neighboursByOffset(cell, columns: side.columns),
                        "Feld \(cellName(cell)) auf Seite \(side)")
            }
        }
    }

    @Test("Nachbarschaft ist gegenseitig")
    func neighbourhoodIsMutual() {
        for side in [BoardSide.a, .b] {
            let board = side.board
            for cell in board.cells {
                for neighbour in board.neighbours(cell) {
                    #expect(board.neighbours(neighbour).contains(cell),
                            "\(cellName(cell)) und \(cellName(neighbour))")
                }
            }
        }
    }

    @Test("Kein Feld hat mehr als sechs Nachbarn, keines weniger als zwei")
    func neighbourCountsStayWithinTheHexagon() {
        for side in [BoardSide.a, .b] {
            let board = side.board
            for cell in board.cells {
                let count = board.neighbours(cell).count
                #expect((2...6).contains(count), "\(cellName(cell)) hat \(count)")
            }
        }
    }

    @Test("Feld 21 der Schablone berührt 11, 12, 31 und 32")
    func theTemplateCellFromTheNotationDocument() {
        // `kartennotation.md` zeichnet die Schablone; 21 sitzt zwischen den
        // beiden linken und den beiden rechten Feldern.
        let template = Board(columns: [3, 3, 3, 3])
        #expect(Set(template.neighbours(21)) == [11, 12, 22, 31, 32])
    }

    // MARK: - Drehungen

    @Test("Sechs Sechsteldrehungen sind die Identität")
    func sixSixthsOfATurnAreTheIdentity() {
        for cell in BoardSide.a.board.cells {
            var hex = Hex(cell: cell)
            for _ in 0..<6 { hex = hex.rotated }
            #expect(hex == Hex(cell: cell), "Feld \(cellName(cell))")
        }
    }

    @Test("Eine Drehung erhält die Nachbarschaft")
    func turningPreservesWhatTouchesWhat() {
        let hex = Hex(cell: 22)
        let turned = hex.rotated
        let neighbours = Set(hex.neighbours.map(\.rotated))
        #expect(neighbours == Set(turned.neighbours))
    }

    @Test("Eine Form behält unter Drehung ihre Größe")
    func aShapeKeepsItsSizeWhenTurned() {
        let shape = HexShape.canonical(of: [12, 21, 22, 32])
        for orientation in shape.orientations {
            #expect(orientation.offsets.count == 4)
        }
    }

    @Test("Dieselbe Form in verschiedener Lage ist dieselbe Form")
    func thePlaceDoesNotMakeTheShape() {
        // `kartennotation.md`: ein Muster ist eine Form, kein Ort.
        #expect(HexShape.canonical(of: [11, 12]) == HexShape.canonical(of: [32, 33]))
        #expect(HexShape.canonical(of: [11, 12, 13]) == HexShape.canonical(of: [41, 42, 43]))
    }

    @Test("Eine gedrehte Form ist dieselbe Form")
    func turningDoesNotMakeANewShape() {
        let upright = HexShape.canonical(of: [11, 12])
        for orientation in HexShape(normalising: [11, 12].map { Hex(cell: $0) }).orientations {
            #expect(orientation.canonical == upright)
        }
    }

    @Test("Zwei verschiedene Formen bleiben verschieden")
    func differentShapesStayDifferent() {
        // Dreierkette gegen Dreieck — beide drei Felder, beide zusammenhängend.
        #expect(HexShape.canonical(of: [11, 12, 13]) != HexShape.canonical(of: [11, 12, 21]))
    }
}
