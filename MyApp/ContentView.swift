import SwiftUI
import Playgrounds

struct ContentView: View {
    /// Nothing is played until the setup has been recorded. The launch
    /// argument skips it and starts on Harmony's screen with sample data,
    /// which is what `pruefverfahren.md` foresees as a test hook.
    @State private var startState: GameState? =
        ProcessInfo.processInfo.arguments.contains("-harmonyTurn")
        ? GameState.initial(seat: Sample.turnOrder.count - 1) : nil

    var body: some View {
        if let startState {
            OpponentTurnView(startState: startState)
        } else {
            SetupView { startState = $0 }
        }
    }
}

#Preview {
    ContentView()
}

#Playground {
    let field = DisplayField(stones: [.brick, .wood, .leaves])
    _ = field.notation
}
