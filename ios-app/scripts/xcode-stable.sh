#!/bin/bash
# Choisit le Xcode stable le plus récent de la machine (xcode-select) et dit
# lequel, avec son SDK iOS. Les liens comptent : l'image xcode-27 de GitHub a
# /Applications/Xcode_27.3.app, qui pointe vers Xcode_27.3_beta.app. Chaque
# lien est donc suivi jusqu'à l'app réelle, bêtas et « release candidates »
# sont écartées, et le rang se fait sur le numéro de version de l'app
# (CFBundleShortVersionString), pas sur son nom.
set -euo pipefail

# Chaque app Xcode réelle et stable, en « version chemin ». (Une fonction, pas
# une substitution $( ) : le bash 3.2 de macOS ne lit pas un « case » écrit
# à l'intérieur d'une substitution.)
candidats() {
  local x r v
  for x in /Applications/Xcode*.app; do
    r=$(cd "$x" 2>/dev/null && pwd -P) || continue
    case "$r" in
      *[Bb]eta*|*_[Rr][Cc]*|*[Rr]elease*[Cc]andidate*) continue ;;
    esac
    v=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$r/Contents/Info.plist" 2>/dev/null) || continue
    echo "$v $r"
  done
}

XC=$(candidats | sort -uV | tail -1 | cut -d' ' -f2-)
if [ -z "$XC" ]; then echo "::error::Aucun Xcode stable sur cette machine"; exit 1; fi
sudo xcode-select -s "$XC"
xcodebuild -version
echo "SDK iOS : $(xcrun --sdk iphoneos --show-sdk-version)"
