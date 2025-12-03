#!/usr/bin/env bash
set -euo pipefail

# Run every scanner script named run.sh in immediate subdirectories.
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

divider() {
  local name="$1"
  printf '\n======================================================================\n'
  printf "[run-all] >> %s\n" "$name"
  printf "======================================================================\n"
}

for dir in "$ROOT_DIR"/*; do
  if [[ -d "$dir" && -x "$dir/run.sh" ]]; then
    scanner_name="$(basename "$dir")"
    divider "${scanner_name}/run.sh"
    (cd "$dir" && ./run.sh)
    printf "[run-all] Finished %s\n" "$scanner_name"
  fi
done

echo "[run-all] All available scanner scripts completed."
