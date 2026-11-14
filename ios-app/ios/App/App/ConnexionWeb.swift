import UIKit
import WebKit
import Capacitor

/* Connexion à un service tiers dans une feuille de l'app (module
   « ConnexionWeb » vu par la page) : la balance Withings.
   Dans Safari, la page Withings ne ramenait jamais à l'app : son adresse de
   retour, enregistrée chez Withings, est le site d'Askēsis. Ici, la page de
   connexion s'ouvre dans une vue web à part, sur une session oubliée à la
   fermeture (rien n'en reste sur le téléphone). Dès qu'elle part vers
   l'adresse de retour (même hôte, même chemin), la feuille se referme sans
   la charger et rend cette adresse à la page : le code d'autorisation
   qu'elle porte part alors au serveur, qui l'échange et garde les jetons.
   ouvrir({ url, retour, titre }) → { url } (l'adresse de retour, paramètres
     compris) ou { annule: true } (feuille fermée) ; refusé avec le code
     « invalide » (adresse qui n'est pas en https), « occupe » (une feuille
     déjà ouverte) ou « indisponible ».
   fermer() → referme la feuille ouverte, dont l'appel rend { annule: true }. */
@objc(ConnexionWebPlugin)
public class ConnexionWebPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "ConnexionWebPlugin"
    public let jsName = "ConnexionWeb"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "ouvrir", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "fermer", returnType: CAPPluginReturnPromise)
    ]

    private weak var feuille: ConnexionWebControleur?

    @objc func ouvrir(_ call: CAPPluginCall) {
        guard let url = ConnexionWebPlugin.adresseSure(call.getString("url")),
              let retour = ConnexionWebPlugin.adresseSure(call.getString("retour")) else {
            call.reject("Adresse invalide", "invalide")
            return
        }
        let titre = call.getString("titre") ?? ""
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.feuille != nil {
                call.reject("Une connexion est déjà ouverte", "occupe")
                return
            }
            guard var dessus = self.bridge?.viewController?.view.window?.rootViewController else {
                call.reject("Indisponible", "indisponible")
                return
            }
            // Pas sur une feuille en train de se fermer : elle ne présenterait rien.
            while let autre = dessus.presentedViewController, !autre.isBeingDismissed { dessus = autre }
            let ecran = ConnexionWebControleur(url: url, retour: retour, titre: titre) { [weak self] resultat in
                self?.feuille = nil
                switch resultat {
                case .retour(let adresse): call.resolve(["url": adresse.absoluteString])
                case .annule: call.resolve(["annule": true])
                }
            }
            let navigation = UINavigationController(rootViewController: ecran)
            // Le rose de l'appli pour les boutons et la barre de chargement.
            navigation.view.tintColor = ACCENT_ASKESIS
            // Feuille glissée vers le bas : comme « Annuler ».
            navigation.presentationController?.delegate = ecran
            self.feuille = ecran
            dessus.present(navigation, animated: true)
        }
    }

    @objc func fermer(_ call: CAPPluginCall) {
        DispatchQueue.main.async { [weak self] in
            self?.feuille?.annuler()
            call.resolve()
        }
    }

    /// Une adresse https complète, rien d'autre (ni fichier, ni autre appli).
    static func adresseSure(_ texte: String?) -> URL? {
        guard let texte = texte, let url = URL(string: texte), url.scheme?.lowercased() == "https",
              let hote = url.host, !hote.isEmpty else { return nil }
        return url
    }
}

/// La feuille : la page du service, « Annuler » et « Recharger » en haut, une
/// barre de chargement, et un mot si la page ne vient pas (hors connexion).
final class ConnexionWebControleur: UIViewController, WKNavigationDelegate, WKUIDelegate, UIAdaptivePresentationControllerDelegate {
    enum Resultat {
        case retour(URL)
        case annule
    }

    private let adresse: URL
    private let retour: URL
    private let fin: (Resultat) -> Void
    private var fini = false
    private var vueWeb: WKWebView?
    private let barre = UIProgressView(progressViewStyle: .bar)
    private let message = UILabel()
    private let boutonReessayer = UIButton(type: .system)
    private let panne = UIStackView()
    private var suiviChargement: NSKeyValueObservation?

    init(url: URL, retour: URL, titre: String, fin: @escaping (Resultat) -> Void) {
        self.adresse = url
        self.retour = retour
        self.fin = fin
        super.init(nibName: nil, bundle: nil)
        title = titre
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) non utilisé") }

