import WidgetKit
import SwiftUI
import UIKit

/* Les widgets d'Askēsis : « Ma journée » (calories restantes, macros, eau ;
   aussi en cercle et en rectangle sur l'écran verrouillé), « Prochaine
   séance » (un toucher la lance) et « Poids » (tendance). Ils dessinent le
   résumé que la page publie dans le groupe d'apps (voir ResumeAskesis.swift)
   et se redessinent à chaque publication et à minuit. Chaque toucher ouvre
   l'app par une adresse askesis://…, que la page interprète. */

private let accent = Color(UIColor { trait in
    trait.userInterfaceStyle == .dark
        ? UIColor(red: 1.0, green: 0.416, blue: 0.663, alpha: 1)
        : UIColor(red: 0.839, green: 0.141, blue: 0.431, alpha: 1)
})
private let couleurProteines = Color(red: 0.894, green: 0.341, blue: 0.373)
private let couleurGlucides = Color(red: 0.875, green: 0.604, blue: 0.176)
private let couleurLipides = Color(red: 0.541, green: 0.416, blue: 0.878)
private let couleurEau = Color(red: 0.196, green: 0.678, blue: 0.902)

private func fr(_ v: Double, _ decimales: Int = 1) -> String {
    String(format: "%.\(decimales)f", v).replacingOccurrences(of: ".", with: ",")
}

private func litres(_ ml: Int) -> String {
    ml < 1000 ? "\(ml) ml" : fr(Double(ml) / 1000, ml % 1000 == 0 ? 0 : 1) + " L"
}

private func adresse(_ chemin: String) -> URL? {
    URL(string: "askesis://" + chemin)
}

// MARK: - Données

struct EntreeResume: TimelineEntry {
    let date: Date
    let resume: ResumeAskesis?
}

struct FournisseurResume: TimelineProvider {
    func placeholder(in context: Context) -> EntreeResume {
        EntreeResume(date: Date(), resume: ResumeAskesis.exemple())
    }

    func getSnapshot(in context: Context, completion: @escaping (EntreeResume) -> Void) {
        completion(EntreeResume(date: Date(), resume: context.isPreview ? ResumeAskesis.exemple() : ResumeAskesis.lire()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EntreeResume>) -> Void) {
        let maintenant = Date()
        let minuit = Calendar.current.startOfDay(for: maintenant).addingTimeInterval(86400)
        let resume = ResumeAskesis.lire()
        // La même donnée à minuit : la vue repart alors de zéro pour le nouveau jour.
        let entrees = [EntreeResume(date: maintenant, resume: resume), EntreeResume(date: minuit, resume: resume)]
        completion(Timeline(entries: entrees, policy: .after(minuit.addingTimeInterval(60))))
    }
}

// MARK: - Habillage commun

/// Le fond système (iOS 17 : le conteneur du widget ; avant : un fond et des marges).
private struct FondWidget: ViewModifier {
    let accessoire: Bool

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.containerBackground(for: .widget) {
                if accessoire { Color.clear } else { Color(UIColor.systemBackground) }
            }
        } else if accessoire {
            content
        } else {
            content.padding(14).background(Color(UIColor.systemBackground))
        }
    }
}

private extension WidgetFamily {
    var accessoire: Bool {
        switch self {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline: return true
        default: return false
        }
    }
}

private struct Vide: View {
    let texte: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "figure.strengthtraining.traditional").font(.title3).foregroundStyle(accent)
            Text(texte).font(.footnote).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct Barre: View {
    let part: Double
    let couleur: Color

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(couleur.opacity(0.18))
                Capsule().fill(couleur).frame(width: max(0, min(1, part)) * g.size.width)
            }
        }
        .frame(height: 5)
    }
}

// MARK: - Ma journée

