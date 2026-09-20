import Foundation
import HarmonyRules

// The game on disk. `04-architektur.md` asks for a **sequence of events**,
// written after every event, and works out that three demands fall together
// in it: undo is dropping the last event, surviving a switch to the
// background is having written it, and a test case is the same file laid
// aside.
//
// The format is written out rather than put on the view types with a
// `Codable` stamp. A save file is an interface: one that follows whatever a
// struct happens to look like today breaks the first time the struct is
// tidied.

// MARK: - What goes to disk

struct SavedGame: Codable {
    /// Bumped when the format changes. An older file is then discarded
    /// rather than misread — a game lasts an evening, and `04-architektur.md`
    /// rules out one that spans days.
    var version = 1
    var start: SavedState
    var events: [SavedEvent]
}

struct SavedState: Codable {
    var display: [[String]]
    var openCards: [String]
    var seenCards: [String]
    var seatIndex: Int
    var board: [String: [String]]
    var cubes: [String: String]
    var cards: [String]
    var seating: [String]
    var sideB: Bool
}

enum SavedEvent: Codable {
    case opponent(SavedOpponentTurn)
    case harmony(SavedHarmonyMove)
    case correction(SavedCorrection)
}

struct SavedOpponentTurn: Codable {
    var taken: Int
    var refill: [String]
    var cardTaken: String?
    var cardDrawn: String?
    var taps: Int
    var boardNearlyFull: Bool
}

struct SavedHarmonyMove: Codable {
    var space: Int
    var placements: [SavedPlacement]
    var cubes: [SavedCube]
    var cardTaken: String?
    var refill: [String]
    var cardDrawn: String?
    var rationale: SavedRationale
}

struct SavedPlacement: Codable { var stone: String; var cell: Int }
struct SavedCube: Codable { var card: String; var cell: Int }

struct SavedRationale: Codable {
    var immediate: Int
    var value: Int
    var terms: [SavedTerm]
    var probabilityNote: String?
    var runnerUp: String
    var runnerUpImmediate: Int
    var runnerUpValue: Int
    var gapExplanation: String
}

struct SavedTerm: Codable {
    var name: String
    var points: Int
    var prospect: Bool
    var probability: Double?
}

struct SavedCorrection: Codable {
    var changes: [SavedChange]
}

struct SavedChange: Codable { var cell: Int; var stack: [String]; var cube: String? }

// MARK: - Both ways

extension SavedState {
    init(_ state: GameState) {
        display = state.display.map { $0.stones.map(\.rawValue) }
        openCards = state.openCards
        seenCards = state.seenCards.sorted()
        seatIndex = state.seatIndex
        board = Dictionary(uniqueKeysWithValues:
            state.harmonyBoard.map { ("\($0.key)", $0.value.map(\.rawValue)) })
        cubes = Dictionary(uniqueKeysWithValues:
            state.harmonyCubes.map { ("\($0.key)", $0.value) })
        cards = state.harmonyCards.map(\.name)
        seating = state.seating
        sideB = state.sideB
    }

    /// `nil` when the file names something that does not exist — a stone
    /// that is not a stone, a card that is not a card. Better a fresh game
    /// than a position nobody can account for.
    var restored: GameState? {
        func stones(_ raw: [String]) -> [Stone]? {
            var out: [Stone] = []
            for value in raw {
                guard let stone = Stone(rawValue: value) else { return nil }
                out.append(stone)
            }
            return out
        }

        var fields: [DisplayField] = []
        for raw in display {
            guard let stones = stones(raw) else { return nil }
            fields.append(DisplayField(stones: stones))
        }

        var boardOut: [Int: [Stone]] = [:]
        for (key, raw) in board {
            guard let cell = Int(key), let stones = stones(raw) else { return nil }
            boardOut[cell] = stones
        }

        var cubesOut: [Int: String] = [:]
        for (key, card) in cubes {
            guard let cell = Int(key) else { return nil }
            cubesOut[cell] = card
        }

        let known = Set(AnimalCards.all.map(\.name))
        guard cards.allSatisfy(known.contains), openCards.allSatisfy(known.contains)
        else { return nil }

        return GameState(display: fields,
                         openCards: openCards,
                         seenCards: Set(seenCards),
                         seatIndex: seatIndex,
                         harmonyBoard: boardOut,
                         harmonyCubes: cubesOut,
                         harmonyCards: cards.map(Sample.card),
                         seating: seating,
                         sideB: sideB)
    }
}

