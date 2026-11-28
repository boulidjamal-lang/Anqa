import Foundation

/* Le résumé que la page publie pour les widgets et Siri (module « Resume »,
   voir Resume.swift), rangé dans le groupe d'apps partagé avec l'extension
   SeanceEnDirect, qui le lit pour dessiner ses widgets. La page reste la
   seule source : ici on ne calcule rien, on affiche. */

/// Le groupe d'apps (App Group) partagé par l'app et son extension.
let GROUPE_ASKESIS = "group.com.jambou.askesis"

struct ResumeAskesis: Codable {
    struct Journee: Codable {
        /// AAAA-MM-JJ (jour local de la page).
        var date: String
        var kcalCible: Int
        var kcalConsommees: Int
        var proteines: Int
        var proteinesCible: Int
        var glucides: Int
        var glucidesCible: Int
        var lipides: Int
        var lipidesCible: Int
        var eauMl: Int
        var eauCibleMl: Int
        var pas: Int?

        var kcalRestantes: Int { max(0, kcalCible - kcalConsommees) }
        var part: Double { kcalCible > 0 ? min(1, Double(kcalConsommees) / Double(kcalCible)) : 0 }
    }

    struct Seance: Codable {
        var id: String?
        /// « Push », « Jambes »…
        var nom: String
        /// « Prochaine séance · demain soir », « Séance du jour », « En cours ».
        var titre: String
        /// « Quadriceps, Abdominaux, Épaules »
        var muscles: String
        var exercices: Int
        var series: Int
        var enCours: Bool
    }

    struct Poids: Codable {
        var dernier: Double?
        var date: String?
        var vise: Double?
        /// Tendance lissée, des plus anciennes aux plus récentes (jusqu'à 14 valeurs).
        var tendance: [Double]
        var variation7j: Double?
    }

    var journee: Journee?
    var seance: Seance?
    var poids: Poids?
    /// Date de publication (millisecondes, Date.now() côté page).
    var maj: Double

    static var defauts: UserDefaults? { UserDefaults(suiteName: GROUPE_ASKESIS) }
    private static let cle = "resume"

    static func lire() -> ResumeAskesis? {
        guard let data = defauts?.data(forKey: cle) else { return nil }
        return try? JSONDecoder().decode(ResumeAskesis.self, from: data)
    }

    func ecrire() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        Self.defauts?.set(data, forKey: Self.cle)
    }

    /// Le jour local au format de la page (AAAA-MM-JJ).
    static func aujourdhui(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// La journée telle qu'elle vaut maintenant : passé minuit, les compteurs
    /// repartent de zéro avec la cible de la veille, jusqu'à ce que la page
    /// publie à nouveau.
    var journeeCourante: Journee? {
        guard var j = journee else { return nil }
        if j.date != Self.aujourdhui() {
            j.date = Self.aujourdhui()
            j.kcalConsommees = 0; j.proteines = 0; j.glucides = 0; j.lipides = 0; j.eauMl = 0; j.pas = nil
        }
        return j
    }

    /// Des valeurs de démonstration : galerie des widgets et aperçus.
    static func exemple() -> ResumeAskesis {
        ResumeAskesis(
            journee: Journee(date: aujourdhui(), kcalCible: 2150, kcalConsommees: 1320, proteines: 96, proteinesCible: 160,
                             glucides: 140, glucidesCible: 230, lipides: 44, lipidesCible: 70, eauMl: 1250, eauCibleMl: 2500, pas: 6410),
            seance: Seance(id: nil, nom: "Push", titre: "Prochaine séance · ce soir", muscles: "Pectoraux, Épaules, Triceps", exercices: 5, series: 15, enCours: false),
            poids: Poids(dernier: 78.9, date: aujourdhui(), vise: 76, tendance: [80.4, 80.2, 80.0, 79.8, 79.7, 79.4, 79.2, 79.1, 78.9], variation7j: -0.6),
            maj: Date().timeIntervalSince1970 * 1000)
    }
}

/// L'action demandée par Siri ou un widget (une URL askesis://…), gardée
/// jusqu'à ce que la page, revenue au premier plan, la prenne (module
/// « Resume », méthode intention()).
enum IntentionAskesis {
    private static let cle = "intention"

    static func poser(_ url: String) {
        ResumeAskesis.defauts?.set(url, forKey: cle)
    }

    static func prendre() -> String? {
        guard let d = ResumeAskesis.defauts, let url = d.string(forKey: cle) else { return nil }
        d.removeObject(forKey: cle)
        return url
    }
}
