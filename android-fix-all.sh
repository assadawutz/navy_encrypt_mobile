#!/usr/bin/env bash
set -Eeuo pipefail
echo "[ANDROID FIX-ALL] backup+clean+fix"
tar czf backup_android_$(date +%Y%m%d-%H%M%S).tgz android || true
flutter clean || true
./fix-android.sh --preflight
./fix-android.sh --auto
flutter build apk --release || true
flutter build appbundle --release || true
echo "[ANDROID FIX-ALL] done"
