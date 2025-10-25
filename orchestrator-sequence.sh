#!/usr/bin/env bash
set -Eeuo pipefail
LOG_DIR="./logs"; mkdir -p "$LOG_DIR"
RUN_ID="$(date +%Y%m%d-%H%M%S)"; LOG_FILE="$LOG_DIR/orchestrator-sequence-${RUN_ID}.log"
need(){ for f in "$@"; do [[ -x "$f" ]] || { echo "Missing $f"; exit 1; }; done; }
run_ios_menu(){ IFS=',' read -ra n <<<"$1"; for i in "${n[@]}"; do printf "%s\n\n" "$i" | ./fix-ios.sh | tee -a "$LOG_FILE"; done; }
run_android_menu(){ IFS=',' read -ra n <<<"$1"; for i in "${n[@]}"; do printf "%s\n\n" "$i" | ./fix-android.sh | tee -a "$LOG_FILE"; done; }
dispatch(){ case "$1" in quick) ./dev-orchestrator.sh --quick | tee -a "$LOG_FILE";; deep) ./dev-orchestrator.sh --deep | tee -a "$LOG_FILE";; matrix) ./dev-orchestrator.sh --matrix | tee -a "$LOG_FILE";; ios) ./dev-orchestrator.sh --ios | tee -a "$LOG_FILE";; android) ./dev-orchestrator.sh --android | tee -a "$LOG_FILE";; fvm) ./dev-orchestrator.sh --fvm | tee -a "$LOG_FILE";; null) ./dev-orchestrator.sh --null | tee -a "$LOG_FILE";; all) ./dev-orchestrator.sh --all | tee -a "$LOG_FILE";; smoke) shift; ./dev-orchestrator.sh --smoke "$@" | tee -a "$LOG_FILE";; build-all) shift; ./dev-orchestrator.sh --build-all "$@" | tee -a "$LOG_FILE";; run-all) ./dev-orchestrator.sh --run-all | tee -a "$LOG_FILE";; report) ./dev-orchestrator.sh --report | tee -a "$LOG_FILE";; ios:*) run_ios_menu "${1#ios:}";; android:*) run_android_menu "${1#android:}";; *) echo "Unknown token $1";; esac; }
main(){ need ./dev-orchestrator.sh ./fix-ios.sh ./fix-android.sh; PAR=""; for a in "$@"; do [[ "$a" == "--parallel" ]] && PAR="--parallel"; done; for a in "$@"; do [[ "$a" == "--parallel" ]] && continue; case "$a" in smoke|build-all) dispatch "$a" "$PAR";; *) dispatch "$a";; esac; done; }
main "$@"
