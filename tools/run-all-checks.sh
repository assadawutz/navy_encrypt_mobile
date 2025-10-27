#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

status_file=""
if [[ "${1:-}" == "--ci" ]]; then
  status_file="$PROJECT_ROOT/build/run-all-status.log"
  mkdir -p "$(dirname "$status_file")"
  : >"$status_file"
fi

log(){
  echo "[$(date +%H:%M:%S)] $*"
  if [[ -n "$status_file" ]]; then
    echo "$*" >>"$status_file"
  fi
}

warn(){
  log "WARN: $*" >&2
}

abort(){
  warn "$*"
  exit 1
}

find_flutter(){
  if command -v fvm >/dev/null 2>&1; then
    echo "fvm flutter"
    return 0
  fi
  if [[ -x "$PROJECT_ROOT/.fvm/flutter_sdk/bin/flutter" ]]; then
    echo "$PROJECT_ROOT/.fvm/flutter_sdk/bin/flutter"
    return 0
  fi
  if command -v flutter >/dev/null 2>&1; then
    echo "flutter"
    return 0
  fi
  abort "Flutter CLI not found. Run ./fix-fvm.sh --auto first."
}

FLUTTER_CMD=$(find_flutter)

run_flutter(){
  local cmd="$1"; shift || true
  if [[ "$FLUTTER_CMD" == fvm\ flutter ]]; then
    fvm flutter "$cmd" "$@"
  else
    "$FLUTTER_CMD" "$cmd" "$@"
  fi
}

ensure_pub_get(){
  if [[ "${SKIP_PUB_GET:-}" == "1" ]]; then
    log "SKIP_PUB_GET=1 -> skipping flutter pub get"
    return 0
  fi
  log "Resolving Flutter packages"
  run_flutter pub get
}

format_sources(){
  if [[ "${SKIP_FORMAT:-}" == "1" ]]; then
    log "SKIP_FORMAT=1 -> skipping dart format"
    return 0
  fi
  local targets=()
  if [[ -d "$PROJECT_ROOT/lib" ]]; then
    targets+=("lib")
  fi
  if [[ -d "$PROJECT_ROOT/test" ]]; then
    targets+=("test")
  fi
  if [[ ${#targets[@]} -eq 0 ]]; then
    log "No lib/test directories found; skipping format check"
    return 0
  fi
  log "Checking Dart formatting"
  run_flutter format --set-exit-if-changed "${targets[@]}"
}

run_analyze(){
  if [[ "${SKIP_ANALYZE:-}" == "1" ]]; then
    log "SKIP_ANALYZE=1 -> skipping flutter analyze"
    return 0
  fi
  log "Running flutter analyze"
  run_flutter analyze
}

run_tests(){
  if [[ "${SKIP_TESTS:-}" == "1" ]]; then
    log "SKIP_TESTS=1 -> skipping flutter test"
    return 0
  fi
  if [[ -d "$PROJECT_ROOT/test" ]]; then
    log "Running Flutter tests"
    run_flutter test --coverage "$@"
  else
    log "No test directory; skipping flutter test"
  fi
}

build_android(){
  if [[ "${SKIP_ANDROID_BUILD:-}" == "1" ]]; then
    log "SKIP_ANDROID_BUILD=1 -> skipping Android builds"
    return 0
  fi
  if [[ -d "$PROJECT_ROOT/android" ]]; then
    log "Building Android APK (release)"
    run_flutter build apk --release "$@"
    log "Building Android appbundle (release)"
    run_flutter build appbundle --release "$@"
  else
    log "Android directory missing; skipping Android builds"
  fi
}

build_ios_no_codesign(){
  if [[ "${SKIP_IOS_BUILD:-}" == "1" ]]; then
    log "SKIP_IOS_BUILD=1 -> skipping iOS build"
    return 0
  fi
  if [[ "$(uname -s)" != "Darwin" ]]; then
    log "Non-macOS host detected; skipping iOS build"
    return 0
  fi
  if [[ -d "$PROJECT_ROOT/ios" ]]; then
    log "Building iOS IPA (no codesign)"
    run_flutter build ipa --no-codesign "$@"
  else
    log "iOS directory missing; skipping iOS build"
  fi
}

build_web(){
  if [[ "${SKIP_WEB_BUILD:-}" == "1" ]]; then
    log "SKIP_WEB_BUILD=1 -> skipping web build"
    return 0
  fi
  if [[ -d "$PROJECT_ROOT/web" ]]; then
    log "Building Flutter web"
    run_flutter build web "$@"
  else
    log "Web directory missing; skipping web build"
  fi
}

main(){
  ensure_pub_get
  format_sources
  run_analyze
  run_tests
  build_android
  build_ios_no_codesign
  build_web
  log "All checks done"
}

main "$@"
