import Foundation
import HarmonyRules
import HarmonyEngine
import HarmonyTable

// Two to four engines with different settings against each other. Every
// deal — the same bag, the same deck — is played once per rotation of the
// seats, so each setting sits in each place equally often and meets the
// same stones there. Every turn passes the referee; a game with an
// objection is set aside and reported, never counted.
//
//   swift run -c release HarmonyMatch --plaetze standard,ohne-kartenplatz --partien 50
//
// A setting is `standard`, `ohne-kartenplatz` or `ohne-vorhersage`, with
// changes after a `+`: `standard+preis=7`, `standard+bedenkzeit=10+outlook=0.7`.
// Keys: vorhersage, kartenplatz (an/aus), preis, vollab, outlook,
// tierkarten, offene, landschaften, vielfalt, bedenkzeit (seconds).
// `docs/06-durchstich.md`, *Engines gegeneinander*, has the reasoning.

setvbuf(stdout, nil, _IOLBF, 0)

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("HarmonyMatch: \(message)\n".utf8))
    exit(2)
}

struct Variant: Sendable {
    let name: String
    let settings: EngineSettings

    init(_ text: String) {
        let parts = text.split(separator: "+").map(String.init)
        var settings = EngineSettings.standard
        switch parts.first {
        case "standard": break
        case "ohne-kartenplatz": settings.priceCardSpaces = false
        case "ohne-vorhersage": settings.forecastEnd = false
        default: fail("unbekannte Einstellung \(parts.first ?? "")")
        }
        for change in parts.dropFirst() {
            let pair = change.split(separator: "=").map(String.init)
            guard pair.count == 2 else { fail("\(change): Schlüssel=Wert erwartet") }
            let (key, value) = (pair[0], pair[1])
            func number() -> Double {
                guard let x = Double(value) else { fail("\(change): Zahl erwartet") }
                return x
            }
            func flag() -> Bool {
                switch value {
                case "an", "ja", "true": return true
                case "aus", "nein", "false": return false
                default: fail("\(change): an oder aus erwartet")
                }
            }
            switch key {
            case "vorhersage": settings.forecastEnd = flag()
            case "kartenplatz": settings.priceCardSpaces = flag()
            case "preis": settings.cardSpacePrice = number()
            case "vollab": settings.cardSpaceFullFrom = Int(number())
            case "outlook": settings.outlook = number()
            case "tierkarten": settings.cardProspects = number()
            case "offene": settings.openCardProspects = number()
            case "landschaften": settings.landscapeProspects = number()
            case "vielfalt": settings.variety = number()
            case "bedenkzeit": settings.thinkingLimit = Int(number())
            default: fail("unbekannter Schlüssel \(key)")
            }
        }
        name = text
        self.settings = settings
    }
}

struct Options {
    var seats: [Variant] = [Variant("standard"), Variant("ohne-kartenplatz")]
    var deals = 10
    var side = BoardSide.a
    var seed: UInt64 = 1
    var verbose = false
    var log: String?

    init(_ arguments: [String]) {
        var rest = arguments.dropFirst()[...]
        func value() -> String {
            guard let next = rest.popFirst() else { fail("Wert fehlt") }
            return next
        }
        while let flag = rest.popFirst() {
            switch flag {
            case "--plaetze": seats = value().split(separator: ",").map { Variant(String($0)) }
            case "--partien": deals = Int(value()) ?? deals
            case "--seite": side = value().lowercased() == "b" ? .b : .a
            case "--startwert": seed = UInt64(value()) ?? seed
            case "--protokoll": log = value()
            case "-v", "--verbose": verbose = true
            default: fail("unbekannter Parameter \(flag)")
            }
        }
        guard (2...4).contains(seats.count) else { fail("2 bis 4 Plätze") }
    }
}

/// Where a seat's points came from, for the table at the end of a run.
enum Breakdown {
    /// The first word of a score group's title, which tells the landscapes
    /// apart on both sides of the board.
    static let titles = ["Bäume", "Berge", "Felder", "Wasser", "Gebäude"]

    static func points(of seat: Int, in table: Table) -> [Int] {
        let groups = BoardScoring(side: table.side, columns: table.side.columns,
                                  stacks: table.seats[seat].stacks).breakdown()
        return titles.map { title in
            groups.filter { $0.title.hasPrefix(title) }.reduce(0) { $0 + $1.points }
        }
    }
}

