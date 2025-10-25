#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$PROJECT_ROOT/logs"; mkdir -p "$LOG_DIR"
RUN_ID="$(date +%Y%m%d-%H%M%S)"; LOG_FILE="$LOG_DIR/dev-orchestrator-${RUN_ID}.log"; REPORT_FILE="$LOG_DIR/dev-orchestrator-${RUN_ID}.report.txt"
c_reset="\033[0m"; c_b="\033[1m"; c_green="\033[32m"; c_yellow="\033[33m"; c_red="\033[31m"; c_blue="\033[34m"
banner(){ echo -e "${c_blue}${c_b}🛠️ DEV ORCHESTRATOR v3.6${c_reset}"; }
is_dry(){ [[ "${DRY_RUN:-0}" == "1" ]]; }
run(){ echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG_FILE"; if is_dry; then echo "[DRY] $*"; else eval "$@" 2>&1 | tee -a "$LOG_FILE"; fi; }
warn(){ echo -e "[$(date +%H:%M:%S)] ${c_yellow}[WARN]${c_reset} $*" | tee -a "$LOG_FILE" >&2; }
has_ios(){ [[ -d "$PROJECT_ROOT/ios" ]]; }
has_android(){ [[ -d "$PROJECT_ROOT/android" ]]; }
has_web(){ [[ -d "$PROJECT_ROOT/web" || -f "$PROJECT_ROOT/web/index.html" ]]; }
has_macos(){ [[ -d "$PROJECT_ROOT/macos" ]]; }
flutter_cmd(){ if command -v fvm >/dev/null 2>&1; then fvm flutter "$@"; else flutter "$@"; fi; }
build_ios(){ has_ios || { warn 'iOS missing'; return 0; }; run "flutter_cmd build ios --release || true"; run "flutter_cmd build ios --debug --simulator || true"; }
build_android(){ has_android || { warn 'Android missing'; return 0; }; run "flutter_cmd build apk --release || true"; run "flutter_cmd build appbundle --release || true"; }
build_web(){ has_web || { warn 'Web missing'; return 0; }; run "flutter_cmd build web || true"; }
build_macos(){ has_macos || { warn 'macOS missing'; return 0; }; run "flutter_cmd build macos || true"; }
run_ios(){ has_ios || { warn 'iOS missing'; return 0; }; local dev; dev="$(flutter_cmd devices | awk '/iOS Simulator/{print $1; exit}' || true)"; [[ -z "$dev" ]] && { open -a Simulator || true; sleep 5; dev="$(flutter_cmd devices | awk '/iOS Simulator/{print $1; exit}' || true)"; }; [[ -n "$dev" ]] && run "flutter_cmd run -d \"$dev\" --release || flutter_cmd run -d \"$dev\" || true"; }
run_android(){ has_android || { warn 'Android missing'; return 0; }; local dev; adb start-server >/dev/null 2>&1 || true; sleep 2; dev="$(flutter_cmd devices | awk '/android-emulator|Android/{print $1; exit}' || true)"; [[ -n "$dev" ]] && run "flutter_cmd run -d \"$dev\" --release || flutter_cmd run -d \"$dev\" || true"; }
run_web(){ has_web || { warn 'Web missing'; return 0; }; run "flutter_cmd run -d web-server --web-port 7357 --web-enable-expression-evaluation || true"; }
run_macos(){ has_macos || { warn 'macOS missing'; return 0; }; run "flutter_cmd run -d macos || true"; }
mode_build_all(){ [[ "${1-}" == "--parallel" ]] && { has_ios&&build_ios & has_android&&build_android & has_web&&build_web & has_macos&&build_macos & wait; } || { has_ios&&build_ios; has_android&&build_android; has_web&&build_web; has_macos&&build_macos; }; }
mode_run_all(){ has_ios&&run_ios; has_android&&run_android; has_web&&run_web; has_macos&&run_macos; }
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
