#!/bin/bash
# Régénère les 10 captures App Store (appstore/) et les 6 visuels de la landing (landing/img/).
# Prérequis : build Debug dans build/ (voir HealthKitSpike/README.md) et simulateur 6,9" démarré.
# Usage : scripts/captures.sh [identifiant du simulateur]
set -euo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE="${1:-2CAC6724-1FE4-4A57-B0D8-BD11FE5FB469}"
APP_PATH="$DIR/build/Build/Products/Debug-iphonesimulator/LivasideSpike.app"
APP_ID="com.livaside.healthkitspike"
OUT="${PAPERCLIP_RUN_SCRATCH_DIR:-$(mktemp -d)}"

# Simulateur en français : dates, heures et clavier.
xcrun simctl spawn "$DEVICE" defaults write -g AppleLanguages -array fr
xcrun simctl spawn "$DEVICE" defaults write -g AppleLocale fr_FR
xcrun simctl spawn "$DEVICE" defaults write -g AppleKeyboards -array "fr_FR@sw=AZERTY;hw=Automatic"
xcrun simctl status_bar "$DEVICE" override --time "$(date +%H:%M)" --batteryState charged --batteryLevel 100 \
  --wifiBars 3 --cellularMode active --cellularBars 4 --operatorName ""
xcrun simctl install "$DEVICE" "$APP_PATH"

# shot <fichier> <arguments de lancement…>
shot() {
  local file=$1; shift
  xcrun simctl terminate "$DEVICE" "$APP_ID" 2>/dev/null || true
  sleep 1
  xcrun simctl launch "$DEVICE" "$APP_ID" -AppleLanguages "(fr)" -AppleLocale fr_FR \
    -demoMode YES -captureMode YES "$@" >/dev/null
  sleep 5
  xcrun simctl io "$DEVICE" screenshot "$OUT/$file" >/dev/null
}

for theme in clair sombre; do
  [ "$theme" = clair ] && xcrun simctl ui "$DEVICE" appearance light || xcrun simctl ui "$DEVICE" appearance dark
  sleep 2
  shot "1-$theme.png" -captureTab today -captureScroll end
  shot "2-$theme.png" -captureTab trends -captureScroll end
  shot "3-$theme.png" -captureTab meal
  shot "4-$theme.png" -captureTab trends -captureRange 30 -captureScroll end
  shot "5-$theme.png" -captureTab meal -captureKeyboard NO

  for n in 1 2 3 4 5; do cp "$OUT/$n-$theme.png" "$DIR/appstore/capture-$n-$theme.png"; done
  cp "$OUT/1-$theme.png" "$DIR/landing/img/ecran-aujourdhui-$theme.png"
  cp "$OUT/2-$theme.png" "$DIR/landing/img/ecran-tendances-$theme.png"
  cp "$OUT/3-$theme.png" "$DIR/landing/img/ecran-repas-$theme.png"
done

xcrun simctl status_bar "$DEVICE" clear
echo "Captures écrites dans appstore/ et landing/img/"
