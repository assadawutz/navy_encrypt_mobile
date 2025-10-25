#!/usr/bin/env bash
set -Eeuo pipefail
echo "[MATRIX] auto-detect common issues"
./fix-fvm.sh --preflight
./fix-null-safety.sh --preflight
./fix-ios.sh --preflight || true
./fix-android.sh --preflight || true
./fix-fvm.sh --auto
./fix-null-safety.sh --auto
./fix-ios.sh --auto || true
./fix-android.sh --auto || true
echo "[MATRIX] done"
