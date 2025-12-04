#!/usr/bin/env bash
set -euo pipefail

# Basic logger.
log() {
  echo "[grype] $*"
}

# Print CLI usage help.
usage() {
  cat <<'EOF'
Run Anchore Grype on OSS and NES Spring PetClinic branches.

Optional (defaults shown):
  --oss-repo    Git URL for OSS PetClinic (default: https://github.com/neverendingsupport/nes-spring-petclinic.git)
  --oss-branch  Branch/tag for OSS PetClinic (default: OSS)
  --nes-repo    Git URL for NES PetClinic (default: https://github.com/neverendingsupport/nes-spring-petclinic.git)
  --nes-branch  Branch/tag for NES PetClinic (default: nes-2.7.x)
  --workdir     Base dir to clone into (default: <repo-root>/local-clones)
  --out         Where to write reports (default: <script-dir>/grype-output)
  --grype-config Grype config file with ignore rules (default: <repo-root>/exclusions/grype-ignore.yaml if present)

Example:
  ./run.sh

Install Grype CLI:
  curl -sSfL https://get.anchore.io/grype | sudo sh -s -- -b /usr/local/bin

EOF
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

WORKDIR=""
OUT_DIR="$SCRIPT_DIR/grype-output"
OSS_REPO="https://github.com/neverendingsupport/nes-spring-petclinic.git"
OSS_BRANCH="OSS"
NES_REPO="https://github.com/neverendingsupport/nes-spring-petclinic.git"
NES_BRANCH="nes-2.7.x"
GRYPE_CONFIG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --oss-repo) OSS_REPO="$2"; shift 2;;
    --oss-branch) OSS_BRANCH="$2"; shift 2;;
    --nes-repo) NES_REPO="$2"; shift 2;;
    --nes-branch) NES_BRANCH="$2"; shift 2;;
    --workdir) WORKDIR="$2"; shift 2;;
    --out) OUT_DIR="$2"; shift 2;;
    --grype-config) GRYPE_CONFIG="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1;;
  esac
done

if ! command -v grype >/dev/null 2>&1; then
  echo "grype CLI not found on PATH." >&2
  exit 1
fi

if [[ -z "$WORKDIR" ]]; then
  WORKDIR="$ROOT_DIR/local-clones"
fi

if [[ -z "$GRYPE_CONFIG" && -f "$ROOT_DIR/exclusions/grype-ignore.yaml" ]]; then
  GRYPE_CONFIG="$ROOT_DIR/exclusions/grype-ignore.yaml"
fi

mkdir -p "$WORKDIR"
mkdir -p "$OUT_DIR"

# Clone or refresh a target repo.
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

# Run grype against a source directory.
scan_dir() {
  local label="$1" dir="$2"
  local outfile="$OUT_DIR/${label}-petclinic-grype.json"
  log "Scanning $dir -> $outfile"
  local args=("dir:${dir}" --output json)
  if [[ -n "$GRYPE_CONFIG" ]]; then
    args+=(--config "$GRYPE_CONFIG")
  fi
  grype "${args[@]}" > "$outfile"
  log "Wrote $outfile"
}

OSS_DIR="$WORKDIR/oss-petclinic"
NES_DIR="$WORKDIR/nes-petclinic"

log "Using workdir $WORKDIR and output dir $OUT_DIR"
ensure_repo "$OSS_REPO" "$OSS_BRANCH" "$OSS_DIR"
ensure_repo "$NES_REPO" "$NES_BRANCH" "$NES_DIR"

scan_dir "oss" "$OSS_DIR"
scan_dir "nes" "$NES_DIR"

log "Done. Reports in $OUT_DIR"
