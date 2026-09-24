import Foundation
import HarmonyRules
import HarmonyEngine

// Plays Harmony against random opponents and compares variants of her
// weights on the same seeds. Asked for first by the price of a card space —
// whether she should wait for a better card — and built so that the other
// guessed weights can be measured the same way. See
// `docs/06-durchstich.md`, *Der Preis eines Kartenplatzes*.
//
//   swift run -c release HarmonySelfPlay --games 40 --take 0.3,0.6 \
//       --variants ohne,stufe:7,stufe:10
//
// A variant is `standard` (the weights as they ship), `ohne` (no price for
// a card space), `stufe:W` (graded, W for the last free space), `flach:W`
// (every space W) or `liste:a/b/c/d` (the four worths as given, the last
// free space first). A third part sets from how many turns
// left a space keeps its full worth: `stufe:4:8`.

struct Variant: Sendable {
    let name: String
    let weights: Weights

    /// How the graded price falls off: the last free space in full, the
    /// first taken out of an empty hand for nothing.
    static let grading: [Double] = [1, 0.6, 0.25, 0]

    init?(_ text: String) {
        let parts = text.split(separator: ":")
        var weights = Weights()
        switch parts.first {
        case "standard":
            guard parts.count == 1 else { return nil }
        case "ohne":
            guard parts.count == 1 else { return nil }
            weights.freeSlots = [0, 0, 0, 0]
        case "stufe":
            guard parts.count >= 2, let w = Double(parts[1]) else { return nil }
            weights.freeSlots = Self.grading.map { $0 * w }
        case "flach":
            guard parts.count >= 2, let w = Double(parts[1]) else { return nil }
            weights.freeSlots = [w, w, w, w]
        case "liste":
            guard parts.count >= 2 else { return nil }
            let worths = parts[1].split(separator: "/").compactMap { Double($0) }
            guard worths.count == 4 else { return nil }
            weights.freeSlots = worths
        default:
            return nil
        }
        if parts.count == 3 {
            guard let turns = Int(parts[2]) else { return nil }
            weights.freeSlotsFullFrom = turns
        }
        name = text
        self.weights = weights
    }
}

struct Options {
    var games = 20
    var players = 3
    var take: [Double] = [0.3, 0.6]
    var variants: [Variant] = ["standard", "ohne"].compactMap(Variant.init)
    var side = BoardSide.a
    var seed: UInt64 = 1
    var forecast = true
    var verbose = false

    init(_ arguments: [String]) {
        var rest = arguments.dropFirst()[...]
        func value() -> String {
            guard let next = rest.popFirst() else { fail("Wert fehlt") }
            return next
        }
        while let flag = rest.popFirst() {
            switch flag {
            case "--games": games = Int(value()) ?? games
            case "--players": players = Int(value()) ?? players
            case "--take": take = value().split(separator: ",").compactMap { Double($0) }
            case "--variants":
                let list = value().split(separator: ",").map(String.init)
                variants = list.map { text -> Variant in
                    guard let variant = Variant(text) else { fail("unbekannte Variante \(text)") }
                    return variant
                }
            case "--side": side = value().lowercased() == "b" ? .b : .a
            case "--seed": seed = UInt64(value()) ?? seed
            case "--no-forecast": forecast = false
            case "-v", "--verbose": verbose = true
            default: fail("unbekannter Parameter \(flag)")
            }
        }
    }
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("HarmonySelfPlay: \(message)\n".utf8))
    exit(2)
}

/// One slot per game. Each game writes its own and reads none.
final class Results: @unchecked Sendable {
    private var slots: [GameResult?]
    init(_ count: Int) { slots = Array(repeating: nil, count: count) }
    subscript(index: Int) -> GameResult? {
        get { slots[index] }
        set { slots[index] = newValue }
    }
}

final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var done = 0
    func next() -> Int { lock.lock(); defer { lock.unlock() }; done += 1; return done }
}

func mean(_ xs: [Double]) -> Double { xs.isEmpty ? 0 : xs.reduce(0, +) / Double(xs.count) }

/// Standard error of the mean.
func stderr(_ xs: [Double]) -> Double {
    guard xs.count > 1 else { return 0 }
    let m = mean(xs)
    let variance = xs.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(xs.count - 1)
    return (variance / Double(xs.count)).squareRoot()
}

func f(_ x: Double, _ digits: Int = 1) -> String { String(format: "%.\(digits)f", x) }

func pad(_ text: String, _ width: Int) -> String {
    text + String(repeating: " ", count: max(0, width - text.count))
}

