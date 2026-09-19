import SwiftUI
import Playgrounds

struct ContentView: View {
    var body: some View {
        FremderZugView()
    }
}

#Preview {
    ContentView()
}

#Playground {
    let feld = Feld(steine: [.ziegel, .holz, .laub])
    _ = feld.notation
}
