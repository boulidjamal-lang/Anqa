import UIKit
import WebKit
import Capacitor

/* Barre d'onglets native d'Askēsis (iOS 26 et plus).
   La page web (index.html du dépôt Anqaa) reste l'appli ; seule la barre du
   bas devient la vraie barre d'iOS : verre liquide, bulle de sélection qui
   glisse d'un onglet à l'autre, réduction quand on fait défiler, « + » à
   part dans son cercle de verre, et la séance en cours posée au-dessus comme
   le mini-lecteur de Musique. La page masque alors sa propre barre (classe
   « onglets-natifs ») et pilote celle-ci par le module « Onglets » :
   - etat()                         → { actif } : la barre native est-elle là ?
   - selectionner({ nom })          : l'onglet de l'écran affiché
   - afficher({ visible, anime })   : cachée pendant les fenêtres, le plein écran…
   - plus({ visible, libelle })     : le « + » (caché sur Progrès)
   - accessoire({ titre, detail, depuis } | { cacher: true }) : séance en cours
   - apparence({ style })           : clair, sombre ou comme le téléphone
   Elle prévient la page par les évènements « onglet » ({ nom }), « retouche »
   (onglet déjà choisi, touché à nouveau), « plus » et « accessoire ».
   Avant iOS 26, rien de tout ça : la page garde sa barre. */

private let ORDRE_ONGLETS = ["repas", "seance", "stats", "reglages"]

/// Le rose des muscles, couleur d'accent de l'appli (clair / sombre).
let ACCENT_ASKESIS = UIColor { trait in
    trait.userInterfaceStyle == .dark
        ? UIColor(red: 1.0, green: 0.416, blue: 0.663, alpha: 1)
        : UIColor(red: 0.839, green: 0.141, blue: 0.431, alpha: 1)
}

/// Le pont Capacitor de l'appli : enregistre les modules propres à Askēsis.
class PontAskesis: CAPBridgeViewController {
    static weak var courant: PontAskesis?

    override func capacitorDidLoad() {
        PontAskesis.courant = self
        bridge?.registerPluginInstance(OngletsNatifs())
        bridge?.registerPluginInstance(ActiviteSeancePlugin())
    }
}

/// Le contrôleur racine : un onglet par écran, et la page web qui passe dans
/// l'onglet choisi (une seule page, déplacée d'un onglet à l'autre).
@available(iOS 26.0, *)
final class OngletsControleur: UITabBarController, UITabBarControllerDelegate {
    static weak var courant: OngletsControleur?

    let pont: PontAskesis
    weak var module: OngletsNatifs?
    private var conteneurs: [String: ConteneurOnglet] = [:]
    private var ongletsEcrans: [UITab] = []
    private var ongletPlus: UISearchTab?
    private var accessoireVue: AccessoireSeance?

