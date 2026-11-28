import Foundation
import Capacitor
import WidgetKit

/* Module « Resume » : la page publie l'essentiel de la journée (calories,
   macros, eau, pas), la prochaine séance et le poids ; les widgets de
   l'écran d'accueil et de l'écran verrouillé (extension SeanceEnDirect) et
   « Mon bilan » de Siri lisent ce résumé dans le groupe d'apps.
   - publier({ resume })  → { publie } ; redessine les widgets
   - intention()          → { url } : l'action laissée par Siri ou un widget
                            (askesis://…), vide s'il n'y en a pas ; prise une fois.
   La page reste la source de vérité : rien n'est recalculé ici. */
@objc(ResumePlugin)
public class ResumePlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "ResumePlugin"
    public let jsName = "Resume"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "publier", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "intention", returnType: CAPPluginReturnPromise)
    ]

    @objc func publier(_ call: CAPPluginCall) {
        guard let objet = call.getObject("resume") else { call.reject("resume manquant"); return }
        let dictionnaire = objet as [String: Any]
        guard JSONSerialization.isValidJSONObject(dictionnaire) else { call.reject("resume invalide"); return }
        do {
            let data = try JSONSerialization.data(withJSONObject: dictionnaire)
            let resume = try JSONDecoder().decode(ResumeAskesis.self, from: data)
            resume.ecrire()
            WidgetCenter.shared.reloadAllTimelines()
            call.resolve(["publie": true])
        } catch {
            call.resolve(["publie": false, "erreur": error.localizedDescription])
        }
    }

    @objc func intention(_ call: CAPPluginCall) {
        call.resolve(["url": IntentionAskesis.prendre() ?? ""])
    }
}
