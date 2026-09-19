import SwiftUI
import Playgrounds

struct ContentView: View {
    var body: some View {
        OpponentTurnView()
    }
}

#Preview {
    ContentView()
}

#Playground {
    let field = DisplayField(stones: [.brick, .wood, .leaves])
    _ = field.notation
}
