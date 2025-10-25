#!/usr/bin/env bash
set -Eeuo pipefail
case "${1-}" in
  --preflight) echo "[FVM] Preflight"; command -v fvm || true; command -v flutter || true; flutter --version || true;;
  --auto|*) echo "[FVM] Auto"; fvm install >/dev/null 2>&1 || true; fvm use >/dev/null 2>&1 || true; if command -v fvm >/dev/null 2>&1; then fvm flutter doctor -v || true; fvm flutter precache || true; else flutter doctor -v || true; flutter precache || true; fi;;
esac
