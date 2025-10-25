#!/usr/bin/env bash
set -Eeuo pipefail
case "${1-}" in
  --preflight) echo "[iOS] Preflight"; xcodebuild -version || true; pod --version || true;;
  --auto|*) echo "[iOS] Auto"; rm -rf ios/Pods ios/Podfile.lock || true; rm -rf ~/Library/Developer/Xcode/DerivedData || true; (cd ios && pod deintegrate || true && pod install || true) || true; flutter pub get || true; flutter build ios --debug --simulator || true;;
esac
