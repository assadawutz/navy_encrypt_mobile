#!/usr/bin/env bash
set -Eeuo pipefail
case "${1-}" in
  --preflight) echo "[NULL] Preflight"; grep -n "environment:" pubspec.yaml || true;;
  --auto|*) echo "[NULL] Auto migrate"; flutter pub get || true; flutter pub upgrade --null-safety || true; grep -Rl -- '--no-sound-null-safety' . | xargs -I{} sed -i '' 's/--no-sound-null-safety//g' {} 2>/dev/null || true; dart migrate --apply-changes || true;;
esac
