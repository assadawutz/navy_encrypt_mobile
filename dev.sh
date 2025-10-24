#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

function usage() {
  cat <<'USAGE'
Usage: ./dev.sh [command]

Commands:
  setup           Run flutter clean, pub get, and CocoaPods install.
  build-ios-sim   Build the iOS simulator artifact.
  build-android   Build the Android release APK.
  build-windows   Build the Windows desktop application.
  all             Run setup and all build targets.
USAGE
}

function ensure_fvm() {
  if ! command -v fvm >/dev/null 2>&1; then
    echo "Error: fvm is not installed or not available in PATH." >&2
    exit 1
  fi
}

function run_flutter() {
  ensure_fvm
  echo "> fvm flutter $*"
  (cd "$REPO_ROOT" && fvm flutter "$@")
}

function run_pod_install() {
  if [ ! -d "$REPO_ROOT/ios" ]; then
    echo "Warning: ios directory not found; skipping pod install." >&2
    return
  fi
  if ! command -v pod >/dev/null 2>&1; then
    echo "Warning: CocoaPods (pod) not installed; skipping pod install." >&2
    return
  fi
  echo "> pod install"
  (cd "$REPO_ROOT/ios" && pod install)
}

function cmd_setup() {
  run_flutter clean
  run_flutter pub get
  run_pod_install
}

function cmd_build_ios_sim() {
  run_flutter build ios --simulator
}

function cmd_build_android() {
  run_flutter build apk --release
}

function cmd_build_windows() {
  run_flutter build windows
}

function cmd_all() {
  cmd_setup
  cmd_build_ios_sim
  cmd_build_android
  cmd_build_windows
}

COMMAND="${1:-all}"

case "$COMMAND" in
  setup)
    cmd_setup
    ;;
  build-ios-sim)
    cmd_build_ios_sim
    ;;
  build-android)
    cmd_build_android
    ;;
  build-windows)
    cmd_build_windows
    ;;
  all)
    cmd_all
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    echo "Unknown command: $COMMAND" >&2
    usage
    exit 1
    ;;
esac

