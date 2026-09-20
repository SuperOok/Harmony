import SwiftUI
import HarmonyRules
import Playgrounds

struct ContentView: View {
    /// Nothing is played until the setup has been recorded. The launch
    /// argument skips it and starts on Harmony's screen with sample data,
    /// which is what `pruefverfahren.md` foresees as a test hook.
    @State private var startState: GameState? = {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-endScoreB") { return GameState.finished(sideB: true) }
        if arguments.contains("-endScore") { return GameState.finished() }
        if arguments.contains("-harmonyTurn") {
            return GameState.initial(seat: Sample.turnOrder.count - 1)
        }
        return nil
    }()

    /// Set by `-endScore`: skip to the final score instead of playing the
    /// five and thirty turns that empty the bag.
    private let finished = ProcessInfo.processInfo.arguments.contains("-endScore")
        || ProcessInfo.processInfo.arguments.contains("-endScoreB")

    var body: some View {
        if let startState {
            OpponentTurnView(startState: startState, finished: finished)
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
