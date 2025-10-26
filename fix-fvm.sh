#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
FVM_BIN="$(command -v fvm 2>/dev/null || true)"
SYSTEM_FLUTTER_BIN="$(command -v flutter 2>/dev/null || true)"
LOCAL_FLUTTER_DIR="$PROJECT_ROOT/.fvm/flutter_sdk"
LOCAL_FLUTTER_BIN="$LOCAL_FLUTTER_DIR/bin/flutter"
ARCHIVE_CANDIDATE_DEFAULT="$PROJECT_ROOT/tools/cache/flutter_3.3.8-stable.tar.xz"
ARCHIVE_CANDIDATE="${FLUTTER_SDK_ARCHIVE:-$ARCHIVE_CANDIDATE_DEFAULT}"

read -r -a ARCHIVE_URLS_CLI <<< "${FLUTTER_SDK_URLS:-}"
ARCHIVE_URLS=("${ARCHIVE_URLS_CLI[@]}")
ARCHIVE_URLS+=(
  "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.3.8-stable.tar.xz"
  "https://storage.flutter-io.cn/flutter_infra_release/releases/stable/linux/flutter_linux_3.3.8-stable.tar.xz"
)

cleanup_temp(){
  local temp_path="$1"
  if [[ -n "$temp_path" && -f "$temp_path" ]]; then
    rm -f "$temp_path"
  fi
}

fetch_with_tool(){
  local url="$1"
  local output="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fL "$url" -o "$output"
    return $?
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$output" "$url"
    return $?
  fi
  echo "[FVM] Neither curl nor wget is available for downloading archives." >&2
  return 2
}

download_archive(){
  if [[ -f "$ARCHIVE_CANDIDATE" ]]; then
    return 0
  fi
  local destination_dir
  destination_dir="$(dirname "$ARCHIVE_CANDIDATE")"
  mkdir -p "$destination_dir"
  local temp_file="$ARCHIVE_CANDIDATE.download"
  cleanup_temp "$temp_file"
  for url in "${ARCHIVE_URLS[@]}"; do
    if [[ -z "$url" ]]; then
      continue
    fi
    echo "[FVM] Attempting to download Flutter archive from $url"
    if fetch_with_tool "$url" "$temp_file"; then
      mv "$temp_file" "$ARCHIVE_CANDIDATE"
      echo "[FVM] Downloaded archive to $ARCHIVE_CANDIDATE"
      return 0
    fi
  done
  cleanup_temp "$temp_file"
  echo "[FVM] Unable to download Flutter archive; tried ${#ARCHIVE_URLS[@]} URL(s)." >&2
  return 1
}

extract_archive(){
  local archive_path="$1"
  local destination_parent="$PROJECT_ROOT/.fvm"
  if [[ ! -f "$archive_path" ]]; then
    echo "[FVM] Offline archive $archive_path not found."
    return 1
  fi
  echo "[FVM] Extracting Flutter archive from $archive_path ..."
  mkdir -p "$destination_parent"
  tar -xf "$archive_path" -C "$destination_parent"
  if [[ -d "$destination_parent/flutter" && "$destination_parent/flutter" != "$LOCAL_FLUTTER_DIR" ]]; then
    rm -rf -- "$LOCAL_FLUTTER_DIR"
    mv "$destination_parent/flutter" "$LOCAL_FLUTTER_DIR"
  fi
  if [[ ! -x "$LOCAL_FLUTTER_BIN" ]]; then
    echo "[FVM] Extraction completed, but flutter binary missing at $LOCAL_FLUTTER_BIN"
    return 1
  fi
  "$LOCAL_FLUTTER_BIN" --version || true
}

doctor_precache(){
  if [[ $# -eq 0 ]]; then
    echo "[FVM] doctor_precache requires a flutter command"
    return 1
  fi
  "$@" doctor -v || true
  "$@" precache || true
}

ensure_local_flutter(){
  if [[ -x "$LOCAL_FLUTTER_BIN" ]]; then
    return 0
  fi
  if [[ -f "$ARCHIVE_CANDIDATE" ]]; then
    extract_archive "$ARCHIVE_CANDIDATE" || return 1
    return 0
  fi
  if download_archive; then
    extract_archive "$ARCHIVE_CANDIDATE" || return 1
    return 0
  fi
  return 1
}

use_fvm_flutter(){
  if [[ -z "$FVM_BIN" ]]; then
    return 1
  fi
  if "$FVM_BIN" flutter --version >/dev/null 2>&1; then
    doctor_precache "$FVM_BIN" flutter
    return 0
  fi
  "$FVM_BIN" install >/dev/null 2>&1 || true
  "$FVM_BIN" use >/dev/null 2>&1 || true
  if "$FVM_BIN" flutter --version >/dev/null 2>&1; then
    doctor_precache "$FVM_BIN" flutter
    return 0
  fi
  return 1
}

case "${1-}" in
  --preflight)
    echo "[FVM] Preflight"
    if [[ -n "$FVM_BIN" ]]; then
      echo "[FVM] fvm located at $FVM_BIN"
    else
      echo "[FVM] fvm not found in PATH"
    fi
    if [[ -n "$SYSTEM_FLUTTER_BIN" ]]; then
      echo "[FVM] flutter located at $SYSTEM_FLUTTER_BIN"
      "$SYSTEM_FLUTTER_BIN" --version || true
    elif [[ -x "$LOCAL_FLUTTER_BIN" ]]; then
      echo "[FVM] flutter (local) located at $LOCAL_FLUTTER_BIN"
      "$LOCAL_FLUTTER_BIN" --version || true
    else
      echo "[FVM] flutter not found"
    fi
    ;;
  --auto|*)
    echo "[FVM] Auto"
    if use_fvm_flutter; then
      exit 0
    fi
    if ensure_local_flutter; then
      doctor_precache "$LOCAL_FLUTTER_BIN"
    elif [[ -n "$SYSTEM_FLUTTER_BIN" ]]; then
      doctor_precache "$SYSTEM_FLUTTER_BIN"
    else
      echo "[FVM] Flutter CLI unavailable. Provide fvm, install Flutter globally, or place archive at $ARCHIVE_CANDIDATE" >&2
      exit 1
    fi
    ;;
esac
