import Foundation
import HarmonyEngine

/// What the launch arguments ask for, in one place. See the list of test
/// hooks in `CLAUDE.md`.
enum Launch {
    static let arguments = ProcessInfo.processInfo.arguments

    static func has(_ flag: String) -> Bool { arguments.contains(flag) }

    /// Started for a test rather than by hand. The splash and the start
    /// screen are skipped then: the hooks open on a prepared screen, and
    /// the interface tests would only wait in front of them.
    /// `-showStart` brings the start screen back, for the test of it.
    static var skipsIntro: Bool {
        ["-harmonyTurn", "-sampleMove", "-forgetGame", "-endScore", "-endScoreB",
         "-longCards", "-showStart"].contains(where: has)
    }

    static var showsStartScreen: Bool { has("-showStart") || !skipsIntro }
}

/// The settings for Harmony's thinking, kept between launches.
///
/// In `UserDefaults` rather than beside the game: they belong to the device
/// and its caretaker, not to one evening, and a new game keeps them.
enum SettingsStore {
    private static let key = "engineSettings"

    static func load() -> EngineSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let settings = try? JSONDecoder().decode(EngineSettings.self, from: data)
        else { return .standard }
        return settings
    }

    static func save(_ settings: EngineSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    /// What a search is to use now. `-noForecastEnd` still switches the
    /// forecast off for a comparison, whatever the screen says.
    static var current: EngineSettings {
        var settings = load()
        if Launch.has("-noForecastEnd") { settings.forecastEnd = false }
        return settings
    }
}
