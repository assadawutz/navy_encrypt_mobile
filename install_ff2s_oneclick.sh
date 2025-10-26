#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/assadawutz/FF2S.OneClick.git"
TARGET_DIR="${1:-tools/FF2S.OneClick}"

log() {
  printf '[FF2S.OneClick] %s\n' "$1"
}

abort() {
  log "Error: $1" >&2
  exit 1
}

if ! command -v git >/dev/null 2>&1; then
  abort "git command not found. Install Git first."
fi

if [ -e "$TARGET_DIR" ]; then
  abort "Target path '$TARGET_DIR' already exists. Remove it or choose another location."
fi

TMP_DIR=$(mktemp -d)
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

log "Cloning $REPO_URL ..."
if ! git clone --depth=1 "$REPO_URL" "$TMP_DIR/repo"; then
  abort "Failed to clone repository. Check network connectivity or proxy settings."
fi

log "Installing into $TARGET_DIR"
mkdir -p "$(dirname "$TARGET_DIR")"
cp -a "$TMP_DIR/repo" "$TARGET_DIR"

log "Cleaning up"
rm -rf "$TMP_DIR"
trap - EXIT

log "Installation complete."
