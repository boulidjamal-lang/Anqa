import UIKit
import AVFoundation
import Capacitor

/* Scanner de codes-barres de l'app (module « Scanner » vu par la page).
   Le module tout fait d'avant mettait longtemps à faire la mise au point :
   il prenait l'objectif principal, qui ne voit pas net de près sur les
   iPhone Pro, et cherchait sur toute la plage des distances. Ici :
   - la caméra « virtuelle » de l'iPhone (ultra grand-angle + grand-angle…),
     qui passe seule en macro quand le code est près, comme l'appareil Photo ;
   - une mise au point continue limitée aux distances proches, donc rapide ;
     un toucher sur l'image la refait à cet endroit ;
   - sur un iPhone sans macro, un léger zoom pour ne pas avoir à approcher
     le code plus près que ce que l'objectif voit net (conseil d'Apple) ;
   - la lecture par iOS, dès que le code passe dans le cadre ; une lampe
     pour les rayons sombres.
   scanner({ consigne }) → { code } ou { annule: true } ; refusé avec le code
   « refus » (appareil photo refusé) ou « indisponible ».
   etat() → { camera } : y a-t-il une caméra arrière (pas dans le simulateur). */
@objc(ScannerCodes)
public class ScannerCodes: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "ScannerCodes"
    public let jsName = "Scanner"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "etat", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "scanner", returnType: CAPPluginReturnPromise)
    ]

    @objc func etat(_ call: CAPPluginCall) {
        call.resolve(["camera": ScannerControleur.meilleureCamera() != nil])
    }

    @objc func scanner(_ call: CAPPluginCall) {
        let consigne = call.getString("consigne") ?? "Vise le code-barres du produit"
        let ouvrir: () -> Void = { [weak self] in
            DispatchQueue.main.async {
                guard ScannerControleur.meilleureCamera() != nil,
                      var dessus = self?.bridge?.viewController?.view.window?.rootViewController else {
                    call.reject("Pas d'appareil photo", "indisponible")
                    return
                }
                while let autre = dessus.presentedViewController { dessus = autre }
                let ecran = ScannerControleur(consigne: consigne) { resultat in
                    switch resultat {
                    case .code(let code): call.resolve(["code": code])
                    case .annule: call.resolve(["annule": true])
                    case .erreur(let message): call.reject(message, "indisponible")
                    }
                }
                dessus.present(ecran, animated: true)
            }
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            ouvrir()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { accorde in
                if accorde { ouvrir() } else { call.reject("Appareil photo refusé", "refus") }
            }
        default:
            call.reject("Appareil photo refusé", "refus")
        }
    }
}

