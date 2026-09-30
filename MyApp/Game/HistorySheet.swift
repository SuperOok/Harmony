import SwiftUI

/// The transcript, and the three ways out of a game gone wrong: undo,
/// correcting the board, throwing the game away.
///
/// Störfall B lives next to Störfall A, because both repair the same thing
/// from different sides: undo takes back what was entered wrongly, the
/// correction takes in what was played wrongly. Neither belongs on the
/// screen of the running turn.
struct HistorySheet: View {
    let history: [LogEntry]
    let canUndo: Bool
    /// Each of these is also expected to close the sheet.
    let onUndo: () -> Void
    let onShowRationale: (MoveRationale) -> Void
    let onCorrect: () -> Void
    let onNewGame: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if history.isEmpty {
                    ContentUnavailableView("Noch kein Zug erfasst", systemImage: "list.bullet")
                } else {
                    List(history) { entry in
                        HStack {
                            Text(entry.line).font(.system(.footnote, design: .monospaced))
                            Spacer()
                            trailing(of: entry)
                        }
                    }
                }
            }
            .navigationTitle("Verlauf")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zurücknehmen", systemImage: "arrow.uturn.backward", action: onUndo)
                        .disabled(!canUndo)
                        .accessibilityIdentifier("undo")
                }
            }
            .safeAreaInset(edge: .bottom) { footer }
        }
    }

    @ViewBuilder private func trailing(of entry: LogEntry) -> some View {
        if let rationale = entry.rationale {
            Button {
                onShowRationale(rationale)
            } label: {
                Label("Warum", systemImage: "questionmark.circle")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
        } else if let taps = entry.taps {
            Text("\(taps) ×")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        } else {
            // A correction stays visible as one. That is not decoration: it
            // is the deterrent that keeps the way from being used to improve
            // Harmony's move.
            Image(systemName: "wrench.adjustable")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Button(action: onCorrect) {
                Label("Tableau berichtigen", systemImage: "wrench.adjustable")
                    .font(.callout)
            }
            .accessibilityIdentifier("correct-board")

            Text("Nur wenn auf dem Tisch etwas anderes liegt als hier.")
                .font(.caption).foregroundStyle(.secondary)

            Divider().padding(.vertical, 4)

            // A game outlives the device being put away; without this way
            // out one could never leave the last one.
            Button(role: .destructive, action: onNewGame) {
                Label("Neue Partie", systemImage: "trash").font(.callout)
            }
            .accessibilityIdentifier("new-game")

            Text("Verwirft den gespeicherten Stand und kehrt zum Start zurück.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10).padding(.bottom, 8)
        .background(.bar)
    }
}
