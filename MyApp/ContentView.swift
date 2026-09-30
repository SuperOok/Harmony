import SwiftUI
import HarmonyRules

struct ContentView: View {
    /// Nothing is played until the setup has been recorded. The launch
    /// argument skips it and starts on Harmony's screen with sample data,
    /// which is what `pruefverfahren.md` foresees as a test hook.
    @State private var startState: GameState? = {
        let arguments = ProcessInfo.processInfo.arguments
        // Ein Prüfeinstieg, der mit leerem Tisch beginnen muss.
        if arguments.contains("-forgetGame") { GameStore.discard() }
        if arguments.contains("-endScoreB") { return GameState.finished(sideB: true) }
        if arguments.contains("-endScore") { return GameState.finished() }
        if arguments.contains("-harmonyTurn") {
            return GameState.initial(seat: Sample.turnOrder.count - 1)
        }
        // A game left open comes back as it was. `04-architektur.md` asks
        // for the event sequence to be written after every event; this is
        // the reading side of it.
        return GameStore.load()?.start
    }()

    /// What was played before the app was last put away.
    @State private var restored: [GameEvent] = {
        let arguments = ProcessInfo.processInfo.arguments
        guard !arguments.contains("-endScore"), !arguments.contains("-endScoreB"),
              !arguments.contains("-harmonyTurn")
        else { return [] }
        return GameStore.load()?.events ?? []
    }()

    /// Set by `-endScore`: skip to the final score instead of playing the
    /// five and thirty turns that empty the bag.
    private let finished = ProcessInfo.processInfo.arguments.contains("-endScore")
        || ProcessInfo.processInfo.arguments.contains("-endScoreB")

    /// Started through one of the test hooks rather than by being tapped.
    ///
    /// Such a run must not write: the sample position would come back the
    /// next time the app is opened for real, looking exactly like a game
    /// somebody played.
    private let isTestEntry = ["-harmonyTurn", "-endScore", "-endScoreB"]
        .contains { ProcessInfo.processInfo.arguments.contains($0) }

    /// The start screen comes first, after the splash, with a game left
    /// open or without. The test hooks skip it, as they skip the splash.
    @State private var showsStart = Launch.showsStartScreen

    /// The splash is for a start by hand, and for a new game begun from the
    /// transcript. The test hooks skip it: they open on a prepared screen,
    /// and two seconds of flowers in front of it would only make the
    /// interface tests wait.
    @State private var showsSplash = !Launch.skipsIntro

    /// The game left open, in a line for the start screen.
    private var savedSummary: String? {
        guard let startState else { return nil }
        let others = startState.seating.filter { $0 != GameState.harmonyName }
        let with = others.isEmpty ? "" : " · mit " + others.formatted(.list(type: .and))
        return "Zug \(restored.turnCount + 1)\(with)"
    }

    var body: some View {
        ZStack {
            // Underneath from the start, so that the screen is laid out by
            // the time the splash fades.
            screen
            if showsSplash {
                SplashView { showsSplash = false }
                    .zIndex(1)
            }
        }
    }

    @ViewBuilder private var screen: some View {
        if showsStart {
            StartView(saved: savedSummary,
                      onContinue: { showsStart = false },
                      onNewGame: {
                          GameStore.discard()
                          restored = []
                          startState = nil
                          showsStart = false
                      })
        } else if let startState {
            OpponentTurnView(startState: startState,
                             restored: restored,
                             finished: finished,
                             onEventsChanged: { events in
                                 guard !isTestEntry else { return }
                                 GameStore.save(start: startState, events: events)
                             },
                             onNewGame: {
                                 // Back to the beginning, as if the app had
                                 // just been opened: the splash, then the
                                 // start screen, where the strength can be
                                 // set before the next game is laid out.
                                 GameStore.discard()
                                 restored = []
                                 self.startState = nil
                                 showsStart = true
                                 showsSplash = !Launch.skipsIntro
                             })
        } else {
            SetupView {
                startState = $0
                restored = []
                GameStore.save(start: $0, events: [])
            }
        }
    }
}

#Preview {
    ContentView()
}
