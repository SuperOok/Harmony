import SwiftUI
import HarmonyEngine

/// How strongly and how long Harmony thinks.
///
/// Every setting says what it does in a sentence, and whether its standard
/// value is measured or guessed — a guessed weight is an invitation to try,
/// a measured one is not. Changes are saved at once and reach the next
/// search; one already running keeps what it started with.
struct SettingsView: View {
    @Binding var settings: EngineSettings

    private static let limits: [Int?] = [nil, 10, 20, 30, 60]

    var body: some View {
        Form {
            Section {
                Toggle("Spielende vorhersagen", isOn: $settings.forecastEnd)
                    .accessibilityIdentifier("settings-forecast")
                Picker("Bedenkzeit", selection: $settings.thinkingLimit) {
                    ForEach(Self.limits, id: \.self) { limit in
                        Text(limit.map { "\($0) Sekunden" } ?? "unbegrenzt").tag(limit)
                    }
                }
                .accessibilityIdentifier("settings-limit")
            } header: {
                Text("Vorausschau")
            } footer: {
                Text("""
                Die Vorhersage schätzt aus den genommenen Steinen, wann die \
                Spielpläne der Mitspielerinnen voll sind. Ohne sie rechnet \
                Harmony nur mit dem, was sicher ist, und glaubt, mehr Zeit zu \
                haben. Mit einer Bedenkzeit spielt sie nach Ablauf den besten \
                Zug, den sie bis dahin gefunden hat — knapp bemessen spielt \
                sie schwächer.
                """)
            }

            Section {
                Toggle("Freie Kartenplätze bewerten", isOn: $settings.priceCardSpaces)
                    .accessibilityIdentifier("settings-card-spaces")
                if settings.priceCardSpaces {
                    Stepper(value: $settings.cardSpacePrice, in: 1...20, step: 1) {
                        LabeledContent("Wert des letzten Platzes",
                                       value: settings.cardSpacePrice.formatted(.number))
                    }
                    Stepper(value: $settings.cardSpaceFullFrom, in: 1...12) {
                        LabeledContent("Voll wert ab",
                                       value: "\(settings.cardSpaceFullFrom) Restzügen")
                    }
                }
            } header: {
                SourceHeader("Tierkarten", measured: true)
            } footer: {
                Text("""
                Eine Karte lässt sich nicht abwerfen; eine schwache belegt \
                ihren Platz bis zum letzten Würfel. Mit Bewertung nimmt \
                Harmony nur, was den Platz wert ist, und wartet sonst auf eine \
                bessere. Im Selbstspiel brachte das 3,4 Punkte je Partie; \
                höhere Werte als 10 halfen nicht mehr.
                """)
            }

            Section {
                WeightRow(title: "Abschlag für Aussichten", value: $settings.outlook,
                          range: 0.5...1, step: 0.05, standard: EngineSettings.standard.outlook,
                          note: "Niedriger: lieber jetzt einen Würfel legen als auf einen besseren hoffen.")
                WeightRow(title: "Aussicht der Tierkarten", value: $settings.cardProspects,
                          range: 0...2, step: 0.1, standard: EngineSettings.standard.cardProspects,
                          note: "Wie viel Muster zählen, die erst noch entstehen.")
                WeightRow(title: "Aussicht der Landschaften", value: $settings.landscapeProspects,
                          range: 0...2, step: 0.1,
                          standard: EngineSettings.standard.landscapeProspects,
                          note: "Flüsse, Inseln, Berge, Felder, Bäume und Gebäude im Werden.")
                WeightRow(title: "Offene Möglichkeiten", value: $settings.variety,
                          range: 0...0.2, step: 0.01, standard: EngineSettings.standard.variety,
                          note: "Ein kleiner Bonus je Muster, das noch entstehen kann.")
            } header: {
                SourceHeader("Gewichte", measured: false)
            } footer: {
                Text("""
                Gemessen an den Punkten, die jetzt schon zählen. Diese Werte \
                sind geschätzt, nicht gemessen — hier darf ausprobiert werden.
                """)
            }

            Section {
                Button("Auf Standard zurücksetzen", role: .destructive) {
                    settings = .standard
                }
                .disabled(settings.isStandard)
                .accessibilityIdentifier("settings-reset")
            } footer: {
                Text("Änderungen gelten ab dem nächsten Zug, den Harmony rechnet.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(IconFlower.background.ignoresSafeArea())
        .navigationTitle("Spielstärke")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarVisibility(.visible, for: .navigationBar)
        .onChange(of: settings) { _, new in SettingsStore.save(new) }
    }
}

/// A section title that says where its standard values come from.
private struct SourceHeader: View {
    let title: String
    let measured: Bool

    init(_ title: String, measured: Bool) {
        self.title = title
        self.measured = measured
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(measured ? "gemessen" : "geschätzt")
                .font(.caption2.weight(.semibold))
                .textCase(.none)
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background((measured ? Color.green : Color.orange).opacity(0.25),
                            in: .capsule)
        }
    }
}

/// One weight: its value, a slider and what it does.
private struct WeightRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let standard: Double
    let note: String

    private var digits: Int { step < 0.1 ? 2 : (step < 1 ? (step == 0.05 ? 2 : 1) : 0) }

    private func shown(_ x: Double) -> String {
        x.formatted(.number.precision(.fractionLength(digits)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(shown(value))
                    .monospacedDigit()
                    .foregroundStyle(abs(value - standard) < step / 2 ? .secondary : .primary)
            }
            Slider(value: $value, in: range, step: step)
                .accessibilityLabel(title)
                .accessibilityValue(shown(value))
            Text("\(note) Standard: \(shown(standard)).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    @Previewable @State var settings = EngineSettings()
    NavigationStack { SettingsView(settings: $settings) }
        .preferredColorScheme(.dark)
}
