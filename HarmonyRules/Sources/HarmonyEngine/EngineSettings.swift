import Foundation

/// How strongly and how long Harmony thinks, as the caretaker can set it.
///
/// Not the weights themselves but what is worth offering on a screen: each
/// setting answers one question someone at the table could ask, and turns
/// into `Weights`, the end forecast and a time limit for the search. Kept
/// here rather than in the app, so that what a setting does to the engine
/// is tested where the engine is.
///
/// **The standard values are `Weights()`'s.** They are read from there, not
/// copied: what ships as the standard is one number in one place, and the
/// settings screen and the evaluation cannot come to disagree about it.
///
/// **What is left out, and why.** `Weights.pointsNow` is the yardstick the
/// others are measured against — raising it is the same as lowering all
/// the rest. The stacking shares of the end forecast, the survival of a
/// display space and the shape of the chance model are assumptions about
/// the game, not preferences; a switch for them would invite tuning by
/// feel what belongs measured.
public struct EngineSettings: Sendable, Equatable, Codable {
    /// The end forecast steers the evaluation. Off, she counts only the
    /// triggers she knows for certain — the bag, her own board and a
    /// reported foreign one — and plays as if she had more time.
    public var forecastEnd = true

    /// A free card space has a worth, so a weak card is not taken just
    /// because a space is free. Measured: +3.4 points a game.
    public var priceCardSpaces = true
    /// What the last free space is worth; the others follow the grading.
    public var cardSpacePrice = Weights().freeSlots[0]
    /// Own turns left from which a free space keeps its full worth.
    public var cardSpaceFullFrom = Weights().freeSlotsFullFrom

    /// Points in prospect against points in hand. Lower is more cautious:
    /// she lays a cube now rather than hoping for a better one.
    public var outlook = Weights().outlook
    /// How much the animal cards' prospects count.
    public var cardProspects = 1.0
    /// How much the cards that only lie open count, as a share of one in
    /// hand. See `Weights.openCards`.
    public var openCardProspects = Weights().openCards
    /// How much the landscapes' prospects count — rivers, islands, the
    /// sleeping ones.
    public var landscapeProspects = 1.0
    /// A small bonus per candidate still alive, which keeps options open.
    public var variety = Weights().variety

    /// Seconds before the search stops by itself and plays the best turn
    /// found so far. `nil` lets it run until it is done.
    public var thinkingLimit: Int? = nil

    public init() {}

    /// The settings as they ship.
    public static let standard = EngineSettings()

    public var isStandard: Bool { self == .standard }

    /// How the price falls off from the last free space to the first: the
    /// last in full, the one taken out of an empty hand for nothing. The
    /// grading the self-play measured.
    public static let cardSpaceGrading: [Double] = {
        let slots = Weights().freeSlots
        return slots.map { $0 / slots[0] }
    }()

    /// What the evaluation is to use.
    public var weights: Weights {
        var weights = Weights()
        weights.candidates = cardProspects
        weights.openCards = openCardProspects
        weights.landscape = landscapeProspects
        weights.variety = variety
        weights.outlook = outlook
        weights.freeSlots = priceCardSpaces
            ? Self.cardSpaceGrading.map { $0 * cardSpacePrice }
            : Array(repeating: 0, count: EngineState.cardLimit)
        weights.freeSlotsFullFrom = cardSpaceFullFrom
        return weights
    }

    // Forward compatible: a setting added later is missing from what an
    // older version saved, and then it takes its standard value instead of
    // throwing everything away.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = EngineSettings.standard
        forecastEnd = try c.decodeIfPresent(Bool.self, forKey: .forecastEnd) ?? d.forecastEnd
        priceCardSpaces = try c.decodeIfPresent(Bool.self, forKey: .priceCardSpaces)
            ?? d.priceCardSpaces
        cardSpacePrice = try c.decodeIfPresent(Double.self, forKey: .cardSpacePrice)
            ?? d.cardSpacePrice
        cardSpaceFullFrom = try c.decodeIfPresent(Int.self, forKey: .cardSpaceFullFrom)
            ?? d.cardSpaceFullFrom
        outlook = try c.decodeIfPresent(Double.self, forKey: .outlook) ?? d.outlook
        cardProspects = try c.decodeIfPresent(Double.self, forKey: .cardProspects)
            ?? d.cardProspects
        openCardProspects = try c.decodeIfPresent(Double.self, forKey: .openCardProspects)
            ?? d.openCardProspects
        landscapeProspects = try c.decodeIfPresent(Double.self, forKey: .landscapeProspects)
            ?? d.landscapeProspects
        variety = try c.decodeIfPresent(Double.self, forKey: .variety) ?? d.variety
        thinkingLimit = try c.decodeIfPresent(Int.self, forKey: .thinkingLimit)
    }
}
