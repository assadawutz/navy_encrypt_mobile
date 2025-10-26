#!/usr/bin/env bash
set -euo pipefail

if ! command -v git >/dev/null 2>&1; then
  echo "git is required to run this script" >&2
  exit 127
fi

repo_root=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [[ -z "$repo_root" ]]; then
  echo "Unable to determine git repository root" >&2
  exit 2
fi

cd "$repo_root"

mapfile -d '' status_entries < <(git status --porcelain -z)
unmerged_paths=()
for entry in "${status_entries[@]}"; do
  status=${entry:0:2}
  path=${entry:3}
  case "$status" in
    AA|DD|UU|DU|UD)
      unmerged_paths+=("$path")
      ;;
  esac
done

if (( ${#unmerged_paths[@]} > 0 )); then
  echo "Unmerged paths detected:" >&2
  printf '  %s\n' "${unmerged_paths[@]}" >&2
  exit 3
fi

if ! command -v rg >/dev/null 2>&1; then
  echo "ripgrep (rg) is required to scan for conflict markers" >&2
  exit 127
fi

conflict_markers=$(rg --hidden --glob '!.git' --no-ignore --color never --no-messages -n '^(<<<<<<<|=======|>>>>>>>)' || true)
if [[ -n "$conflict_markers" ]]; then
  echo "Conflict markers detected:" >&2
  echo "$conflict_markers" >&2
  exit 4
fi

echo "No merge conflicts or conflict markers detected."
