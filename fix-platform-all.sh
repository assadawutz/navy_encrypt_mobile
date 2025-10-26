#!/usr/bin/env bash
set -Eeuo pipefail
echo "[PLATFORM FIX-ALL] iOS + Android + FVM + Null"
./fix-fvm.sh --preflight
./fix-fvm.sh --auto
./fix-null-safety.sh --preflight
./fix-null-safety.sh --auto
./ios-fix-all.sh || true
./android-fix-all.sh || true
echo "[PLATFORM FIX-ALL] done"
