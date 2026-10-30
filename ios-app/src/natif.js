/* Pont entre l'appli (index.html du dépôt Anqaa) et les modules iOS.
   Compilé par esbuild en www/natif.js, chargé avant tout autre script :
   l'appli teste window.AppNatif, qui n'existe que dans l'app iOS. Sur le
   web, ce fichier n'est jamais servi et rien ne change.
   Les modules sont déclarés par leur nom natif (registerPlugin) plutôt
   qu'importés depuis leurs paquets : leurs versions web (le lecteur de
   codes-barres en JS, par exemple) n'ont rien à faire dans l'app. */
import { Capacitor, registerPlugin } from '@capacitor/core';

const NOMS = ['App', 'Browser', 'Filesystem', 'Haptics', 'Keyboard', 'LocalNotifications', 'ScreenOrientation', 'Share',
  'SplashScreen', 'StatusBar', 'KeepAwake', 'CapacitorBarcodeScanner', 'Health', 'NativePurchases'];

if (Capacitor.isNativePlatform()) {
  const natif = { plateforme: Capacitor.getPlatform(), version: __VERSION_APP__ };
  NOMS.forEach(nom => { natif[nom] = registerPlugin(nom); });
  // Un module absent du projet natif répond par une erreur : l'appli s'en
  // passe (chaque appel est entouré d'un try/catch côté index.html).
  natif.disponible = nom => Capacitor.isPluginAvailable(nom);
  window.AppNatif = Object.freeze(natif);
  // L'écran de lancement d'iOS laisse la place à l'appli (et à l'animation du
  // T) dès que la page est là, quelle que soit la version de l'appli embarquée.
  const cacherLancement = () => requestAnimationFrame(() => natif.SplashScreen.hide({ fadeOutDuration: 200 }).catch(() => {}));
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', cacherLancement, { once: true });
  else cacherLancement();
}
