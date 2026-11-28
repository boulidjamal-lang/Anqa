import Foundation
import ActivityKit
import Capacitor

/* Module « ActiviteSeance » : la séance en cours en activité en direct
   (écran verrouillé et Dynamic Island), pilotée par la page :
   - demarrer({ titre, debut, detail, seriesFaites, seriesTotal, reposFin, depuis, perimeLe })
   - maj({ … })   : série cochée, repos qui démarre
   - terminer()
   `depuis` : d'où part le chrono (le début, décalé des temps morts).
   `perimeLe` : 30 min après la dernière action ; passé ce moment, iOS
   marque l'activité périmée et elle s'affiche « En pause » au lieu d'un
   chrono qui tournerait toute la nuit sur une séance oubliée (l'app ne peut
   pas la retirer elle-même tant qu'elle n'est pas rouverte).
   Les dates arrivent en millisecondes (Date.now() côté page). Sans
   autorisation (Réglages › Askēsis › Activités en direct) ou avant iOS
   16.2, rien ne s'affiche et la page n'en sait rien. */
@objc(ActiviteSeancePlugin)
public class ActiviteSeancePlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "ActiviteSeancePlugin"
    public let jsName = "ActiviteSeance"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "demarrer", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "maj", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "terminer", returnType: CAPPluginReturnPromise)
    ]

    @objc func demarrer(_ call: CAPPluginCall) {
        guard #available(iOS 16.2, *) else { call.resolve(["actif": false]); return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { call.resolve(["actif": false]); return }
        let titre = call.getString("titre") ?? "Séance"
        let debut = Self.date(call.getDouble("debut")) ?? Date()
        let etat = Self.etat(call)
        let perime = Self.date(call.getDouble("perimeLe"))
        Task { @MainActor in
            // Une seule séance à la fois : la précédente s'efface.
            for activite in Activity<SeanceAttributs>.activities {
                await activite.end(nil, dismissalPolicy: .immediate)
            }
            do {
                _ = try Activity.request(attributes: SeanceAttributs(titre: titre, debut: debut),
                                         content: ActivityContent(state: etat, staleDate: perime),
                                         pushType: nil)
                call.resolve(["actif": true])
            } catch {
                call.resolve(["actif": false, "erreur": error.localizedDescription])
            }
        }
    }

    @objc func maj(_ call: CAPPluginCall) {
        guard #available(iOS 16.2, *) else { call.resolve(); return }
        let etat = Self.etat(call)
        let perime = Self.date(call.getDouble("perimeLe"))
        Task { @MainActor in
            for activite in Activity<SeanceAttributs>.activities {
                await activite.update(ActivityContent(state: etat, staleDate: perime))
            }
            call.resolve()
        }
    }

    @objc func terminer(_ call: CAPPluginCall) {
        guard #available(iOS 16.2, *) else { call.resolve(); return }
        Task { @MainActor in
            for activite in Activity<SeanceAttributs>.activities {
                await activite.end(nil, dismissalPolicy: .immediate)
            }
            call.resolve()
        }
    }

    private static func date(_ ms: Double?) -> Date? {
        guard let ms = ms, ms > 0 else { return nil }
        return Date(timeIntervalSince1970: ms / 1000)
    }

    @available(iOS 16.2, *)
    private static func etat(_ call: CAPPluginCall) -> SeanceAttributs.ContentState {
        SeanceAttributs.ContentState(detail: call.getString("detail") ?? "",
                                     seriesFaites: call.getInt("seriesFaites") ?? 0,
                                     seriesTotal: call.getInt("seriesTotal") ?? 0,
                                     reposFin: date(call.getDouble("reposFin")),
                                     chronoDepuis: date(call.getDouble("depuis")))
    }
}
