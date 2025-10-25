#!/usr/bin/env bash
set -Eeuo pipefail
echo "[HOOK] Bundle artifacts:"
ls -al build/app/outputs 2>/dev/null || true
ls -al build/ios/ipa 2>/dev/null || true
