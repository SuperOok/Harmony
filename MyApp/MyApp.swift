import SwiftUI

@main struct MyApp: App {
    /// The splash is for a start by hand. The test hooks skip it: they open
    /// on a prepared screen, and two seconds of flowers in front of it would
    /// only make the interface tests wait.
    @State private var showsSplash = !["-harmonyTurn", "-sampleMove", "-forgetGame",
                                        "-endScore", "-endScoreB", "-longCards"]
        .contains { ProcessInfo.processInfo.arguments.contains($0) }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Underneath from the start, so that the game is loaded and
                // laid out by the time the splash fades.
                ContentView()
                if showsSplash {
                    SplashView { showsSplash = false }
                        .zIndex(1)
                }
            }
            // The table is usually dimly lit and the dark appearance is
            // what gets used anyway. Until Phase 5 settles it with a
            // reason, this is simply the default.
            .preferredColorScheme(.dark)
        }
    }
}
