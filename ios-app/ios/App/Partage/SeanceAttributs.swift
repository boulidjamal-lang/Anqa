import Foundation
import ActivityKit

/* La séance en cours, telle que l'affiche l'activité en direct (écran
   verrouillé, Dynamic Island). Partagé entre l'app (qui la démarre et la
   met à jour, voir ActiviteSeance.swift) et l'extension qui la dessine
   (SeanceEnDirect). */
@available(iOS 16.1, *)
struct SeanceAttributs: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// « Développé couché · série 2/3 »
        var detail: String
        var seriesFaites: Int
        var seriesTotal: Int
        /// Fin du repos en cours (compte à rebours), s'il y en a un.
        var reposFin: Date?
    }

    /// Nom du programme (« Push », « Séance libre »).
    var titre: String
    /// Début de la séance (le chrono part de là).
    var debut: Date
}