/// One game: which setting sat where, and how it went.
struct GameResult: Sendable, Codable {
    let deal: Int
    let rotation: Int
    let seats: [String]
    var scores: [Int] = []
    var landscape: [Int] = []
    var cards: [Int] = []
    var cardsTaken: [Int] = []
    var seconds: [Double] = []
    /// Points per landscape, in the order of `Breakdown.titles`, for each seat.
    var byLandscape: [[Int]] = []
    /// Cards that reached their last cube, and cubes laid and left on the
    /// cards still held, for each seat.
    var cardsFinished: [Int] = []
    var cubesLaid: [Int] = []
    var cubesLeft: [Int] = []
    /// Stones down and spaces left empty at the end, for each seat.
    var stonesDown: [Int] = []
    var emptySpaces: [Int] = []
    var turns = 0
    /// Anything the referee objected to. A game with an objection is not
    /// counted.
    var objections: [String] = []
}

/// Plays one deal in one rotation.
func play(deal: Int, rotation: Int, options: Options, cards: [AnimalCard]) -> GameResult {
    let players = options.seats.count
    let seated = (0..<players).map { options.seats[($0 + rotation) % players] }
    var table = Table(side: options.side, names: seated.map(\.name), cards: cards,
                      seed: options.seed &* 1_000_003 &+ UInt64(deal))
    var result = GameResult(deal: deal, rotation: rotation, seats: seated.map(\.name))
    var seconds = Array(repeating: 0.0, count: players)

    while !table.isOver {
        let seat = table.mover
        let settings = seated[seat].settings
        let view = table.view(for: seat, forecast: settings.forecastEnd)
        if !view.inconsistencies.isEmpty {
            result.objections += view.inconsistencies.map { "Sicht von \(seat): \($0)" }
            break
        }
        let started = Date()
        let deadline = settings.thinkingLimit.map { started.addingTimeInterval(Double($0)) }
        // One core per game: the games run side by side, which uses the
        // machine better than one game on all of it.
        let suggestion = Search.best(from: view, weights: settings.weights,
                                     cancelled: { deadline.map { Date() > $0 } ?? false },
                                     cores: 1)
        seconds[seat] += Date().timeIntervalSince(started)
        guard let move = suggestion?.move else {
            result.objections.append("Zug \(table.turnsPlayed + 1): \(seated[seat].name) "
                                     + "findet keinen Zug.")
            break
        }
        let problems = table.play(move)
        if !problems.isEmpty {
            result.objections += problems.map {
                "Zug \(table.turnsPlayed + 1), \(seated[seat].name): \($0)"
            }
            break
        }
    }

    result.turns = table.turnsPlayed
    result.scores = (0..<players).map(table.score(of:))
    result.landscape = (0..<players).map(table.landscape(of:))
    result.cards = (0..<players).map(table.cardPoints(of:))
    result.cardsTaken = table.seats.map(\.hand.count)
    result.byLandscape = (0..<players).map { Breakdown.points(of: $0, in: table) }
    result.cardsFinished = table.seats.map { $0.hand.count(where: \.isFinished) }
    result.cubesLaid = table.seats.map { $0.hand.reduce(0) { $0 + $1.cubesPlaced } }
    result.cubesLeft = table.seats.map {
        $0.hand.reduce(0) { $0 + $1.card.points.count - $1.cubesPlaced }
    }
    result.stonesDown = table.seats.map { $0.stacks.values.reduce(0) { $0 + $1.count } }
    result.emptySpaces = table.seats.map { table.side.board.cells.count - $0.stacks.count }
    result.seconds = seconds
    return result
}

/// One slot per game. Each game writes its own and reads none.
final class Results: @unchecked Sendable {
    private var slots: [GameResult?]
    private let lock = NSLock()
    private var done = 0
    init(_ count: Int) { slots = Array(repeating: nil, count: count) }
    subscript(index: Int) -> GameResult? {
        get { slots[index] }
        set { slots[index] = newValue }
    }
    func finished() -> Int { lock.lock(); defer { lock.unlock() }; done += 1; return done }
}

func mean(_ xs: [Double]) -> Double { xs.isEmpty ? 0 : xs.reduce(0, +) / Double(xs.count) }

func stderr(_ xs: [Double]) -> Double {
    guard xs.count > 1 else { return 0 }
    let m = mean(xs)
    return (xs.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(xs.count - 1) / Double(xs.count))
        .squareRoot()
}

