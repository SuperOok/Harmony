import Foundation
import Testing
@testable import HarmonyEngine

/// What the settings screen hands the engine.
@Suite("Einstellungen")
struct EngineSettingsTests {
    @Test("Die Standardeinstellungen ergeben genau die Standardgewichte")
    func standardSettingsGiveTheStandardWeights() {
        // Otherwise opening the settings and closing them again would
        // change how she plays.
        #expect(EngineSettings.standard.weights == Weights())
        #expect(EngineSettings.standard.forecastEnd)
        #expect(EngineSettings.standard.thinkingLimit == nil)
    }

    @Test("Ohne Kartenplatz-Preis sind freie Plätze nichts wert")
    func withoutThePriceFreeSpacesAreWorthNothing() {
        var settings = EngineSettings()
        settings.priceCardSpaces = false
        #expect(settings.weights.freeSlots == [0, 0, 0, 0])
        #expect(!settings.isStandard)
    }

    @Test("Der Preis wird gestaffelt weitergereicht")
    func thePriceIsHandedOnGraded() {
        var settings = EngineSettings()
        settings.cardSpacePrice = 4
        settings.cardSpaceFullFrom = 9
        #expect(settings.weights.freeSlots == [4, 2.4, 1, 0])
        #expect(settings.weights.freeSlotsFullFrom == 9)
    }

    @Test("Jedes Gewicht kommt in der Bewertung an")
    func everyWeightReachesTheEvaluation() {
        var settings = EngineSettings()
        settings.outlook = 0.7
        settings.cardProspects = 1.3
        settings.landscapeProspects = 0.6
        settings.variety = 0.1
        let weights = settings.weights
        #expect(weights.outlook == 0.7)
        #expect(weights.candidates == 1.3)
        #expect(weights.landscape == 0.6)
        #expect(weights.variety == 0.1)
        #expect(weights.pointsNow == 1, "der Maßstab bleibt")
    }

    @Test("Gespeichert und gelesen bleibt alles, wie es war")
    func savedAndReadNothingChanges() throws {
        var settings = EngineSettings()
        settings.forecastEnd = false
        settings.thinkingLimit = 20
        settings.cardSpacePrice = 7
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(EngineSettings.self, from: data) == settings)
    }

    @Test("Was eine ältere Fassung nicht kannte, nimmt den Standard an")
    func whatAnOlderVersionDidNotKnowTakesTheStandard() throws {
        let old = Data(#"{"forecastEnd": false}"#.utf8)
        let settings = try JSONDecoder().decode(EngineSettings.self, from: old)
        #expect(settings.forecastEnd == false)
        #expect(settings.cardSpacePrice == 10)
        #expect(settings.priceCardSpaces)
    }
}
