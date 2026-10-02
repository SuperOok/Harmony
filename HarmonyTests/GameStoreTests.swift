import Testing
import Foundation
import HarmonyRules
@testable import Harmony

/// The game on disk. Every test works on a file of its own — the app's real
/// one is not to be touched by a test run.
@Suite("Spielstand")
struct GameStoreTests {
    private func temporaryFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("harmony-test-\(UUID().uuidString).json")
    }

    private let events: [GameEvent] = [
        GameLogTests.opponentTurn(taken: 2, refill: [.brick, .leaves, .wood]),
        GameLogTests.harmonyTurn(space: 0, refill: [.water, .field, .stone]),
        GameLogTests.opponentTurn(taken: 1, refill: []),
    ]

    @Test("Was gespeichert wurde, kommt gleich zurück")
    func aSavedGameComesBackAsItWas() throws {
        let url = temporaryFile()
        defer { GameStore.discard(at: url) }
        let start = GameState.initial()

        #expect(GameStore.save(start: start, events: events, to: url))
        let loaded = try #require(GameStore.load(from: url))

        #expect(loaded.events.count == events.count)
        #expect(loaded.events.entries(from: loaded.start).map(\.line)
                == events.entries(from: start).map(\.line))
        #expect(loaded.events.state(from: loaded.start).display.map(\.notation)
                == events.state(from: start).display.map(\.notation))
    }

    @Test("Ohne Datei gibt es keine Partie")
    func withoutAFileThereIsNoGame() {
        #expect(GameStore.load(from: temporaryFile()) == nil)
    }

    @Test("Eine unlesbare Datei gilt als keine Partie")
    func anUnreadableFileIsNoGame() throws {
        let url = temporaryFile()
        defer { GameStore.discard(at: url) }
        try Data("das ist kein JSON".utf8).write(to: url)
        #expect(GameStore.load(from: url) == nil)
    }

    @Test("Ein Ereignis auf ein Feld, das es nicht gibt, verwirft die Datei")
    func anEventOnAMissingSpaceDiscardsTheFile() {
        let url = temporaryFile()
        defer { GameStore.discard(at: url) }
        GameStore.save(start: .initial(), events: [GameLogTests.opponentTurn(taken: 9)], to: url)
        #expect(GameStore.load(from: url) == nil)
    }

    @Test("Ein Feld, das nach einem leeren Beutel fehlt, wird beim Laden mitgezählt")
    func replayingCountsTheSpacesLostToAnEmptyBag() {
        let url = temporaryFile()
        defer { GameStore.discard(at: url) }
        // Five turns without a refill leave no space; a sixth has none to take.
        var many: [GameEvent] = Array(repeating: GameLogTests.opponentTurn(taken: 0, refill: []), count: 5)
        GameStore.save(start: .initial(), events: many, to: url)
        #expect(GameStore.load(from: url) != nil)
        many.append(GameLogTests.opponentTurn(taken: 0, refill: []))
        GameStore.save(start: .initial(), events: many, to: url)
        #expect(GameStore.load(from: url) == nil)
    }

    @Test("Ein Platz außerhalb der Sitzordnung verwirft die Datei")
    func aSeatOutsideTheSeatingDiscardsTheFile() {
        let url = temporaryFile()
        defer { GameStore.discard(at: url) }
        var start = GameState.initial()
        start.seatIndex = 7
        GameStore.save(start: start, events: [], to: url)
        #expect(GameStore.load(from: url) == nil)
    }

    @Test("Eine Sitzordnung ohne Harmony verwirft die Datei")
    func aSeatingWithoutHarmonyDiscardsTheFile() {
        let url = temporaryFile()
        defer { GameStore.discard(at: url) }
        var start = GameState.initial()
        start.seating = start.seating.map { $0 == GameState.harmonyName ? "Anke" : $0 }
        GameStore.save(start: start, events: [], to: url)
        #expect(GameStore.load(from: url) == nil)
    }

    @Test("Wo nicht geschrieben werden kann, meldet das Speichern es")
    func savingReportsAFailure() {
        let url = URL(fileURLWithPath: "/nicht-vorhanden-\(UUID().uuidString)/spielstand.json")
        #expect(GameStore.save(start: .initial(), events: [], to: url) == false)
    }

    @Test("Verwerfen entfernt die Datei")
    func discardingRemovesTheFile() {
        let url = temporaryFile()
        GameStore.save(start: .initial(), events: [], to: url)
        GameStore.discard(at: url)
        #expect(GameStore.load(from: url) == nil)
    }
}
