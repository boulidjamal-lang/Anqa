#!/usr/bin/env bash
# Lance l'app (version « capture », voir preparer-www.mjs --capture) dans le
# plus grand simulateur iPhone disponible et photographie chaque écran, en
# clair puis en sombre. L'app reste 24 s sur chaque écran et l'annonce dans
# son journal (« CAPTURE:repas »…) : la capture se fait à l'annonce, ou au
# minutage si le journal reste muet.
# Usage : scripts/captures-simulateur.sh <App.app> <dossier de sortie>
set -euo pipefail
APP="$1"
SORTIE="$2"
BUNDLE="${BUNDLE_ID:-com.jambou.askesis}"
mkdir -p "$SORTIE"

# iOS le plus récent, et de préférence un « Pro Max » : le format des captures de l'App Store.
read -r UDID NOM < <(xcrun simctl list devices available -j | python3 -c '
import json, re, sys
choix = []
for rt, appareils in json.load(sys.stdin)["devices"].items():
    if "iOS" not in rt:
        continue
    version = [int(x) for x in re.findall(r"\d+", rt.split("iOS")[-1])]
    for a in appareils:
        if a["name"].startswith("iPhone"):
            choix.append((version, "Pro Max" in a["name"], a["name"], a["udid"]))
choix.sort()
print(choix[-1][3], choix[-1][2])')
echo "Simulateur : $NOM ($UDID)"

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 || true
xcrun simctl install "$UDID" "$APP"

# Une capture ne bloque jamais la compilation : 45 s au plus (une appli qui
# s'emballe a déjà figé une capture un quart d'heure).
# Une image presque vide (page blanche pas encore peinte) pèse quelques Ko,
# un vrai écran plusieurs centaines : en dessous de 40 Ko, on réessaie une
# fois après 2 s, puis on le signale.
# Juste après le démarrage du simulateur, l'image rendue peut rester figée
# quelques secondes (la première passe, en clair, sortait quatre captures
# identiques) : une capture identique à la précédente est reprise, jusqu'à
# trois fois à 2 s d'intervalle, puis signalée.
DERNIERE_EMPREINTE=""
photographier() {
  for essai in 1 2 3; do
    perl -e 'alarm shift @ARGV; exec @ARGV' 45 xcrun simctl io "$UDID" screenshot "$1" \
      || { echo "::warning::$(basename "$1") : le simulateur n'a pas répondu à temps"; return; }
    taille=$(stat -f%z "$1" 2>/dev/null || echo 0)
    empreinte=$(md5 -q "$1" 2>/dev/null || echo "$taille")
    if [ "$taille" -ge 40000 ] && [ "$empreinte" != "$DERNIERE_EMPREINTE" ]; then DERNIERE_EMPREINTE="$empreinte"; return; fi
    [ "$essai" -lt 3 ] && sleep 2
  done
  if [ "$taille" -lt 40000 ]; then echo "::warning::$(basename "$1") : image presque vide ($taille octets), l'écran n'était sans doute pas peint"
  else echo "::warning::$(basename "$1") : image identique à la précédente, l'écran ne s'est pas redessiné"; fi
  DERNIERE_EMPREINTE="$empreinte"
}

for apparence in light dark; do
  xcrun simctl ui "$UDID" appearance "$apparence"
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  journal="$SORTIE/journal-$apparence.txt"
  # Pseudo-terminal et sortie sans tampon : le journal arrive ligne à ligne.
  debut=$(date +%s)
  SIMCTL_CHILD_NSUnbufferedIO=YES xcrun simctl launch --console-pty "$UDID" "$BUNDLE" > "$journal" 2>&1 &
  PID=$!
  sleep 4
  photographier "$SORTIE/$apparence-0-lancement.png"
  k=0
  for ecran in repas seance stats reglages feuille accessoire; do
    limite=$((debut + 26 + 24 * k))
    while [ "$(date +%s)" -lt "$limite" ] && ! grep -q "CAPTURE:$ecran" "$journal"; do sleep 1; done
    grep -q "CAPTURE:$ecran" "$journal" || echo "::notice::$apparence / $ecran : capture au minutage (journal muet)"
    photographier "$SORTIE/$apparence-$((k + 1))-$ecran.png"
    k=$((k + 1))
  done
  sleep 3
  kill "$PID" 2>/dev/null || true
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
done

if grep -h "CAPTURE:erreur" "$SORTIE"/journal-*.txt; then
  echo "::error::l'appli a signalé une erreur pendant les captures (voir les journaux)"
  exit 1
fi
# La barre native et la page ne doivent pas se renvoyer la balle : une
# vingtaine d'appels « selectionner » par passe, pas des centaines.
for journal in "$SORTIE"/journal-*.txt; do
  appels=$(grep -c "Onglets selectionner" "$journal" || true)
  if [ "${appels:-0}" -gt 100 ]; then
    echo "::error::$(basename "$journal") : $appels changements d'onglet, la barre et la page se renvoient la balle"
    exit 1
  fi
done
ls -1 "$SORTIE"