    init(pont: PontAskesis) {
        self.pont = pont
        super.init(nibName: nil, bundle: nil)
        OngletsControleur.courant = self
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) non utilisé") }

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        let definitions: [(String, String, String)] = [
            ("repas", "Repas", "fork.knife"),
            ("seance", "Activité", "dumbbell.fill"),
            ("stats", "Progrès", "chart.line.uptrend.xyaxis"),
            ("reglages", "Profil", "person.crop.circle.fill")
        ]
        ongletsEcrans = definitions.map { definition in
            let (id, titre, symbole) = definition
            return UITab(title: titre, image: UIImage(systemName: symbole), identifier: id) { [weak self] _ in
                self?.conteneur(id) ?? UIViewController()
            }
        }
        let plus = UISearchTab { [weak self] _ in self?.conteneur("plus") ?? UIViewController() }
        plus.title = "Ajouter"
        plus.image = UIImage(systemName: "plus")
        ongletPlus = plus
        tabs = ongletsEcrans + [plus]
        tabBarMinimizeBehavior = .onScrollDown
        tabBar.tintColor = ACCENT_ASKESIS
        installerPage(dans: "repas")
        // Cachée jusqu'à ce que la page soit prête (écran de démarrage, connexion).
        isTabBarHidden = true
    }

    // MARK: - Onglets

    private func conteneur(_ id: String) -> ConteneurOnglet {
        if let c = conteneurs[id] { return c }
        let c = ConteneurOnglet()
        conteneurs[id] = c
        return c
    }

    /// La page web passe dans le conteneur de l'onglet choisi.
    private func installerPage(dans id: String) {
        let c = conteneur(id)
        guard pont.parent !== c else { return }
        if pont.parent != nil {
            pont.willMove(toParent: nil)
            pont.view.removeFromSuperview()
            pont.removeFromParent()
        }
        c.loadViewIfNeeded()
        c.addChild(pont)
        pont.view.frame = c.view.bounds
        pont.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        c.view.addSubview(pont.view)
        pont.didMove(toParent: c)
        if let defilement = pont.webView?.scrollView {
            c.setContentScrollView(defilement, for: .bottom)
        }
        setNeedsStatusBarAppearanceUpdate()
    }

    /// Choisi depuis la page (allerA) : sans renvoyer d'évènement.
    func selectionner(_ nom: String) {
        guard let onglet = ongletsEcrans.first(where: { $0.identifier == nom }) else { return }
        dernierSignale = nom
        if selectedTab !== onglet { selectedTab = onglet }
        installerPage(dans: nom)
    }

    func montrerPlus(_ visible: Bool, libelle: String?) {
        guard let plus = ongletPlus else { return }
        if let libelle = libelle, !libelle.isEmpty { plus.title = libelle }
        let voulus: [UITab] = visible ? ongletsEcrans + [plus] : ongletsEcrans
        if tabs.count != voulus.count { setTabs(voulus, animated: true) }
    }

    func tabBarController(_ tabBarController: UITabBarController, shouldSelectTab tab: UITab) -> Bool {
        if tab is UISearchTab {
            module?.signaler("plus")
            return false
        }
        if tab === selectedTab {
            module?.signaler("retouche", ["nom": tab.identifier])
            return false
        }
        return true
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelectTab selectedTab: UITab, previousTab: UITab?) {
        suivreSelection()
    }

    // Les mêmes, par contrôleur (selon la version d'iOS, l'un ou l'autre est appelé).
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        if viewController === conteneurs["plus"] {
            module?.signaler("plus")
            return false
        }
        return true
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        suivreSelection()
    }

    /// La page suit l'onglet choisi, et la page en est prévenue (une fois).
    private func suivreSelection() {
        guard let id = selectedTab?.identifier, ORDRE_ONGLETS.contains(id) else { return }
        let deplacee = pont.parent !== conteneurs[id]
        installerPage(dans: id)
        if deplacee || dernierSignale != id {
            dernierSignale = id
            module?.signaler("onglet", ["nom": id])
        }
    }
    private var dernierSignale = "repas"

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Filet : si l'onglet a changé sans que les délégués soient appelés.
        if let id = selectedTab?.identifier, ORDRE_ONGLETS.contains(id), pont.parent !== conteneurs[id] {
            suivreSelection()
        }
    }

    // MARK: - Séance en cours, au-dessus de la barre

    func montrerAccessoire(titre: String, detail: String, depuis: Date?) {
        let vue = accessoireVue ?? AccessoireSeance()
        if accessoireVue == nil {
            vue.auToucher = { [weak self] in self?.module?.signaler("accessoire") }
            accessoireVue = vue
        }
        vue.maj(titre: titre, detail: detail, depuis: depuis)
        if bottomAccessory == nil {
            setBottomAccessory(UITabAccessory(contentView: vue), animated: true)
        }
    }

    func cacherAccessoire() {
        accessoireVue?.arreter()
        if bottomAccessory != nil { setBottomAccessory(nil, animated: true) }
    }

    // MARK: - Barre d'état et orientation : celles de la page

    override var childForStatusBarStyle: UIViewController? { pont }
    override var childForStatusBarHidden: UIViewController? { pont }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { pont.supportedInterfaceOrientations }
}

/// Un onglet : une vue vide, du fond de l'appli, qui accueille la page web.
final class ConteneurOnglet: UIViewController {
    override func loadView() {
        let v = UIView()
        v.backgroundColor = UIColor { $0.userInterfaceStyle == .dark ? .black : UIColor(red: 0.949, green: 0.949, blue: 0.969, alpha: 1) }
        view = v
    }
    override var childForStatusBarStyle: UIViewController? { children.first }
    override var childForStatusBarHidden: UIViewController? { children.first }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        children.first?.supportedInterfaceOrientations ?? .portrait
    }
}

