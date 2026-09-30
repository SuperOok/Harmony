import SwiftUI

/// Störfall C: what does this move bring, and what would the alternative
/// have been. A number without a comparison answers neither — "this move
/// brings 14" means nothing until the next best one is known.
struct RationaleSheet: View {
    let rationale: MoveRationale

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    TitledBlock("Was der Zug bringt") {
                        VStack(spacing: 10) {
                            ForEach(Array(rationale.terms.enumerated()), id: \.offset) { _, term in
                                termRow(term)
                            }
                            Divider()
                            HStack {
                                Text("Punkte jetzt").font(.callout.weight(.semibold))
                                Spacer()
                                Text("\(rationale.immediate)")
                                    .font(.callout.monospacedDigit().weight(.bold))
                            }
                            if rationale.isProspective {
                                HStack {
                                    Text("Bewertung der Stellung").font(.callout.weight(.semibold))
                                    Spacer()
                                    Text("\(rationale.value)")
                                        .font(.callout.monospacedDigit().weight(.bold))
                                }
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Aussichten sind Erwartungswerte, keine Punkte: "
                                         + "der Gewinn mal der Wahrscheinlichkeit, ihn zu "
                                         + "erreichen, danach mit dem Abschlag für Aussichten "
                                         + "gewichtet (der Pfeil zeigt, was daraus wird). "
                                         + "Boni und Preise ohne Punkte steuern nur die Wahl. "
                                         + "Verglichen wird auf der Bewertung — "
                                         + "sonst könnte ein Zug ohne sofortige Punkte nie "
                                         + "der beste sein.")
                                    if let note = rationale.probabilityNote {
                                        Text(note)
                                    }
                                }
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    TitledBlock("Die Alternative") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(rationale.runnerUp).font(.callout)
                            HStack {
                                Text(rationale.isProspective
                                     ? "\(rationale.runnerUpImmediate) Punkte jetzt, "
                                       + "Bewertung \(rationale.runnerUpValue)"
                                     : "\(rationale.runnerUpValue) Punkte")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            Text("Abstand: \(rationale.gap)")
                                .font(.callout.weight(.semibold))
                            Text(rationale.gapExplanation)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Begründung")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private func termRow(_ term: ScoreTerm) -> some View {
        HStack(alignment: .firstTextBaseline) {
            if term.kind != .points {
                Image(systemName: term.kind == .prospect
                      ? "arrow.turn.right.up" : "slider.horizontal.3")
                    .font(.caption2)
                    .foregroundStyle(.tint)
            }
            Text(term.name)
                .font(.callout)
                .foregroundStyle(term.kind == .points ? .primary : .secondary)
            Spacer(minLength: 12)
            if term.points > 0 {
                Text(value(of: term))
                    .font(.callout.monospacedDigit()
                        .weight(term.kind == .points ? .semibold : .regular))
                    .foregroundStyle(term.kind == .points ? .primary : .secondary)
            }
        }
    }

    /// A term's number as the reason shows it: points with a plus, a
    /// prospect as gain times probability and what came of it after the
    /// weights, a steering term in brackets.
    private func value(of term: ScoreTerm) -> String {
        switch term.kind {
        case .points:
            return "+\(term.points)"
        case .prospect:
            guard let gain = term.gain, let probability = term.probability else {
                return "(\(term.points))"
            }
            return "\(gain) × \(Int((probability * 100).rounded())) % → \(term.points)"
        case .steering:
            return "(\(term.points))"
        }
    }
}
