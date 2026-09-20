import SwiftUI
import HarmonyRules
import HarmonyEngine

/// What the search is doing, while it does it.
///
/// `docs/06-durchstich.md` measures 110 Sekunden für eine halbe Stellung und
/// rechnet bis zu 17 Minuten für die frühe Partie hoch. Ein Bildschirm, der
/// so lange nichts sagt, ist von einem hängenden nicht zu unterscheiden —
/// und am Tisch legt dann jemand das Gerät weg und spielt etwas Ausgedachtes.
///
/// Gezeigt wird deshalb nur, was die Suche billig über sich weiß
/// (`SearchProgress`), und dazu der eine Knopf, der dem Warten ein Ende
/// macht: Abkürzen gibt den besten bisher gefundenen Zug heraus.
struct ThinkingView: View {
    /// Where the running search leaves its reports.
    let monitor: SearchMonitor
    /// When this search began. The clock runs against this rather than
    /// against a counter of its own, so it stays right when the app was
    /// away in between.
    let started: Date
    /// How many turns have been played — the figure that says why this
    /// position takes as long as it does.
    let turnsPlayed: Int
    /// Ends the search. Not giving up: what comes back is the best turn
    /// found so far.
    var onStop: () -> Void
    /// Leaves the screen; the search runs on.
    var onHide: () -> Void

    var body: some View {
        NavigationStack {
            // Viermal in der Sekunde: oft genug, dass Sekunden wie Sekunden
            // aussehen, selten genug, dass es die Suche nichts kostet.
            //
            // Die Zeitschiene umschließt auch die Fußzeile. Läge der Knopf
            // außerhalb, bliebe er in dem Zustand stehen, den die Suche in
            // ihrer ersten Viertelsekunde hatte — also gesperrt, für immer.
            TimelineView(.periodic(from: started, by: 0.25)) { context in
                // Einmal gefragt, mehrfach gezeigt: jede Abfrage nimmt das
                // Schloss, das die Suche für ihre Meldungen braucht.
                let progress = monitor.current

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        clock(at: context.date)
                        numbers(at: context.date, progress)
                        reach(progress)
                        bestSoFar(progress)
                        note
                    }
                    .padding()
                }
                .safeAreaInset(edge: .bottom) { footer(progress) }
            }
            .navigationTitle("Harmony rechnet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Ausblenden", action: onHide)
                        .accessibilityIdentifier("thinking-hide")
                }
            }
        }
        .accessibilityIdentifier("thinking-screen")
    }

    // MARK: - Die Uhr

    private func clock(at now: Date) -> some View {
        let elapsed = max(0, now.timeIntervalSince(started))
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                ProgressView().controlSize(.small)
                Text(clockText(elapsed))
                    .font(.system(size: 44, weight: .semibold, design: .rounded)
                        .monospacedDigit())
                    .accessibilityIdentifier("thinking-elapsed")
            }
            Text("seit dem Eintrag des letzten gegnerischen Zugs")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func clockText(_ elapsed: TimeInterval) -> String {
        let seconds = Int(elapsed.rounded())
        return seconds < 60
            ? String(format: "%d s", seconds)
            : String(format: "%d:%02d min", seconds / 60, seconds % 60)
    }

    // MARK: - Die Zahlen

    private func numbers(at now: Date, _ progress: SearchProgress?) -> some View {
        let elapsed = max(0.001, now.timeIntervalSince(started))
        let weighed = progress?.weighed ?? 0
        return TitledBlock("Was gewogen wurde") {
            VStack(spacing: 0) {
                StatRow(name: "Geprüfte Züge",
                        value: weighed.formatted(),
                        identifier: "thinking-weighed")
                Divider()
                StatRow(name: "Tempo",
                        value: weighed == 0
                            ? "—"
                            : "\(Int(Double(weighed) / elapsed).formatted()) Züge/s")
                Divider()
                StatRow(name: "Gespielte Züge", value: "\(turnsPlayed)")
            }
            .padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground)))
        }
    }

    // MARK: - Wie weit

    /// Der einzige ehrliche Bruch, den die Suche hergibt.
    ///
    /// Innerhalb eines Auslagefelds ist nichts vorher zählbar — das wäre
    /// genau das Aufzählen aller Züge, das die Suche vermeidet. Zwischen den
    /// Feldern dagegen ist alles zählbar. Der Balken zählt Felder, und der
    /// Text darunter sagt, dass er das tut.
    @ViewBuilder private func reach(_ progress: SearchProgress?) -> some View {
        if let progress, progress.spacesTotal > 0 {
            TitledBlock("Wie weit") {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: Double(progress.spacesDone),
                                 total: Double(progress.spacesTotal))
                    Text("Auslagefeld \(min(progress.spacesDone + 1, progress.spacesTotal)) "
                         + "von \(progress.spacesTotal) — "
                         + (progress.spacesTotal == 1
                            ? "gleiche Felder zählen als eines."
                            : "jedes Feld wird ganz durchgerechnet."))
                        .font(.footnote).foregroundStyle(.secondary)
                        .accessibilityIdentifier("thinking-spaces")
                }
            }
        }
    }

    // MARK: - Der beste bisher

    @ViewBuilder private func bestSoFar(_ progress: SearchProgress?) -> some View {
        TitledBlock("Bester Zug bisher") {
            if let best = progress?.best {
                VStack(alignment: .leading, spacing: 6) {
                    Text(engineNotation(best))
                        .font(.system(.body, design: .monospaced))
                        .accessibilityIdentifier("thinking-best")
                    if let value = progress?.bestValue {
                        Text("Bewertung \(Int(value.rounded()))")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Text("Diesen Zug gibt die Suche heraus, wenn jetzt "
                         + "abgekürzt wird.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14).padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground)))
            } else {
                Text("Noch keiner. Die ersten Züge sind in Arbeit.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    private var note: some View {
        Text("Harmony wägt jeden möglichen Zug einzeln ab. Wie lange das "
             + "dauert, hängt an der Stellung: je leerer der Spielplan, desto "
             + "mehr Möglichkeiten. Abkürzen verwirft nichts — es nimmt den "
             + "besten Zug, der bis dahin gefunden wurde, und sagt beim "
             + "Vorschlag dazu, dass abgekürzt wurde.")
            .font(.footnote).foregroundStyle(.secondary)
    }

    private func footer(_ progress: SearchProgress?) -> some View {
        VStack(spacing: 8) {
            Button(action: onStop) {
                Text("Abkürzen und besten Zug nehmen")
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(progress?.best == nil)
            .accessibilityIdentifier("thinking-stop")

            if progress?.best == nil {
                Text("Abkürzen geht, sobald ein erster Zug gewogen ist.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal).padding(.vertical, 8)
        .background(.bar)
    }
}

/// Eine Zeile aus Name und Zahl. Die Zahl rechts und mit gleich breiten
/// Ziffern, damit sie beim Hochzählen nicht springt.
private struct StatRow: View {
    let name: String
    let value: String
    var identifier: String?

    var body: some View {
        HStack {
            Text(name).font(.callout)
            Spacer()
            Text(value)
                .font(.callout.monospacedDigit().weight(.medium))
                .accessibilityIdentifier(identifier ?? name)
        }
        .padding(.vertical, 11)
    }
}
