#!/usr/bin/env bash
# Lance l'app (version « capture », voir preparer-www.mjs --capture) dans le
# plus grand simulateur iPhone disponible et photographie chaque écran, en
# clair puis en sombre. L'app reste 12 s sur chaque écran et l'annonce dans
# son journal (« CAPTURE:repas »…) : la capture se fait à l'annonce, ou au
# milieu de la fenêtre de l'écran si le journal reste muet.
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

for apparence in light dark; do
  xcrun simctl ui "$UDID" appearance "$apparence"
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  journal="$SORTIE/journal-$apparence.txt"
  # Pseudo-terminal et sortie sans tampon : le journal arrive ligne à ligne.
  debut=$(date +%s)
  SIMCTL_CHILD_NSUnbufferedIO=YES xcrun simctl launch --console-pty "$UDID" "$BUNDLE" > "$journal" 2>&1 &
  PID=$!
  sleep 2
  xcrun simctl io "$UDID" screenshot "$SORTIE/$apparence-0-lancement.png" || true
  k=0
  for ecran in repas seance stats reglages; do
    limite=$((debut + 12 + 12 * k))
    while [ "$(date +%s)" -lt "$limite" ] && ! grep -q "CAPTURE:$ecran" "$journal"; do sleep 1; done
    grep -q "CAPTURE:$ecran" "$journal" || echo "::notice::$apparence / $ecran : capture au minutage (journal muet)"
    xcrun simctl io "$UDID" screenshot "$SORTIE/$apparence-$((k + 1))-$ecran.png"
    k=$((k + 1))
  done
  sleep 3
  kill "$PID" 2>/dev/null || true
done

if grep -h "CAPTURE:erreur" "$SORTIE"/journal-*.txt; then
  echo "::error::l'appli a signalé une erreur pendant les captures (voir les journaux)"
  exit 1
fi
ls -1 "$SORTIE"