    deinit { suiviChargement?.invalidate() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Annuler", style: .plain, target: self, action: #selector(annuler))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(recharger))
        navigationItem.rightBarButtonItem?.accessibilityLabel = "Recharger la page"

        let reglages = WKWebViewConfiguration()
        // Une session à part, oubliée à la fermeture : ni les cookies du service ni rien d'autre ne restent.
        reglages.websiteDataStore = .nonPersistent()
        let vue = WKWebView(frame: .zero, configuration: reglages)
        vue.navigationDelegate = self
        vue.uiDelegate = self
        vue.allowsBackForwardNavigationGestures = true
        vue.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(vue)
        vueWeb = vue

        barre.translatesAutoresizingMaskIntoConstraints = false
        barre.trackTintColor = .clear
        view.addSubview(barre)

        message.numberOfLines = 0
        message.textAlignment = .center
        message.font = .preferredFont(forTextStyle: .body)
        message.adjustsFontForContentSizeCategory = true
        message.textColor = .secondaryLabel
        boutonReessayer.setTitle("Réessayer", for: .normal)
        boutonReessayer.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        boutonReessayer.titleLabel?.adjustsFontForContentSizeCategory = true
        boutonReessayer.addTarget(self, action: #selector(recharger), for: .touchUpInside)
        panne.axis = .vertical
        panne.alignment = .center
        panne.spacing = 12
        panne.addArrangedSubview(message)
        panne.addArrangedSubview(boutonReessayer)
        panne.translatesAutoresizingMaskIntoConstraints = false
        panne.isHidden = true
        view.addSubview(panne)

        let zone = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            vue.topAnchor.constraint(equalTo: zone.topAnchor),
            vue.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            vue.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            vue.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            barre.topAnchor.constraint(equalTo: zone.topAnchor),
            barre.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            barre.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panne.centerYAnchor.constraint(equalTo: zone.centerYAnchor),
            panne.leadingAnchor.constraint(equalTo: zone.leadingAnchor, constant: 32),
            panne.trailingAnchor.constraint(equalTo: zone.trailingAnchor, constant: -32)
        ])

        suiviChargement = vue.observe(\.estimatedProgress, options: [.new]) { [weak self] vue, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.barre.setProgress(Float(vue.estimatedProgress), animated: vue.estimatedProgress > 0.05)
                self.barre.isHidden = vue.estimatedProgress >= 1
            }
        }
        vue.load(URLRequest(url: adresse))
    }

    // MARK: Fin de la connexion

    @objc func annuler() { terminer(.annule) }

    @objc private func recharger() {
        panne.isHidden = true
        guard let vue = vueWeb else { return }
        if vue.url != nil { vue.reload() } else { vue.load(URLRequest(url: adresse)) }
    }

    private func terminer(_ resultat: Resultat) {
        guard !fini else { return }
        fini = true
        vueWeb?.stopLoading()
        let presentee: UIViewController = navigationController ?? self
        if presentee.presentingViewController != nil {
            // Encore en train d'apparaître (une adresse de retour reçue tout de suite) : on attend la fin de
            // l'animation, sinon UIKit ignore la fermeture et la feuille reste à l'écran.
            if let transition = presentee.transitionCoordinator {
                _ = transition.animate(alongsideTransition: nil) { _ in presentee.dismiss(animated: true) }
            } else {
                presentee.dismiss(animated: true)
            }
        }
        fin(resultat)
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        terminer(.annule)
    }

    // MARK: Navigation

    /// L'adresse de retour : https, même hôte, même chemin (les paramètres, eux, changent).
    private func estRetour(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https", let hote = url.host?.lowercased(), hote == retour.host?.lowercased() else { return false }
        let chemin = { (u: URL) -> String in
            let p = URLComponents(url: u, resolvingAgainstBaseURL: false)?.path ?? ""
            return p.isEmpty ? "/" : p
        }
        return chemin(url) == chemin(retour)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        let pagePrincipale = navigationAction.targetFrame?.isMainFrame ?? true
        if pagePrincipale && estRetour(url) {
            decisionHandler(.cancel)
            terminer(.retour(url))
            return
        }
        // Rien que des pages web dans la feuille : un lien vers une autre appli (tel:, mailto:…) n'y part pas.
        switch url.scheme?.lowercased() ?? "" {
        case "https", "http", "about", "data", "blob": decisionHandler(.allow)
        default: decisionHandler(.cancel)
        }
    }

    // Une page qui s'ouvrirait « dans une nouvelle fenêtre » s'ouvre ici même.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url { webView.load(URLRequest(url: url)) }
        return nil
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        panne.isHidden = true
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        echec(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        echec(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        if !fini { recharger() }
    }

    private func echec(_ error: Error) {
        let e = error as NSError
        // Un chargement arrêté par la feuille elle-même (l'adresse de retour, un lien refusé) n'est pas une panne.
        if fini || e.code == NSURLErrorCancelled || (e.domain == "WebKitErrorDomain" && e.code == 102) { return }
        let horsLigne = [NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost, NSURLErrorDataNotAllowed].contains(e.code)
        message.text = horsLigne ? "Pas de connexion à Internet." : "La page ne s'est pas chargée."
        barre.isHidden = true
        panne.isHidden = false
    }

    // MARK: Fenêtres de la page (alert, confirm)

    private func peutMontrer() -> Bool { view.window != nil && presentedViewController == nil && !fini }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        guard peutMontrer() else { completionHandler(); return }
        let alerte = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alerte.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(alerte, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        guard peutMontrer() else { completionHandler(false); return }
        let alerte = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alerte.addAction(UIAlertAction(title: "Annuler", style: .cancel) { _ in completionHandler(false) })
        alerte.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        present(alerte, animated: true)
    }
}