func f(_ x: Double, _ digits: Int = 1) -> String { String(format: "%.\(digits)f", x) }

func pad(_ text: String, _ width: Int) -> String {
    text + String(repeating: " ", count: max(0, width - text.count))
}

// MARK: - The run

let options = Options(CommandLine.arguments)
let cards = AnimalCards.all
let players = options.seats.count
let names = options.seats.map(\.name)
let variants = Array(Set(names)).sorted { names.firstIndex(of: $0)! < names.firstIndex(of: $1)! }

let jobs = (0..<options.deals).flatMap { deal in (0..<players).map { (deal, $0) } }
let results = Results(jobs.count)
let started = Date()

print("Engines gegeneinander: \(names.joined(separator: " · ")), Seite "
      + "\(options.side == .a ? "A" : "B"), \(options.deals) Austeilungen × "
      + "\(players) Sitzordnungen = \(jobs.count) Partien, Startwert \(options.seed)")
for variant in variants {
    let s = Variant(variant).settings
    print("  \(variant): Vorhersage \(s.forecastEnd ? "an" : "aus"), Kartenplatz "
          + (s.priceCardSpaces ? "\(f(s.cardSpacePrice, 1)) ab \(s.cardSpaceFullFrom)" : "aus")
          + ", Aussicht \(f(s.outlook, 2)), Tierkarten \(f(s.cardProspects, 1)), "
          + "offene Karten \(f(s.openCardProspects, 2)), "
          + "Landschaften \(f(s.landscapeProspects, 1)), Vielfalt \(f(s.variety, 2)), "
          + "Bedenkzeit \(s.thinkingLimit.map { "\($0) s" } ?? "unbegrenzt")")
}
print()

let snapshot = options
DispatchQueue.concurrentPerform(iterations: jobs.count) { index in
    let (deal, rotation) = jobs[index]
    let result = play(deal: deal, rotation: rotation, options: snapshot, cards: cards)
    results[index] = result
    let done = results.finished()
    if snapshot.verbose {
        let line = zip(result.seats, result.scores).map { "\($0) \($1)" }.joined(separator: ", ")
        print("[\(done)/\(jobs.count)] Austeilung \(deal), Drehung \(rotation): \(line)"
              + " — \(result.turns) Züge, \(f(result.seconds.reduce(0, +), 0)) s"
              + (result.objections.isEmpty ? "" : " — BEANSTANDET: \(result.objections[0])"))
    }
}

let all = (0..<jobs.count).compactMap { results[$0] }
let valid = all.filter { $0.objections.isEmpty }
let objected = all.filter { !$0.objections.isEmpty }

if let path = options.log {
    let encoder = JSONEncoder()
    let lines = all.compactMap { try? encoder.encode($0) }
        .compactMap { String(data: $0, encoding: .utf8) }
    try? (lines.joined(separator: "\n") + "\n").write(toFile: path, atomically: true,
                                                         encoding: .utf8)
}

// MARK: - The statistics

/// A setting's points in one game: the mean over its seats, if it holds
/// several. `nil` if it did not play.
func points(of variant: String, in game: GameResult) -> Double? {
    let mine = game.seats.indices.filter { game.seats[$0] == variant }.map { Double(game.scores[$0]) }
    return mine.isEmpty ? nil : mean(mine)
}

/// Rank from 1, ties sharing the better one.
func rank(of seat: Int, in game: GameResult) -> Int {
    1 + game.scores.count { $0 > game.scores[seat] }
}

print("\nNach Einstellung (\(valid.count) gültige Partien)")
print(pad("Einstellung", 26) + pad("Punkte", 14) + pad("Landsch.", 10) + pad("Karten", 8)
      + pad("genommen", 10) + pad("Rang", 7) + pad("Siege", 8) + "s/Zug")
for variant in variants {
    var scores: [Double] = [], land: [Double] = [], card: [Double] = []
    var taken: [Double] = [], ranks: [Double] = [], wins = 0.0, seconds = 0.0, turns = 0.0
    for game in valid {
        for seat in game.seats.indices where game.seats[seat] == variant {
            scores.append(Double(game.scores[seat]))
            land.append(Double(game.landscape[seat]))
            card.append(Double(game.cards[seat]))
            taken.append(Double(game.cardsTaken[seat]))
            ranks.append(Double(rank(of: seat, in: game)))
            let best = game.scores.max()!
            if game.scores[seat] == best {
                wins += 1 / Double(game.scores.count { $0 == best })
            }
            seconds += game.seconds[seat]
            turns += Double(game.turns) / Double(players)
        }
    }
    print(pad(variant, 26) + pad("\(f(mean(scores))) ± \(f(stderr(scores)))", 14)
          + pad(f(mean(land)), 10) + pad(f(mean(card)), 8) + pad(f(mean(taken)), 10)
          + pad(f(mean(ranks), 2), 7) + pad("\(f(100 * wins / Double(max(scores.count, 1)), 0)) %", 8)
          + f(turns > 0 ? seconds / turns : 0))
}

