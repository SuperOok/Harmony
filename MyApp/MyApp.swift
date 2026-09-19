import SwiftUI

@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // Am Tisch wird meist im Dunkeln gespielt, und Hauke nutzt
                // ohnehin das dunkle Erscheinungsbild. Bis Phase 5 das
                // begründet festlegt, ist es hier die Vorgabe.
                .preferredColorScheme(.dark)
        }
    }
}