extension SavedEvent {
    init(_ event: GameEvent) {
        switch event {
        case let .opponentTurn(turn):
            self = .opponent(SavedOpponentTurn(
                taken: turn.taken, refill: turn.refill.map(\.rawValue),
                cardTaken: turn.cardTaken, cardDrawn: turn.cardDrawn,
                taps: turn.taps, boardNearlyFull: turn.boardNearlyFull))
        case let .harmonyTurn(move):
            self = .harmony(SavedHarmonyMove(
                space: move.space,
                placements: move.placements.map {
                    SavedPlacement(stone: $0.stone.rawValue, cell: $0.cell)
                },
                cubes: move.cubes.map { SavedCube(card: $0.card, cell: $0.cell) },
                cardTaken: move.cardTaken,
                refill: move.refill.map(\.rawValue),
                cardDrawn: move.cardDrawn,
                rationale: SavedRationale(move.rationale)))
        case let .correction(correction):
            self = .correction(SavedCorrection(changes: correction.changes.map {
                SavedChange(cell: $0.cell, stack: $0.stack.map(\.rawValue), cube: $0.cube)
            }))
        }
    }

    var restored: GameEvent? {
        func stones(_ raw: [String]) -> [Stone]? {
            var out: [Stone] = []
            for value in raw {
                guard let stone = Stone(rawValue: value) else { return nil }
                out.append(stone)
            }
            return out
        }

        switch self {
        case let .opponent(turn):
            guard let refill = stones(turn.refill) else { return nil }
            return .opponentTurn(OpponentTurn(
                taken: turn.taken, refill: refill,
                cardTaken: turn.cardTaken, cardDrawn: turn.cardDrawn,
                taps: turn.taps, boardNearlyFull: turn.boardNearlyFull))

        case let .harmony(move):
            guard let refill = stones(move.refill) else { return nil }
            var placements: [Placement] = []
            for saved in move.placements {
                guard let stone = Stone(rawValue: saved.stone) else { return nil }
                placements.append(Placement(stone: stone, cell: saved.cell))
            }
            return .harmonyTurn(HarmonyMove(
                space: move.space,
                placements: placements,
                cubes: move.cubes.map { CubePlacement(card: $0.card, cell: $0.cell) },
                cardTaken: move.cardTaken,
                rationale: move.rationale.restored,
                refill: refill,
                cardDrawn: move.cardDrawn))

        case let .correction(correction):
            var changes: [BoardCorrection.Change] = []
            for saved in correction.changes {
                guard let stack = stones(saved.stack) else { return nil }
                changes.append(BoardCorrection.Change(cell: saved.cell, stack: stack,
                                                      cube: saved.cube))
            }
            return .correction(BoardCorrection(changes: changes))
        }
    }
}

extension SavedRationale {
    init(_ rationale: MoveRationale) {
        immediate = rationale.immediate
        value = rationale.value
        terms = rationale.terms.map {
            SavedTerm(name: $0.name, points: $0.points,
                      prospect: $0.prospect, probability: $0.probability)
        }
        probabilityNote = rationale.probabilityNote
        runnerUp = rationale.runnerUp
        runnerUpImmediate = rationale.runnerUpImmediate
        runnerUpValue = rationale.runnerUpValue
        gapExplanation = rationale.gapExplanation
    }

    var restored: MoveRationale {
        MoveRationale(
            immediate: immediate, value: value,
            terms: terms.map {
                ScoreTerm(name: $0.name, points: $0.points,
                          prospect: $0.prospect, probability: $0.probability)
            },
            probabilityNote: probabilityNote,
            runnerUp: runnerUp, runnerUpImmediate: runnerUpImmediate,
            runnerUpValue: runnerUpValue, gapExplanation: gapExplanation)
    }
}

// MARK: - The file

/// Where the game lives between two looks at the screen.
///
/// One file, rewritten after every event. A game is a few dozen events, so
/// there is nothing to gain from appending and something to lose: a file
/// written whole is either the old one or the new one.
enum GameStore {
    private static var url: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory,
                                                 in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory,
                                                 withIntermediateDirectories: true)
        return directory.appendingPathComponent("spielstand.json")
    }

    static func save(start: GameState, events: [GameEvent]) {
        let saved = SavedGame(start: SavedState(start), events: events.map(SavedEvent.init))
        guard let data = try? JSONEncoder().encode(saved) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// The game as it was left, or nothing. Anything unreadable is treated
    /// as nothing: a wrong position is worse than a fresh start, because
    /// nobody at the table could tell where it came from.
    static func load() -> (start: GameState, events: [GameEvent])? {
        guard let data = try? Data(contentsOf: url),
              let saved = try? JSONDecoder().decode(SavedGame.self, from: data),
              saved.version == 1,
              let start = saved.start.restored
        else { return nil }

        var events: [GameEvent] = []
        for saved in saved.events {
            guard let event = saved.restored else { return nil }
            events.append(event)
        }
        return (start, events)
    }

    static func discard() {
        try? FileManager.default.removeItem(at: url)
    }
}