struct JourneeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Journee", provider: FournisseurResume()) { entree in
            VueJournee(entree: entree)
        }
        .configurationDisplayName("Ma journée")
        .description("Ce qu'il te reste à manger, tes macros et ton eau.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

private struct VueJournee: View {
    @Environment(\.widgetFamily) private var famille
    let entree: EntreeResume

    var body: some View {
        Group {
            if let j = entree.resume?.journeeCourante {
                switch famille {
                case .accessoryCircular: cercle(j)
                case .accessoryRectangular: rectangle(j)
                case .systemMedium: moyen(j)
                default: petit(j)
                }
            } else if famille.accessoire {
                Text("Askēsis").font(.caption)
            } else {
                Vide(texte: "Ouvre Askēsis pour voir ta journée ici.")
            }
        }
        .modifier(FondWidget(accessoire: famille.accessoire))
        .widgetURL(adresse("repas"))
    }

    private func petit(_ j: ResumeAskesis.Journee) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Il te reste").font(.caption).foregroundStyle(.secondary)
            (Text("\(j.kcalRestantes)").font(.system(size: 34, weight: .bold, design: .rounded))
                + Text(" kcal").font(.subheadline.weight(.medium)).foregroundColor(.secondary))
                .minimumScaleFactor(0.7).lineLimit(1)
            Spacer(minLength: 4)
            VStack(spacing: 5) {
                Barre(part: part(j.proteines, j.proteinesCible), couleur: couleurProteines)
                Barre(part: part(j.glucides, j.glucidesCible), couleur: couleurGlucides)
                Barre(part: part(j.lipides, j.lipidesCible), couleur: couleurLipides)
            }
            HStack(spacing: 4) {
                Image(systemName: "drop.fill").font(.caption2).foregroundStyle(couleurEau)
                Text(litres(j.eauMl)).font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func moyen(_ j: ResumeAskesis.Journee) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(accent.opacity(0.16), lineWidth: 9)
                Circle().trim(from: 0, to: CGFloat(j.part))
                    .stroke(accent, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(j.kcalRestantes)").font(.system(size: 22, weight: .bold, design: .rounded)).minimumScaleFactor(0.7).lineLimit(1)
                    Text("restantes").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(width: 96, height: 96)
            VStack(alignment: .leading, spacing: 7) {
                macro("Protéines", j.proteines, j.proteinesCible, couleurProteines)
                macro("Glucides", j.glucides, j.glucidesCible, couleurGlucides)
                macro("Lipides", j.lipides, j.lipidesCible, couleurLipides)
                HStack {
                    Image(systemName: "drop.fill").font(.caption2).foregroundStyle(couleurEau)
                    Text("\(litres(j.eauMl)) / \(litres(j.eauCibleMl))").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    if let url = adresse("eau?ml=250") {
                        Link(destination: url) {
                            Text("+ 250 ml").font(.caption2.weight(.semibold)).foregroundStyle(accent)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Capsule().fill(accent.opacity(0.14)))
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func macro(_ nom: String, _ valeur: Int, _ cible: Int, _ couleur: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(nom).font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("\(valeur) / \(cible) g").font(.caption2.weight(.semibold)).monospacedDigit()
            }
            Barre(part: part(valeur, cible), couleur: couleur)
        }
    }

    private func cercle(_ j: ResumeAskesis.Journee) -> some View {
        Gauge(value: Double(min(j.kcalConsommees, j.kcalCible)), in: 0...Double(max(1, j.kcalCible))) {
            Image(systemName: "fork.knife")
        } currentValueLabel: {
            Text("\(j.kcalRestantes)").font(.system(.body, design: .rounded).weight(.semibold)).minimumScaleFactor(0.6)
        }
        .gaugeStyle(.accessoryCircular)
    }

    private func rectangle(_ j: ResumeAskesis.Journee) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Askēsis · il te reste").font(.caption2).foregroundStyle(.secondary)
            Text("\(j.kcalRestantes) kcal").font(.headline).minimumScaleFactor(0.8).lineLimit(1)
            Text("\(j.proteines)/\(j.proteinesCible) g prot. · \(litres(j.eauMl))").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func part(_ v: Int, _ cible: Int) -> Double {
        cible > 0 ? Double(v) / Double(cible) : 0
    }
}

// MARK: - Prochaine séance

struct ProchaineSeanceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ProchaineSeance", provider: FournisseurResume()) { entree in
            VueSeance(entree: entree)
        }
        .configurationDisplayName("Prochaine séance")
        .description("Ta séance du jour ou la prochaine, lancée d'un toucher.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct VueSeance: View {
    @Environment(\.widgetFamily) private var famille
    let entree: EntreeResume

    private var seance: ResumeAskesis.Seance? { entree.resume?.seance }

    private var lien: URL? {
        guard let s = seance else { return adresse("seance") }
        if s.enCours { return adresse("seance") }
        let id = (s.id ?? "").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return adresse(id.isEmpty ? "seance/demarrer" : "seance/demarrer?id=\(id)")
    }

    var body: some View {
        Group {
            if let s = seance {
                if famille == .systemMedium { moyen(s) } else { petit(s) }
            } else {
                Vide(texte: "Crée ton premier programme dans Askēsis : il se lancera d'ici.")
            }
        }
        .modifier(FondWidget(accessoire: false))
        .widgetURL(lien)
    }

    private func petit(_ s: ResumeAskesis.Seance) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(s.enCours ? "En cours" : s.titre).font(.caption).foregroundStyle(s.enCours ? accent : .secondary).lineLimit(1)
            Text(s.nom).font(.system(size: 22, weight: .bold, design: .rounded)).lineLimit(2).minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            HStack(alignment: .bottom) {
                Text("\(s.exercices) exos · \(s.series) séries").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                bouton
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func moyen(_ s: ResumeAskesis.Seance) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(s.enCours ? "En cours" : s.titre).font(.caption).foregroundStyle(s.enCours ? accent : .secondary).lineLimit(1)
                Text(s.nom).font(.system(size: 26, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.7)
                if !s.muscles.isEmpty {
                    Text(s.muscles).font(.footnote).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer(minLength: 2)
                Text("\(s.exercices) exercice\(s.exercices > 1 ? "s" : "") · \(s.series) séries").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            bouton.scaleEffect(1.35)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var bouton: some View {
        ZStack {
            Circle().fill(accent)
            Image(systemName: seance?.enCours == true ? "arrow.right" : "play.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .offset(x: seance?.enCours == true ? 0 : 1)
        }
        .frame(width: 30, height: 30)
    }
}

// MARK: - Poids

struct PoidsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Poids", provider: FournisseurResume()) { entree in
            VuePoids(entree: entree)
        }
        .configurationDisplayName("Poids")
        .description("Ta dernière pesée et la tendance des derniers jours.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct VuePoids: View {
    @Environment(\.widgetFamily) private var famille
    let entree: EntreeResume

    var body: some View {
        Group {
            if let p = entree.resume?.poids, let dernier = p.dernier {
                contenu(p, dernier)
            } else {
                Vide(texte: "Pèse-toi dans Askēsis : ta tendance s'affichera ici.")
            }
        }
        .modifier(FondWidget(accessoire: false))
        .widgetURL(adresse("poids"))
    }

    private func contenu(_ p: ResumeAskesis.Poids, _ dernier: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text("Poids").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if famille == .systemMedium, let vise = p.vise {
                    Text("Objectif \(fr(vise)) kg").font(.caption2).foregroundStyle(.secondary)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(fr(dernier)).font(.system(size: famille == .systemMedium ? 32 : 28, weight: .bold, design: .rounded)).minimumScaleFactor(0.7).lineLimit(1)
                Text("kg").font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                Spacer()
                if let v = p.variation7j, abs(v) >= 0.05 {
                    Text((v < 0 ? "↘ −" : "↗ +") + fr(abs(v)) + " kg").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            if p.tendance.count >= 2 {
                Etincelle(valeurs: p.tendance).frame(height: famille == .systemMedium ? 46 : 34)
            }
            if famille == .systemMedium {
                Text("Tendance lissée · 7 derniers jours").font(.caption2).foregroundStyle(.secondary).padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// La courbe de tendance, du plus ancien au plus récent.
private struct Etincelle: View {
    let valeurs: [Double]

    var body: some View {
        GeometryReader { g in
            let largeur = g.size.width, hauteur = g.size.height
            let mini = valeurs.min() ?? 0, maxi = valeurs.max() ?? 1
            let amplitude = max(0.2, maxi - mini)
            let points = valeurs.enumerated().map { (i, v) -> CGPoint in
                let x = valeurs.count > 1 ? largeur * CGFloat(i) / CGFloat(valeurs.count - 1) : 0
                let y = hauteur - 3 - (hauteur - 6) * CGFloat((v - mini) / amplitude)
                return CGPoint(x: x, y: y)
            }
            ZStack {
                Path { chemin in
                    guard let premier = points.first, let dernier = points.last else { return }
                    chemin.move(to: CGPoint(x: premier.x, y: hauteur))
                    chemin.addLine(to: premier)
                    points.dropFirst().forEach { chemin.addLine(to: $0) }
                    chemin.addLine(to: CGPoint(x: dernier.x, y: hauteur))
                    chemin.closeSubpath()
                }
                .fill(Color.primary.opacity(0.07))
                Path { chemin in
                    guard let premier = points.first else { return }
                    chemin.move(to: premier)
                    points.dropFirst().forEach { chemin.addLine(to: $0) }
                }
                .stroke(Color.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                if let dernier = points.last {
                    Circle().fill(accent).frame(width: 7, height: 7).position(dernier)
                }
            }
        }
    }
}
