#!/usr/bin/env bash
cat <<'TXT'
One-Click Recovery:
  fix-all      -> ./dev-orchestrator.sh --deep
  build-all    -> ./dev-orchestrator.sh --build-all --parallel
  run-all      -> ./dev-orchestrator.sh --run-all
  matrix       -> ./dev-orchestrator.sh --matrix
  smoke        -> ./dev-orchestrator.sh --smoke --parallel
  ios/android  -> ./dev-orchestrator.sh --ios / --android
TXT
