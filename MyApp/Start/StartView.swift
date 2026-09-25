import SwiftUI
import HarmonyEngine

/// The screen after the splash: the name, the way into a game, and the two
/// things one looks up outside a game — how strongly Harmony plays, and
/// what she is.
///
/// On the icon's background, so the splash fades into it without a change
/// of light.
struct StartView: View {
    /// A game left open, in a line — or nothing.
    var saved: String?
    var onContinue: () -> Void
    var onNewGame: () -> Void

    @State private var confirmingNewGame = false
    /// Read when the screen appears and after the settings close, so the
    /// line under "Spielstärke" says what is set.
    @State private var settings = SettingsStore.load()

    var body: some View {
        NavigationStack {
            ZStack {
                IconFlower.background.ignoresSafeArea()

                // Centred when it fits, scrollable when it does not — a
                // phone on its side has less height than the column needs.
                GeometryReader { proxy in
                    ScrollView {
                        VStack(spacing: 32) {
                            header
                            actions
                            links
                            Text(AppVersion.line)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 32)
                        .frame(maxWidth: 520)
                        .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                    }
                }
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
            .navigationDestination(for: StartLink.self) { link in
                switch link {
                case .settings: SettingsView(settings: $settings)
                case .about: AboutView()
                }
            }
        }
        .confirmationDialog("Die angefangene Partie verwerfen?",
                            isPresented: $confirmingNewGame, titleVisibility: .visible) {
            Button("Verwerfen und neu beginnen", role: .destructive, action: onNewGame)
                .accessibilityIdentifier("start-discard")
        } message: {
            Text("Sie lässt sich danach nicht wiederherstellen.")
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            IconFlowerView()
                .frame(width: 200, height: 200)
                .padding(.bottom, -24)
            Text("Harmony")
                .font(.system(size: 46, weight: .semibold, design: .rounded))
                .tracking(3)
                .foregroundStyle(IconFlower.centre)
            Text("Die Mitspielerin für Harmonies")
                .font(.headline)
                .foregroundStyle(IconFlower.centre.opacity(0.7))
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var actions: some View {
        VStack(spacing: 12) {
            if let saved {
                Button(action: onContinue) {
                    VStack(spacing: 2) {
                        Text("Partie fortsetzen").font(.headline)
                        Text(saved).font(.caption).opacity(0.8)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("start-continue")
            }
            Button {
                if saved == nil { onNewGame() } else { confirmingNewGame = true }
            } label: {
                Text("Neue Partie").font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(saved == nil ? AnyPrimitiveButtonStyle(.borderedProminent)
                                      : AnyPrimitiveButtonStyle(.bordered))
            .accessibilityIdentifier("start-new-game")
        }
        .controlSize(.large)
    }

    private var links: some View {
        VStack(spacing: 0) {
            NavigationLink(value: StartLink.settings) {
                row("Spielstärke", systemImage: "slider.horizontal.3",
                    value: settings.isStandard ? "Standard" : "angepasst")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("start-settings")
            Divider().padding(.leading, 52)
            NavigationLink(value: StartLink.about) {
                row("Über Harmony", systemImage: "info.circle", value: nil)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("start-about")
        }
        .background(.white.opacity(0.06), in: .rect(cornerRadius: 14))
    }

    private func row(_ title: String, systemImage: String, value: String?) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .frame(width: 24)
                .foregroundStyle(IconFlower.centre.opacity(0.8))
            Text(title).foregroundStyle(.primary)
            Spacer()
            if let value { Text(value).foregroundStyle(.secondary) }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

private enum StartLink: Hashable { case settings, about }

/// Two button styles behind one type, since `buttonStyle` wants one.
private struct AnyPrimitiveButtonStyle: PrimitiveButtonStyle {
    private let make: (Configuration) -> AnyView

    init<S: PrimitiveButtonStyle>(_ style: S) {
        make = { AnyView(style.makeBody(configuration: $0)) }
    }

    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}

/// The version as the About screen and the start screen show it.
enum AppVersion {
    static var short: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
    }
    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
    }
    static var line: String { "Version \(short) (\(build))" }
}

#Preview("Mit Partie") {
    StartView(saved: "Zug 12 · mit Anke und Bernd", onContinue: {}, onNewGame: {})
        .preferredColorScheme(.dark)
}

#Preview("Ohne Partie") {
    StartView(saved: nil, onContinue: {}, onNewGame: {})
        .preferredColorScheme(.dark)
}
