import SwiftUI

@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            // The splash lives in `ContentView`, which shows it again when a
            // new game is begun from the transcript.
            ContentView()
            // The table is usually dimly lit and the dark appearance is
            // what gets used anyway, so it is the only one there is.
            .preferredColorScheme(.dark)
        }
    }
}
