#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[scorecard] $*"
}

usage() {
  cat <<'EOF'
Run OpenSSF Scorecard on OSS and NES Spring PetClinic branches.

Optional (defaults shown):
  --oss-repo    Git URL for OSS PetClinic (default: https://github.com/neverendingsupport/nes-spring-petclinic.git)
  --oss-branch  Branch/tag for OSS PetClinic (default: OSS)
  --nes-repo    Git URL for NES PetClinic (default: https://github.com/neverendingsupport/nes-spring-petclinic.git)
  --nes-branch  Branch/tag for NES PetClinic (default: nes-2.7.x)
  --workdir     Base dir to clone into (default: <repo-root>/local-clones)
  --out         Where to write reports (default: <script-dir>/scorecard-output)

Example:
  ./run.sh

Install scorecard CLI:
  https://github.com/ossf/scorecard/releases/latest

EOF
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

WORKDIR=""
OUT_DIR="$SCRIPT_DIR/scorecard-output"
OSS_REPO="https://github.com/neverendingsupport/nes-spring-petclinic.git"
OSS_BRANCH="OSS"
NES_REPO="https://github.com/neverendingsupport/nes-spring-petclinic.git"
NES_BRANCH="nes-2.7.x"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --oss-repo) OSS_REPO="$2"; shift 2;;
    --oss-branch) OSS_BRANCH="$2"; shift 2;;
    --nes-repo) NES_REPO="$2"; shift 2;;
    --nes-branch) NES_BRANCH="$2"; shift 2;;
    --workdir) WORKDIR="$2"; shift 2;;
    --out) OUT_DIR="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1;;
  esac
done

if ! command -v scorecard >/dev/null 2>&1; then
  echo "scorecard CLI not found on PATH." >&2
  exit 1
fi

if [[ -z "$WORKDIR" ]]; then
  WORKDIR="$ROOT_DIR/local-clones"
fi

mkdir -p "$WORKDIR"
mkdir -p "$OUT_DIR"

ensure_repo() {
  local repo="$1" branch="$2" target="$3"
  if [[ -d "$target/.git" ]]; then
    log "Refreshing $target to branch $branch"
    if [[ -n "$(git -C "$target" status --porcelain)" ]]; then
      echo "Existing repo at $target has local changes. Clean it or specify a different --workdir." >&2
      exit 1
    fi
    git -C "$target" fetch --depth 1 origin "$branch"
    git -C "$target" checkout "$branch" || git -C "$target" checkout -B "$branch" "origin/$branch"
    git -C "$target" reset --hard "origin/$branch"
  else
    log "Cloning $repo ($branch) into $target"
    git clone --depth 1 --branch "$branch" "$repo" "$target"
  fi
}

scan_dir() {
  local label="$1" repo="$2" branch="$3" dir="$4"
  local outfile="$OUT_DIR/${label}-petclinic-scorecard.json"
  log "Running scorecard for $repo@$branch -> $outfile"
  # scorecard needs exactly one target flag; use --local and add metadata for provenance.
  scorecard \
    --local "$dir" \
    --metadata "repo=$repo" \
    --metadata "branch=$branch" \
    --format json \
    --show-details > "$outfile"
  log "Wrote $outfile"
}

OSS_DIR="$WORKDIR/oss-petclinic"
NES_DIR="$WORKDIR/nes-petclinic"

log "Using workdir $WORKDIR and output dir $OUT_DIR"
ensure_repo "$OSS_REPO" "$OSS_BRANCH" "$OSS_DIR"
ensure_repo "$NES_REPO" "$NES_BRANCH" "$NES_DIR"

scan_dir "oss" "$OSS_REPO" "$OSS_BRANCH" "$OSS_DIR"
scan_dir "nes" "$NES_REPO" "$NES_BRANCH" "$NES_DIR"

log "Done. Reports in $OUT_DIR"
