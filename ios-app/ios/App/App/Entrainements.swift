import Foundation
import Capacitor
import HealthKit

/* Module « Entrainements » : la séance terminée est inscrite dans Santé
   (anneaux d'activité, historique des entraînements), avec sa dépense
   estimée par la page.
   - enregistrer({ debut, fin, type, kcal, titre }) → { enregistre, raison }
   Dates en millisecondes (Date.now() côté page) ; type : musculation, course,
   marche, velo, natation, rameur, hiit, autre. Sans Santé (iPad, refus),
   { enregistre: false } et la page n'insiste pas. */
@objc(EntrainementsPlugin)
public class EntrainementsPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "EntrainementsPlugin"
    public let jsName = "Entrainements"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "enregistrer", returnType: CAPPluginReturnPromise)
    ]

    private let magasin = HKHealthStore()

    @objc func enregistrer(_ call: CAPPluginCall) {
        guard HKHealthStore.isHealthDataAvailable() else { call.resolve(["enregistre": false, "raison": "indisponible"]); return }
        let debut = Date(timeIntervalSince1970: (call.getDouble("debut") ?? 0) / 1000)
        let fin = Date(timeIntervalSince1970: (call.getDouble("fin") ?? 0) / 1000)
        guard fin > debut, fin.timeIntervalSince(debut) < 12 * 3600 else { call.resolve(["enregistre": false, "raison": "dates"]); return }
        let activite = Self.activite(call.getString("type") ?? "musculation")
        let kcal = call.getDouble("kcal") ?? 0
        let titre = call.getString("titre") ?? ""

        var aPartager: Set<HKSampleType> = [HKObjectType.workoutType()]
        let typeEnergie = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
        if let typeEnergie = typeEnergie { aPartager.insert(typeEnergie) }

        magasin.requestAuthorization(toShare: aPartager, read: []) { [magasin] accorde, erreur in
            guard accorde else { call.resolve(["enregistre": false, "raison": erreur?.localizedDescription ?? "refuse"]); return }
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = activite
            let constructeur = HKWorkoutBuilder(healthStore: magasin, configuration: configuration, device: .local())
            constructeur.beginCollection(withStart: debut) { ok, erreur in
                guard ok else { call.resolve(["enregistre": false, "raison": erreur?.localizedDescription ?? "debut"]); return }
                var metadonnees: [String: Any] = [HKMetadataKeyWorkoutBrandName: "Askēsis"]
                if !titre.isEmpty { metadonnees["titre"] = titre }
                let terminer: () -> Void = {
                    constructeur.endCollection(withEnd: fin) { _, _ in
                        constructeur.finishWorkout { seance, erreur in
                            call.resolve(["enregistre": seance != nil, "raison": erreur?.localizedDescription ?? ""])
                        }
                    }
                }
                constructeur.addMetadata(metadonnees) { _, _ in
                    guard kcal > 0, let typeEnergie = typeEnergie else { terminer(); return }
                    let energie = HKQuantitySample(type: typeEnergie, quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kcal), start: debut, end: fin)
                    constructeur.add([energie]) { _, _ in terminer() }
                }
            }
        }
    }

    private static func activite(_ type: String) -> HKWorkoutActivityType {
        switch type.lowercased() {
        case "musculation", "muscu", "force": return .traditionalStrengthTraining
        case "course", "running", "run": return .running
        case "marche", "walking": return .walking
        case "velo", "vélo", "cycling": return .cycling
        case "natation", "swimming": return .swimming
        case "rameur", "rowing": return .rowing
        case "hiit", "fractionne", "fractionné": return .highIntensityIntervalTraining
        case "elliptique", "elliptical": return .elliptical
        case "corde", "jumprope": return .jumpRope
        default: return .other
        }
    }
}