/// Where the points come from, per setting: the landscapes, and what the
/// cards made of their cubes. The question behind it is which part of the
/// score falls short, not which setting wins.
print("\nWoher die Punkte kommen (Mittel je Partie)")
print(pad("Einstellung", 26) + Breakdown.titles.map { pad($0, 9) }.joined()
      + pad("Karten", 8) + pad("fertig", 8) + pad("Würfel", 8) + pad("offen", 7)
      + pad("Steine", 8) + "leer")
for variant in variants {
    var perLandscape = Array(repeating: 0.0, count: Breakdown.titles.count)
    var card = 0.0, finished = 0.0, laid = 0.0, left = 0.0, stones = 0.0, empty = 0.0
    var seats = 0.0
    for game in valid where game.byLandscape.count == game.seats.count {
        for seat in game.seats.indices where game.seats[seat] == variant {
            seats += 1
            for (index, value) in game.byLandscape[seat].enumerated() {
                perLandscape[index] += Double(value)
            }
            card += Double(game.cards[seat])
            finished += Double(game.cardsFinished[seat])
            laid += Double(game.cubesLaid[seat])
            left += Double(game.cubesLeft[seat])
            stones += Double(game.stonesDown[seat])
            empty += Double(game.emptySpaces[seat])
        }
    }
    let n = max(seats, 1)
    print(pad(variant, 26) + perLandscape.map { pad(f($0 / n), 9) }.joined()
          + pad(f(card / n), 8) + pad(f(finished / n), 8) + pad(f(laid / n), 8)
          + pad(f(left / n), 7) + pad(f(stones / n), 8) + f(empty / n))
}
print("  Karten: Punkte der Tierkarten · fertig: Karten mit letztem Würfel · "
      + "Würfel: gelegt · offen: noch auf den gehaltenen Karten · "
      + "leer: freie Felder am Ende")

if variants.count > 1 {
    print("\nPaarweise: Punkte der ersten minus der zweiten, je Austeilung über alle "
          + "Sitzordnungen gemittelt")
    for (i, a) in variants.enumerated() {
        for b in variants[(i + 1)...] {
            var diffs: [Double] = []
            var ahead = 0.0, meetings = 0.0
            for deal in 0..<options.deals {
                let games = valid.filter { $0.deal == deal }
                // Only a deal whose every rotation counts is a fair pair:
                // dropping one would leave one setting in the better seat.
                guard games.count == players else { continue }
                let pa = games.compactMap { points(of: a, in: $0) }
                let pb = games.compactMap { points(of: b, in: $0) }
                diffs.append(mean(pa) - mean(pb))
                for game in games {
                    for sa in game.seats.indices where game.seats[sa] == a {
                        for sb in game.seats.indices where game.seats[sb] == b {
                            meetings += 1
                            if game.scores[sa] > game.scores[sb] { ahead += 1 }
                            else if game.scores[sa] == game.scores[sb] { ahead += 0.5 }
                        }
                    }
                }
            }
            print("  \(pad(a, 24)) − \(pad(b, 24)) \(f(mean(diffs))) ± \(f(stderr(diffs)))"
                  + "   vorn in \(f(100 * ahead / max(meetings, 1), 0)) % "
                  + "(\(diffs.count) Austeilungen)")
        }
    }
}

print("\nNach Platz (Startspielerin = 1)")
for seat in 0..<players {
    let scores = valid.map { Double($0.scores[seat]) }
    print("  Platz \(seat + 1): \(f(mean(scores))) ± \(f(stderr(scores)))")
}

print("\nSchiedsrichter: \(objected.count) von \(all.count) Partien beanstandet")
for game in objected.prefix(10) {
    print("  Austeilung \(game.deal), Drehung \(game.rotation): \(game.objections.joined(separator: " | "))")
}
print("\nGesamt \(f(Date().timeIntervalSince(started) / 60)) min")
