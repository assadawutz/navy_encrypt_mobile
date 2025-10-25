#!/usr/bin/env bash
set -Eeuo pipefail
case "${1-}" in
  --preflight) echo "[Android] Preflight"; java -version || true; (cd android && ./gradlew -v) 2>/dev/null || true;;
  --auto|*) echo "[Android] Auto"; rm -rf android/.gradle ~/.gradle/caches || true; flutter pub get || true; (cd android && ./gradlew --no-daemon clean || true && ./gradlew --no-daemon build || true) || true; flutter build apk --debug || true;;
esac
