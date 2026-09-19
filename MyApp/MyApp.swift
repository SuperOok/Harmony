import SwiftUI

@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // The table is usually dimly lit and the dark appearance is
                // what gets used anyway. Until Phase 5 settles it with a
                // reason, this is simply the default.
                .preferredColorScheme(.dark)
        }
    }
}
