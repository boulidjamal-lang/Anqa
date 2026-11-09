import WidgetKit
import SwiftUI
import ActivityKit

/* Extension « SeanceEnDirect » : la séance en cours d'Askēsis sur l'écran
   verrouillé et dans la Dynamic Island. Les chronos (séance, repos) sont
   tenus par le système (Text(timerInterval:)) : rien à rafraîchir. */

private let rose = Color(red: 1.0, green: 0.416, blue: 0.663)
private let symbole = "figure.strengthtraining.traditional"

@main
struct AskesisWidgets: WidgetBundle {
    var body: some Widget {
        SeanceEnDirect()
    }
}

struct SeanceEnDirect: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SeanceAttributs.self) { contexte in
            VueEcranVerrouille(attributs: contexte.attributes, etat: contexte.state)
                .activityBackgroundTint(Color.black.opacity(0.82))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { contexte in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(contexte.attributes.titre, systemImage: symbole)
                        .font(.headline)
                        .foregroundStyle(rose)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Chrono(attributs: contexte.attributes, etat: contexte.state)
                        .font(.title3.weight(.semibold))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(contexte.state.detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Progression(etat: contexte.state)
                    }
                }
            } compactLeading: {
                Image(systemName: symbole).foregroundStyle(rose)
            } compactTrailing: {
                Chrono(attributs: contexte.attributes, etat: contexte.state)
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: symbole).foregroundStyle(rose)
            }
            .keylineTint(rose)
        }
    }
}

/// Le repos en cours en compte à rebours (rose), sinon le temps de séance.
private struct Chrono: View {
    let attributs: SeanceAttributs
    let etat: SeanceAttributs.ContentState

    var body: some View {
        if let fin = etat.reposFin, fin > Date() {
            Text(timerInterval: Date()...fin, countsDown: true)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .foregroundStyle(rose)
        } else {
            Text(timerInterval: attributs.debut...Date.distantFuture, countsDown: false)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct Progression: View {
    let etat: SeanceAttributs.ContentState

    var body: some View {
        ProgressView(value: Double(min(etat.seriesFaites, max(etat.seriesTotal, 1))), total: Double(max(etat.seriesTotal, 1)))
            .tint(rose)
    }
}

private struct VueEcranVerrouille: View {
    let attributs: SeanceAttributs
    let etat: SeanceAttributs.ContentState

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle().fill(rose.opacity(0.18))
                Image(systemName: symbole)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(rose)
            }
            .frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 4) {
                Text(attributs.titre)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(etat.detail)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                Progression(etat: etat)
                Text("\(etat.seriesFaites)/\(etat.seriesTotal) séries")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                if let fin = etat.reposFin, fin > Date() {
                    Text("Repos")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                Chrono(attributs: attributs, etat: etat)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: 96, alignment: .trailing)
            }
        }
        .padding(16)
    }
}