// Line by line even into a file: a run takes hours, and its log is the only
// way to see how far it has got.
setvbuf(stdout, nil, _IOLBF, 0)

let options = Options(CommandLine.arguments)
let cards = try AnimalCards.load()

struct Job: Sendable {
    let take: Double
    let variant: Variant
    let game: Int
}

var jobs: [Job] = []
for take in options.take {
    for game in 0..<options.games {
        for variant in options.variants { jobs.append(Job(take: take, variant: variant, game: game)) }
    }
}

print("Selbstspiel: \(options.games) Partien je Variante, \(options.players) Spielerinnen,"
      + " Seite \(options.side == .a ? "A" : "B"),"
      + " Vorhersage \(options.forecast ? "an" : "aus"), Startwert \(options.seed)")
print("\(jobs.count) Partien auf \(ProcessInfo.processInfo.activeProcessorCount) Kernen\n")

let results = Results(jobs.count)
let counter = Counter()
let started = Date()
let snapshot = options

DispatchQueue.concurrentPerform(iterations: jobs.count) { index in
    let job = jobs[index]
    // Seat and seed follow the game number, not the variant: every variant
    // plays the same games from the same seats.
    let game = Game(seed: snapshot.seed &* 1_000_003 &+ UInt64(job.game),
                    players: snapshot.players, seat: job.game % snapshot.players,
                    side: snapshot.side, weights: job.variant.weights,
                    opponents: Opponents(takesCard: job.take),
                    forecast: snapshot.forecast)
    let result = game.play(cards: cards)
    results[index] = result
    let done = counter.next()
    if snapshot.verbose {
        print("[\(done)/\(jobs.count)] \(job.variant.name) p=\(job.take) #\(job.game):"
              + " \(result.total) (\(result.landscape)+\(result.cards)),"
              + " Karten in Zug \(result.takenOnTurn), \(f(result.searchSeconds)) s")
    }
}

let elapsed = Date().timeIntervalSince(started)

for take in options.take {
    print("Mitspielerinnen nehmen eine Karte mit p = \(take)")
    print(pad("Variante", 12) + pad("Punkte", 14) + pad("Δ gepaart", 14)
          + pad("Landsch.", 10) + pad("Karten", 8) + pad("genommen", 10)
          + pad("1./letzte in Zug", 18) + pad("unfertig", 10) + "s/Partie")

    func runs(_ variant: Variant) -> [GameResult] {
        jobs.indices.filter { jobs[$0].take == take && jobs[$0].variant.name == variant.name }
            .sorted { jobs[$0].game < jobs[$1].game }
            .compactMap { results[$0] }
    }
    let base = runs(options.variants[0]).map { Double($0.total) }

    for variant in options.variants {
        let games = runs(variant)
        let totals = games.map { Double($0.total) }
        let diffs = zip(totals, base).map { $0 - $1 }
        let first = games.compactMap { $0.takenOnTurn.first.map(Double.init) }
        let last = games.compactMap { $0.takenOnTurn.last.map(Double.init) }
        print(pad(variant.name, 12)
              + pad("\(f(mean(totals))) ± \(f(stderr(totals)))", 14)
              + pad(variant.name == options.variants[0].name
                    ? "—" : "\(f(mean(diffs))) ± \(f(stderr(diffs)))", 14)
              + pad(f(mean(games.map { Double($0.landscape) })), 10)
              + pad(f(mean(games.map { Double($0.cards) })), 8)
              + pad(f(mean(games.map { Double($0.takenOnTurn.count) })), 10)
              + pad("\(f(mean(first))) / \(f(mean(last)))", 18)
              + pad(f(mean(games.map { Double($0.cardsUnfinished) })), 10)
              + f(mean(games.map(\.searchSeconds)), 0))
        let empty = games.count { $0.takenOnTurn.isEmpty }
        let stuck = games.reduce(0) { $0 + $1.stuck }
        let problems = Set(games.flatMap(\.problems))
        if empty > 0 { print("    \(empty) Partien ohne jede Karte") }
        if stuck > 0 { print("    \(stuck) Züge ohne legale Möglichkeit") }
        for problem in problems.sorted() { print("    Widerspruch: \(problem)") }
    }
    print()
}

print("""
Punkte: Mittel ± Standardfehler. Δ gepaart: Unterschied zur ersten Variante \
auf denselben Partien — gleiche Steine, gleiche Karten, gleicher Platz —, \
der Maßstab für den Vergleich. 1./letzte in Zug: eigener Zug, in dem die \
erste und die letzte Karte genommen wurde, gemittelt über Partien mit Karte.
""")
print("Gesamt \(f(elapsed / 60)) min")
