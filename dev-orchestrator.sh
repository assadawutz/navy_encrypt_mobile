#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$PROJECT_ROOT/logs"; mkdir -p "$LOG_DIR"
RUN_ID="$(date +%Y%m%d-%H%M%S)"; LOG_FILE="$LOG_DIR/dev-orchestrator-${RUN_ID}.log"; REPORT_FILE="$LOG_DIR/dev-orchestrator-${RUN_ID}.report.txt"
c_reset="\033[0m"; c_b="\033[1m"; c_green="\033[32m"; c_yellow="\033[33m"; c_red="\033[31m"; c_blue="\033[34m"
declare -ag FLUTTER_CMD=()
FLUTTER_CMD_SOURCE=""
FLUTTER_VERSION_CHECKED=""
FLUTTER_BOOTSTRAP_ATTEMPTED=0
FLUTTER_BOOTSTRAP_LOCK="$LOG_DIR/.flutter-bootstrap-${RUN_ID}.lock"
FLUTTER_VERSION_REMEDIATED=0

banner(){ echo -e "${c_blue}${c_b}🛠️ DEV ORCHESTRATOR v3.6${c_reset}"; }
is_dry(){ [[ "${DRY_RUN:-0}" == "1" ]]; }
run(){ echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG_FILE"; if is_dry; then echo "[DRY] $*"; else eval "$@" 2>&1 | tee -a "$LOG_FILE"; fi; }
warn(){ echo -e "[$(date +%H:%M:%S)] ${c_yellow}[WARN]${c_reset} $*" | tee -a "$LOG_FILE" >&2; }
has_ios(){ [[ -d "$PROJECT_ROOT/ios" ]]; }
has_android(){ [[ -d "$PROJECT_ROOT/android" ]]; }
has_web(){ [[ -d "$PROJECT_ROOT/web" || -f "$PROJECT_ROOT/web/index.html" ]]; }
has_macos(){ [[ -d "$PROJECT_ROOT/macos" ]]; }
flutter_version_expected(){
  if [[ -n "${FLUTTER_EXPECTED_VERSION:-}" ]]; then
    return
  fi
  if [[ -f "$PROJECT_ROOT/.fvm/fvm_config.json" ]]; then
    FLUTTER_EXPECTED_VERSION="$(sed -n 's/.*"flutter"[[:space:]]*:[[:space:]]*"\([^"]\+\)".*/\1/p' "$PROJECT_ROOT/.fvm/fvm_config.json" | head -n1)"
  fi
  FLUTTER_EXPECTED_VERSION="${FLUTTER_EXPECTED_VERSION:-}"
}

flutter_report_mismatch(){
  flutter_version_expected
  local reported_version="$1"
  if [[ -z "${FLUTTER_EXPECTED_VERSION:-}" || -z "$reported_version" ]]; then
    return
  fi
  if [[ "$reported_version" != "$FLUTTER_EXPECTED_VERSION" ]]; then
    warn "Flutter version $reported_version detected, expected ${FLUTTER_EXPECTED_VERSION}. Run ./fix-fvm.sh --auto to switch to the pinned toolchain."
    if [[ "${FLUTTER_VERSION_REMEDIATED:-0}" != "1" ]]; then
      FLUTTER_VERSION_REMEDIATED=1
      bootstrap_flutter
      FLUTTER_CMD=()
      FLUTTER_CMD_SOURCE=""
      FLUTTER_VERSION_CHECKED=""
    fi
  fi
}

bootstrap_flutter(){
  if [[ "${FLUTTER_BOOTSTRAP_ATTEMPTED:-0}" == "1" ]]; then
    return
  fi
  if [[ -d "$FLUTTER_BOOTSTRAP_LOCK" ]]; then
    FLUTTER_BOOTSTRAP_ATTEMPTED=1
    return
  fi
  if mkdir "$FLUTTER_BOOTSTRAP_LOCK" 2>/dev/null; then
    FLUTTER_BOOTSTRAP_ATTEMPTED=1
  else
    FLUTTER_BOOTSTRAP_ATTEMPTED=1
    warn "Unable to acquire Flutter bootstrap lock at $FLUTTER_BOOTSTRAP_LOCK"
    return
  fi
  if [[ -x "$PROJECT_ROOT/fix-fvm.sh" ]]; then
    warn "Attempting to provision Flutter 3.3.8 via fix-fvm.sh --auto..."
    if is_dry; then
      warn "DRY RUN active; skipping automatic Flutter provisioning."
    else
      if ! "$PROJECT_ROOT/fix-fvm.sh" --auto; then
        warn "Automatic Flutter provisioning failed; install Flutter 3.3.8 manually."
      fi
    fi
  else
    warn "Helper fix-fvm.sh not found; cannot auto-provision Flutter."
  fi
}

flutter_locate_once(){
  local attempted="$1"
  if command -v fvm >/dev/null 2>&1; then
    FLUTTER_CMD=(fvm flutter)
    FLUTTER_CMD_SOURCE="fvm"
  elif [[ -x "$PROJECT_ROOT/.fvm/flutter_sdk/bin/flutter" ]]; then
    FLUTTER_CMD=("$PROJECT_ROOT/.fvm/flutter_sdk/bin/flutter")
    FLUTTER_CMD_SOURCE="bundled"
  elif command -v flutter >/dev/null 2>&1; then
    FLUTTER_CMD=(flutter)
    FLUTTER_CMD_SOURCE="system"
  else
    warn "Flutter CLI not found; run ./fix-fvm.sh --auto to install Flutter 3.3.8. Skipping: flutter ${attempted:-<unknown>}"
    FLUTTER_CMD=()
    FLUTTER_CMD_SOURCE="missing"
  fi
}

flutter_locate(){
  local attempted="$*"
  if [[ -n "${FLUTTER_CMD_SOURCE:-}" && "${FLUTTER_CMD_SOURCE}" != "missing" ]]; then
    return
  fi
  flutter_locate_once "$attempted"
  if [[ "${FLUTTER_CMD_SOURCE:-missing}" == "missing" ]]; then
    bootstrap_flutter
    FLUTTER_CMD=()
    FLUTTER_CMD_SOURCE=""
    FLUTTER_VERSION_CHECKED=""
    flutter_locate_once "$attempted"
  fi
}

flutter_cache_version(){
  if [[ -n "${FLUTTER_VERSION_CHECKED:-}" || ${#FLUTTER_CMD[@]} -eq 0 ]]; then
    return
  fi
  local version_cmd reported_version=""
  case "$FLUTTER_CMD_SOURCE" in
    fvm)
      reported_version="$(fvm flutter --version 2>/dev/null | awk 'NR==1{print $2}')"
      ;;
    bundled|system)
      version_cmd="${FLUTTER_CMD[-1]}"
      reported_version="$($version_cmd --version 2>/dev/null | awk 'NR==1{print $2}')"
      ;;
    *)
      ;;
  esac
  FLUTTER_VERSION_CHECKED=1
  flutter_report_mismatch "$reported_version"
}

flutter_cmd(){
  flutter_locate "$@"
  if [[ ${#FLUTTER_CMD[@]} -eq 0 ]]; then
    return 0
  fi
  flutter_cache_version
  if [[ ${#FLUTTER_CMD[@]} -eq 0 ]]; then
    flutter_locate "$@"
    if [[ ${#FLUTTER_CMD[@]} -eq 0 ]]; then
      return 0
    fi
    flutter_cache_version
  fi
  "${FLUTTER_CMD[@]}" "$@"
}
build_ios(){ has_ios || { warn 'iOS missing'; return 0; }; run "flutter_cmd build ios --release || true"; run "flutter_cmd build ios --debug --simulator || true"; }
build_android(){ has_android || { warn 'Android missing'; return 0; }; run "flutter_cmd build apk --release || true"; run "flutter_cmd build appbundle --release || true"; }
build_web(){ has_web || { warn 'Web missing'; return 0; }; run "flutter_cmd build web || true"; }
build_macos(){ has_macos || { warn 'macOS missing'; return 0; }; run "flutter_cmd build macos || true"; }
run_ios(){
  has_ios || { warn 'iOS missing'; return 0; }
  local dev
  dev="$(flutter_cmd devices | awk '/iOS Simulator/{print $1; exit}' || true)"
  if [[ -z "$dev" ]]; then
    if command -v open >/dev/null 2>&1; then
      open -a Simulator || true
      sleep 5
      dev="$(flutter_cmd devices | awk '/iOS Simulator/{print $1; exit}' || true)"
    else
      warn "macOS 'open' command unavailable; unable to auto-start iOS simulator."
    fi
  fi
  if [[ -n "$dev" ]]; then
    run "flutter_cmd run -d \"$dev\" --release || flutter_cmd run -d \"$dev\" || true"
  else
    warn "No iOS simulator detected; skipping flutter run."
  fi
  return 0
}
run_android(){
  has_android || { warn 'Android missing'; return 0; }
  local dev
  adb start-server >/dev/null 2>&1 || true
  sleep 2
  dev="$(flutter_cmd devices | awk '/android-emulator|Android/{print $1; exit}' || true)"
  if [[ -n "$dev" ]]; then
    run "flutter_cmd run -d \"$dev\" --release || flutter_cmd run -d \"$dev\" || true"
  else
    warn "No Android device found; skipping flutter run."
  fi
  return 0
}
run_web(){ has_web || { warn 'Web missing'; return 0; }; run "flutter_cmd run -d web-server --web-port 7357 --web-enable-expression-evaluation || true"; }
run_macos(){ has_macos || { warn 'macOS missing'; return 0; }; run "flutter_cmd run -d macos || true"; }
mode_build_all(){
  local status=0
  flutter_cmd --version >/dev/null 2>&1 || true
  if [[ "${1-}" == "--parallel" ]]; then
    shift || true
    local pids=()
    if has_ios; then build_ios & pids+=($!); fi
    if has_android; then build_android & pids+=($!); fi
    if has_web; then build_web & pids+=($!); fi
    if has_macos; then build_macos & pids+=($!); fi
    for pid in "${pids[@]}"; do
      wait "$pid" || status=1
    done
  else
    if has_ios; then build_ios || status=1; fi
    if has_android; then build_android || status=1; fi
    if has_web; then build_web || status=1; fi
    if has_macos; then build_macos || status=1; fi
  fi
  return $status
}

mode_run_all(){
  local status=0
  flutter_cmd --version >/dev/null 2>&1 || true
  if has_ios; then run_ios || status=1; fi
  if has_android; then run_android || status=1; fi
  if has_web; then run_web || status=1; fi
  if has_macos; then run_macos || status=1; fi
  return $status
}
mode_quick(){ ./fix-fvm.sh --preflight; ./fix-fvm.sh --auto; ./fix-null-safety.sh --preflight; ./fix-null-safety.sh --auto; has_ios&&{ ./fix-ios.sh --preflight; ./fix-ios.sh --auto; }; has_android&&{ ./fix-android.sh --preflight; ./fix-android.sh --auto; }; }
mode_deep(){ run "rm -rf \"$PROJECT_ROOT/build\" \"$PROJECT_ROOT/.dart_tool\""; run "rm -rf ~/Library/Developer/Xcode/DerivedData"; run "rm -rf \"$PROJECT_ROOT/android/.gradle\" ~/.gradle/caches"; mode_quick; }
mode_matrix(){ ./fix-matrix.sh; }
mode_ios_only(){ has_ios && { ./ios-fix-all.sh; } || warn "iOS not found"; }
mode_android_only(){ has_android && { ./android-fix-all.sh; } || warn "Android not found"; }
mode_fvm_only(){ ./fix-fvm.sh --preflight; ./fix-fvm.sh --auto; }
mode_null_only(){ ./fix-null-safety.sh --preflight; ./fix-null-safety.sh --auto; }
mode_all(){ ./fix-platform-all.sh; }
mode_smoke(){ mode_build_all "$@"; mode_run_all; }
mode_report(){ echo "Dev Orchestrator Report - $(date)" > "$REPORT_FILE"; printf "Artifacts:\n  iOS IPA: build/ios/ipa/\n  Android APK: build/app/outputs/flutter-apk/\n  Android AAB: build/app/outputs/bundle/release/\n  Web: build/web/\n  macOS: build/macos/Build/Products/Release/\n" >> "$REPORT_FILE"; echo "Saved: $REPORT_FILE"; }
menu(){ clear; banner; echo "1) QUICK 2) DEEP 3) MATRIX 4) iOS ONLY 5) ANDROID ONLY 6) FVM ONLY 7) NULL ONLY 8) ALL PLATFORMS 9) SMOKE 10) BUILD ALL 11) RUN ALL 12) REPORT 0) EXIT"; read -r n; case "$n" in 1) mode_quick;;2) mode_deep;;3) mode_matrix;;4) mode_ios_only;;5) mode_android_only;;6) mode_fvm_only;;7) mode_null_only;;8) mode_all;;9) mode_smoke;;10) mode_build_all;;11) mode_run_all;;12) mode_report;;0) exit 0;;*) echo "Invalid";; esac; echo; read -r -p "Enter to menu..." _; menu; }
main(){ banner; case "${1-}" in --quick) mode_quick;; --deep) mode_deep;; --matrix) mode_matrix;; --ios) mode_ios_only;; --android) mode_android_only;; --fvm) mode_fvm_only;; --null) mode_null_only;; --all) mode_all;; --smoke) shift||true; mode_smoke "$@";; --build-all) shift||true; mode_build_all "$@";; --run-all) mode_run_all;; --report) mode_report;; *) menu;; esac; echo -e "${c_green}${c_b}DONE${c_reset} Log: $LOG_FILE"; }
main "$@"