/// La séance en cours, comme le mini-lecteur de Musique : nom du programme,
/// séries cochées et chrono. Un appui rouvre la séance.
@available(iOS 26.0, *)
final class AccessoireSeance: UIView {
    var auToucher: (() -> Void)?
    private let icone = UIImageView(image: UIImage(systemName: "figure.strengthtraining.traditional"))
    private let titre = UILabel()
    private let detail = UILabel()
    private let chrono = UILabel()
    private var depuis: Date?
    private var minuteur: Timer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        icone.tintColor = ACCENT_ASKESIS
        icone.contentMode = .scaleAspectFit
        icone.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        titre.font = .systemFont(ofSize: 15, weight: .semibold)
        titre.lineBreakMode = .byTruncatingTail
        detail.font = .systemFont(ofSize: 12, weight: .regular)
        detail.textColor = .secondaryLabel
        detail.lineBreakMode = .byTruncatingTail
        chrono.font = UIFont.monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        chrono.setContentCompressionResistancePriority(.required, for: .horizontal)
        let textes = UIStackView(arrangedSubviews: [titre, detail])
        textes.axis = .vertical
        textes.spacing = 0
        // Les textes prennent la place libre : le chrono reste calé à droite.
        textes.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textes.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        chrono.setContentHuggingPriority(.required, for: .horizontal)
        chrono.textAlignment = .right
        let ligne = UIStackView(arrangedSubviews: [icone, textes, chrono])
        ligne.axis = .horizontal
        ligne.alignment = .center
        ligne.spacing = 10
        ligne.translatesAutoresizingMaskIntoConstraints = false
        addSubview(ligne)
        NSLayoutConstraint.activate([
            icone.widthAnchor.constraint(equalToConstant: 26),
            ligne.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            ligne.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            ligne.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(touche)))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) non utilisé") }

    @objc private func touche() { auToucher?() }

    func maj(titre texte: String, detail sousTexte: String, depuis debut: Date?) {
        titre.text = texte
        detail.text = sousTexte
        detail.isHidden = sousTexte.isEmpty
        depuis = debut
        accessibilityLabel = "Séance en cours : \(texte)"
        accessibilityHint = "Rouvre la séance"
        majChrono()
        if minuteur == nil && debut != nil {
            let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.majChrono() }
            RunLoop.main.add(t, forMode: .common)
            minuteur = t
        }
    }

    func arreter() {
        minuteur?.invalidate()
        minuteur = nil
    }

    private func majChrono() {
        guard let debut = depuis else { chrono.text = nil; return }
        let s = max(0, Int(Date().timeIntervalSince(debut)))
        chrono.text = s >= 3600
            ? String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
            : String(format: "%d:%02d", s / 60, s % 60)
        accessibilityValue = chrono.text
    }
}

/// Le module « Onglets » vu par la page web.
@objc(OngletsNatifs)
public class OngletsNatifs: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "OngletsNatifs"
    public let jsName = "Onglets"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "etat", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "selectionner", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "afficher", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "plus", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "accessoire", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "apparence", returnType: CAPPluginReturnPromise)
    ]

    override public func load() {
        if #available(iOS 26.0, *) { OngletsControleur.courant?.module = self }
    }

    func signaler(_ evenement: String, _ donnees: [String: Any] = [:]) {
        notifyListeners(evenement, data: donnees)
    }

    @objc func etat(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            var actif = false
            if #available(iOS 26.0, *) { actif = OngletsControleur.courant != nil }
            call.resolve(["actif": actif])
        }
    }

    @objc func selectionner(_ call: CAPPluginCall) {
        let nom = call.getString("nom") ?? ""
        DispatchQueue.main.async {
            if #available(iOS 26.0, *) { OngletsControleur.courant?.selectionner(nom) }
            call.resolve()
        }
    }

    @objc func afficher(_ call: CAPPluginCall) {
        let visible = call.getBool("visible") ?? true
        let anime = call.getBool("anime") ?? true
        DispatchQueue.main.async {
            if #available(iOS 26.0, *) { OngletsControleur.courant?.setTabBarHidden(!visible, animated: anime) }
            call.resolve()
        }
    }

    @objc func plus(_ call: CAPPluginCall) {
        let visible = call.getBool("visible") ?? true
        let libelle = call.getString("libelle")
        DispatchQueue.main.async {
            if #available(iOS 26.0, *) { OngletsControleur.courant?.montrerPlus(visible, libelle: libelle) }
            call.resolve()
        }
    }

    @objc func accessoire(_ call: CAPPluginCall) {
        let cacher = call.getBool("cacher") ?? false
        let titre = call.getString("titre") ?? ""
        let detail = call.getString("detail") ?? ""
        let depuis = call.getDouble("depuis").map { Date(timeIntervalSince1970: $0 / 1000) }
        DispatchQueue.main.async {
            if #available(iOS 26.0, *) {
                if cacher || titre.isEmpty { OngletsControleur.courant?.cacherAccessoire() }
                else { OngletsControleur.courant?.montrerAccessoire(titre: titre, detail: detail, depuis: depuis) }
            }
            call.resolve()
        }
    }

    @objc func apparence(_ call: CAPPluginCall) {
        let style = call.getString("style") ?? "auto"
        DispatchQueue.main.async {
            let choix: UIUserInterfaceStyle = style == "dark" ? .dark : (style == "light" ? .light : .unspecified)
            self.bridge?.viewController?.view.window?.overrideUserInterfaceStyle = choix
            call.resolve()
        }
    }
}
