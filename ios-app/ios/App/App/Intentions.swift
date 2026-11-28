import Foundation
import AppIntents

/* Raccourcis et Siri (iOS 16 et plus), proposés d'eux-mêmes dans l'app
   Raccourcis et à la voix :
   - « Démarre ma séance »  : ouvre l'app sur la séance du jour, lancée ;
   - « Ajoute un verre d'eau » (quantité réglable) : ouvre l'app et note l'eau ;
   - « Mon bilan » : Siri répond avec le résumé publié par la page (calories
     restantes, protéines, séance, eau), sans ouvrir l'app.
   Les deux premières laissent une intention (askesis://…) que la page prend
   quand elle revient au premier plan (module « Resume »), car les données
   vivent dans la page : rien n'est modifié hors d'elle. */

@available(iOS 16.0, *)
struct DemarrerSeanceIntent: AppIntent {
    static var title: LocalizedStringResource = "Démarrer ma séance"
    static var description = IntentDescription("Ouvre Askēsis et lance la séance du jour.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentionAskesis.poser("askesis://seance/demarrer")
        return .result()
    }
}

@available(iOS 16.0, *)
struct AjouterEauIntent: AppIntent {
    static var title: LocalizedStringResource = "Ajouter de l'eau"
    static var description = IntentDescription("Note une quantité d'eau bue dans Askēsis.")
    static var openAppWhenRun = true

    @Parameter(title: "Quantité (ml)", default: 250)
    var ml: Int

    @MainActor
    func perform() async throws -> some IntentResult {
        let quantite = max(50, min(2000, ml))
        IntentionAskesis.poser("askesis://eau?ml=\(quantite)")
        return .result()
    }
}

@available(iOS 16.0, *)
struct MonBilanIntent: AppIntent {
    static var title: LocalizedStringResource = "Mon bilan du jour"
    static var description = IntentDescription("Ce qu'il te reste à manger, ta séance et ton eau, sans ouvrir l'app.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let resume = ResumeAskesis.lire(), let j = resume.journeeCourante else {
            return .result(dialog: IntentDialog(stringLiteral: "Ouvre Askēsis une première fois pour que je connaisse ta journée."))
        }
        var phrases: [String] = []
        if j.date == ResumeAskesis.aujourdhui() && j.kcalConsommees > 0 {
            phrases.append("Il te reste \(j.kcalRestantes) kilocalories et \(max(0, j.proteinesCible - j.proteines)) grammes de protéines.")
        } else {
            phrases.append("Rien de noté aujourd'hui : \(j.kcalCible) kilocalories au programme.")
        }
        if let s = resume.seance {
            phrases.append(s.enCours ? "Ta séance \(s.nom) est en cours." : "\(s.titre) : \(s.nom), \(s.exercices) exercices.")
        }
        phrases.append("Eau : \(Self.litres(j.eauMl)) sur \(Self.litres(j.eauCibleMl)).")
        return .result(dialog: IntentDialog(stringLiteral: phrases.joined(separator: " ")))
    }

    private static func litres(_ ml: Int) -> String {
        if ml < 1000 { return "\(ml) millilitres" }
        let l = Double(ml) / 1000
        let texte = l == l.rounded() ? String(Int(l)) : String(format: "%.1f", l).replacingOccurrences(of: ".", with: ",")
        return "\(texte) litre" + (l >= 2 ? "s" : "")
    }
}

@available(iOS 16.0, *)
struct RaccourcisAskesis: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: DemarrerSeanceIntent(), phrases: [
            "Démarre ma séance dans \(.applicationName)",
            "Lance ma séance \(.applicationName)",
            "Commencer ma séance \(.applicationName)"
        ])
        AppShortcut(intent: AjouterEauIntent(), phrases: [
            "Ajoute un verre d'eau dans \(.applicationName)",
            "J'ai bu de l'eau dans \(.applicationName)",
            "Note de l'eau dans \(.applicationName)"
        ])
        AppShortcut(intent: MonBilanIntent(), phrases: [
            "Mon bilan dans \(.applicationName)",
            "Où j'en suis dans \(.applicationName)",
            "Mon résumé \(.applicationName)"
        ])
    }
}