/// L'écran du scanner : l'image de la caméra, un cadre où viser, la consigne,
/// une croix pour fermer et la lampe.
final class ScannerControleur: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    enum Resultat {
        case code(String)
        case annule
        case erreur(String)
    }

    /// La caméra arrière qui voit le mieux de près : les caméras virtuelles
    /// d'abord (elles basculent seules sur l'ultra grand-angle, en macro).
    static func meilleureCamera() -> AVCaptureDevice? {
        let types: [AVCaptureDevice.DeviceType] = [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera]
        for type in types {
            if let camera = AVCaptureDevice.default(type, for: .video, position: .back) { return camera }
        }
        return nil
    }

    private let consigne: String
    private let fin: (Resultat) -> Void
    private let session = AVCaptureSession()
    private let fileSession = DispatchQueue(label: "askesis.scanner")
    private let apercu = AVCaptureVideoPreviewLayer()
    private let lecture = AVCaptureMetadataOutput()
    private let voile = CAShapeLayer()
    private let cadre = UIView()
    private let texte = UILabel()
    private let boutonFermer = UIButton(type: .system)
    private let boutonLampe = UIButton(type: .system)
    private var camera: AVCaptureDevice?
    private var enMarche = false
    private var lu = false
    private var fini = false

    init(consigne: String, fin: @escaping (Resultat) -> Void) {
        self.consigne = consigne
        self.fin = fin
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) non utilisé") }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        apercu.session = session
        apercu.videoGravity = .resizeAspectFill
        view.layer.addSublayer(apercu)
        voile.fillRule = .evenOdd
        voile.fillColor = UIColor(white: 0, alpha: 0.5).cgColor
        view.layer.addSublayer(voile)

        cadre.layer.borderColor = UIColor.white.cgColor
        cadre.layer.borderWidth = 3
        cadre.layer.cornerRadius = 24
        cadre.layer.cornerCurve = .continuous
        cadre.isUserInteractionEnabled = false
        view.addSubview(cadre)

        texte.text = consigne
        texte.textColor = .white
        texte.font = .systemFont(ofSize: 17, weight: .semibold)
        texte.textAlignment = .center
        texte.numberOfLines = 0
        view.addSubview(texte)

        habiller(boutonFermer, symbole: "xmark", libelle: "Fermer")
        boutonFermer.addTarget(self, action: #selector(fermer), for: .touchUpInside)
        habiller(boutonLampe, symbole: "flashlight.off.fill", libelle: "Allumer la lampe")
        boutonLampe.addTarget(self, action: #selector(basculerLampe), for: .touchUpInside)
        boutonLampe.isHidden = true
        view.addSubview(boutonFermer)
        view.addSubview(boutonLampe)

        // Un toucher sur l'image : mise au point à cet endroit.
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(toucher(_:))))

        fileSession.async { [weak self] in self?.demarrer() }
    }

    /// Bouton rond, en verre liquide sur iOS 26.
    private func habiller(_ bouton: UIButton, symbole: String, libelle: String) {
        var config: UIButton.Configuration
        if #available(iOS 26.0, *) {
            config = .glass()
        } else {
            config = .filled()
            config.baseBackgroundColor = UIColor(white: 0.15, alpha: 0.75)
        }
        config.image = UIImage(systemName: symbole, withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold))
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        bouton.configuration = config
        bouton.accessibilityLabel = libelle
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let cadreEcran = view.bounds, marges = view.safeAreaInsets
        apercu.frame = cadreEcran
        let largeur = min(cadreEcran.width - 48, 420), hauteur: CGFloat = 180
        cadre.frame = CGRect(x: (cadreEcran.width - largeur) / 2, y: cadreEcran.midY - hauteur / 2 - 30, width: largeur, height: hauteur)
        let chemin = UIBezierPath(rect: cadreEcran)
        chemin.append(UIBezierPath(roundedRect: cadre.frame, cornerRadius: 24))
        voile.frame = cadreEcran
        voile.path = chemin.cgPath
        let tailleTexte = texte.sizeThatFits(CGSize(width: cadreEcran.width - 48, height: 200))
        texte.frame = CGRect(x: 24, y: cadre.frame.minY - tailleTexte.height - 20, width: cadreEcran.width - 48, height: tailleTexte.height)
        boutonFermer.frame = CGRect(x: 16, y: marges.top + 8, width: 48, height: 48)
        boutonLampe.frame = CGRect(x: (cadreEcran.width - 64) / 2, y: cadreEcran.height - marges.bottom - 88, width: 64, height: 64)
        majZoneDeLecture()
    }

    /// Le code est cherché dans le cadre, un peu élargi : lecture plus rapide.
    private func majZoneDeLecture() {
        guard enMarche else { return }
        let zone = apercu.metadataOutputRectConverted(fromLayerRect: cadre.frame.insetBy(dx: -24, dy: -60))
        guard zone.width > 0, zone.height > 0 else { return }
        fileSession.async { [weak self] in self?.lecture.rectOfInterest = zone }
    }

    private func demarrer() {
        guard let camera = ScannerControleur.meilleureCamera(), let entree = try? AVCaptureDeviceInput(device: camera) else {
            finir(.erreur("Appareil photo indisponible"))
            return
        }
        session.beginConfiguration()
        if session.canSetSessionPreset(.hd1920x1080) { session.sessionPreset = .hd1920x1080 }
        guard session.canAddInput(entree), session.canAddOutput(lecture) else {
            session.commitConfiguration()
            finir(.erreur("Appareil photo indisponible"))
            return
        }
        session.addInput(entree)
        session.addOutput(lecture)
        lecture.setMetadataObjectsDelegate(self, queue: .main)
        let types: [AVMetadataObject.ObjectType] = [.ean13, .ean8, .upce, .code128, .code39, .code93, .itf14, .interleaved2of5]
        lecture.metadataObjectTypes = types.filter { lecture.availableMetadataObjectTypes.contains($0) }
        session.commitConfiguration()
        regler(camera)
        session.startRunning()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.camera = camera
            self.enMarche = true
            self.boutonLampe.isHidden = !camera.hasTorch
            self.majZoneDeLecture()
        }
    }

    /// Mise au point continue, limitée aux distances proches (plus rapide).
    /// Zoom : sur une caméra virtuelle, celui de l'objectif « 1× » (elle passe
    /// seule en macro de près) ; sinon, de quoi lire un code sans l'approcher
    /// plus près que la distance minimale de mise au point.
    private func regler(_ camera: AVCaptureDevice) {
        do { try camera.lockForConfiguration() } catch { return }
        defer { camera.unlockForConfiguration() }
        if camera.isFocusModeSupported(.continuousAutoFocus) { camera.focusMode = .continuousAutoFocus }
        if camera.isAutoFocusRangeRestrictionSupported { camera.autoFocusRangeRestriction = .near }
        if camera.isSmoothAutoFocusSupported { camera.isSmoothAutoFocusEnabled = false }
        if camera.isFocusPointOfInterestSupported { camera.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5) }
        if camera.isExposureModeSupported(.continuousAutoExposure) { camera.exposureMode = .continuousAutoExposure }
        var zoom: CGFloat = 1
        if camera.deviceType == .builtInTripleCamera || camera.deviceType == .builtInDualWideCamera {
            if camera.activePrimaryConstituentDeviceSwitchingBehavior != .unsupported {
                camera.setPrimaryConstituentDeviceSwitchingBehavior(.auto, restrictedSwitchingBehaviorConditions: [])
            }
            if let bascule = camera.virtualDeviceSwitchOverVideoZoomFactors.first { zoom = CGFloat(truncating: bascule) }
        } else {
            zoom = zoomPourDistanceMinimale(camera)
        }
        camera.videoZoomFactor = max(camera.minAvailableVideoZoomFactor, min(zoom, camera.maxAvailableVideoZoomFactor))
    }

    /// Conseil d'Apple (exemple AVCamBarcode) : zoomer pour qu'un code de
    /// 20 mm remplisse le cadre à la distance minimale de mise au point.
    private func zoomPourDistanceMinimale(_ camera: AVCaptureDevice) -> CGFloat {
        let distanceMinimale = Float(camera.minimumFocusDistance)   // en mm, -1 si inconnue
        guard distanceMinimale > 0 else { return 1 }
        let champ = camera.activeFormat.videoFieldOfView * Float.pi / 180
        let remplissage: Float = 0.8
        let distanceCode = (20 / remplissage) / tan(champ / 2)
        return distanceCode < distanceMinimale ? CGFloat(distanceMinimale / distanceCode) : 1
    }

    @objc private func toucher(_ geste: UITapGestureRecognizer) {
        guard let camera = camera, camera.isFocusPointOfInterestSupported else { return }
        let point = apercu.captureDevicePointConverted(fromLayerPoint: geste.location(in: view))
        fileSession.async {
            do { try camera.lockForConfiguration() } catch { return }
            defer { camera.unlockForConfiguration() }
            camera.focusPointOfInterest = point
            if camera.isFocusModeSupported(.continuousAutoFocus) { camera.focusMode = .continuousAutoFocus }
            if camera.isExposurePointOfInterestSupported { camera.exposurePointOfInterest = point }
            if camera.isExposureModeSupported(.continuousAutoExposure) { camera.exposureMode = .continuousAutoExposure }
        }
    }

    @objc private func basculerLampe() {
        guard let camera = camera, camera.hasTorch else { return }
        let allumer = camera.torchMode != .on
        fileSession.async {
            do { try camera.lockForConfiguration() } catch { return }
            camera.torchMode = allumer ? .on : .off
            camera.unlockForConfiguration()
        }
        habiller(boutonLampe, symbole: allumer ? "flashlight.on.fill" : "flashlight.off.fill", libelle: allumer ? "Éteindre la lampe" : "Allumer la lampe")
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objets: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !lu, let code = objets.lazy.compactMap({ ($0 as? AVMetadataMachineReadableCodeObject)?.stringValue }).first(where: { !$0.isEmpty }) else { return }
        lu = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        cadre.layer.borderColor = UIColor.systemGreen.cgColor
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in self?.finir(.code(code)) }
    }

    @objc private func fermer() { finir(.annule) }

    private func finir(_ resultat: Resultat) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.fini else { return }
            self.fini = true
            self.fileSession.async { if self.session.isRunning { self.session.stopRunning() } }
            if self.presentingViewController != nil {
                self.dismiss(animated: true) { self.fin(resultat) }
            } else {
                self.fin(resultat)
            }
        }
    }
}
