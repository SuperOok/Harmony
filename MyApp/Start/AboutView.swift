import SwiftUI

/// What Harmony is, which version this is, and whose game she plays.
struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(spacing: 8) {
                    IconFlowerView().frame(width: 120, height: 120)
                    Text("Harmony")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .tracking(2)
                    Text(AppVersion.line)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("about-version")
                }
                .frame(maxWidth: .infinity)

                block("Was sie ist", """
                Harmony ist eine Mitspielerin für das Brettspiel Harmonies. \
                Die Partie läuft am echten Tisch mit echtem Material. Harmony \
                verwaltet nur ihr eigenes Wissen und schlägt ihre Züge vor; \
                eine Mitspielerin trägt ein, was die anderen spielen, und legt \
                für Harmony aus.
                """)

                block("Wie sie spielt", """
                In jedem Zug rechnet sie alle Möglichkeiten durch — oft \
                Hunderttausende — und bewertet sie: Punkte, die schon zählen, \
                und Aussichten auf Muster und Landschaften, gewichtet mit der \
                Wahrscheinlichkeit, die nötigen Steine noch zu bekommen. Was \
                im Beutel liegt, weiß sie genau, weil jede Nachfüllung \
                eingetragen wird. Die fremden Spielpläne sieht sie nicht.
                """)

                block("Das Spiel", """
                Harmonies ist ein Spiel von Johan Benvenuto, erschienen bei \
                Libellud. Harmony ist ein privates Projekt und weder mit dem \
                Verlag noch mit dem Autor verbunden. Für eine Partie braucht \
                es das Spiel selbst.
                """)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Quelltext").font(.headline)
                    Link(destination: URL(string: "https://github.com/SuperOok/Harmony")!) {
                        Label("github.com/SuperOok/Harmony", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(IconFlower.background.ignoresSafeArea())
        .navigationTitle("Über Harmony")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarVisibility(.visible, for: .navigationBar)
    }

    private func block(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(text).foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack { AboutView() }
        .preferredColorScheme(.dark)
}
