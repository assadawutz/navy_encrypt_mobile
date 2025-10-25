#!/usr/bin/env bash
set -Eeuo pipefail
echo "[iOS FIX-ALL] backup+clean+fix"
tar czf backup_ios_$(date +%Y%m%d-%H%M%S).tgz ios || true
flutter clean || true
./fix-ios.sh --preflight
./fix-ios.sh --auto
flutter build ios --release || true
flutter build ios --debug --simulator || true
echo "[iOS FIX-ALL] done"
