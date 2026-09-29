import SwiftUI

@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            // The splash lives in `ContentView`, which shows it again when a
            // new game is begun from the transcript.
            ContentView()
            // The table is usually dimly lit and the dark appearance is
            // what gets used anyway. Until Phase 5 settles it with a
            // reason, this is simply the default.
            .preferredColorScheme(.dark)
        }
    }
}
