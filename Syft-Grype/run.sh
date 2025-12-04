#!/usr/bin/env bash
set -euo pipefail

log() {
  # Log to stderr so command substitution callers don't capture log lines.
  echo "[syft-grype] $*" >&2
}

# Print CLI usage help.
usage() {
  cat <<'EOF'
Generate SBOMs with Syft and scan them with Grype for OSS and NES Spring PetClinic branches.

Optional (defaults shown):
  --oss-repo    Git URL for OSS PetClinic (default: https://github.com/neverendingsupport/nes-spring-petclinic.git)
  --oss-branch  Branch/tag for OSS PetClinic (default: OSS)
  --nes-repo    Git URL for NES PetClinic (default: https://github.com/neverendingsupport/nes-spring-petclinic.git)
  --nes-branch  Branch/tag for NES PetClinic (default: nes-2.7.x)
  --workdir     Base dir to clone into (default: <repo-root>/local-clones)
  --out         Where to write SBOMs/results (default: <script-dir>/syft-grype-output)
  --grype-config Grype config file with ignore rules (default: <repo-root>/exclusions/grype-ignore.yaml if present)

Example:
  ./run.sh

Install syft:
  curl -sSfL https://get.anchore.io/syft | sudo sh -s -- -b /usr/local/bin

EOF
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

WORKDIR=""
OUT_DIR="$SCRIPT_DIR/syft-grype-output"
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

if ! command -v syft >/dev/null 2>&1; then
  echo "syft CLI not found on PATH." >&2
  exit 1
fi
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

# Create a CycloneDX SBOM for a given source directory.
generate_sbom() {
  local label="$1" dir="$2"
  local sbom="$OUT_DIR/${label}-petclinic-sbom.cdx.json"
  log "Generating SBOM from $dir -> $sbom"
  syft "dir:${dir}" -o cyclonedx-json > "$sbom"
  echo "$sbom"
}

# Scan a generated SBOM with grype, optionally using a config file.
scan_sbom() {
  local label="$1" sbom="$2"
  local outfile="$OUT_DIR/${label}-petclinic-grype.json"
  log "Scanning SBOM $sbom -> $outfile"
  local args=("sbom:${sbom}" --output json)
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

OSS_SBOM="$(generate_sbom "oss" "$OSS_DIR")"
NES_SBOM="$(generate_sbom "nes" "$NES_DIR")"

scan_sbom "oss" "$OSS_SBOM"
scan_sbom "nes" "$NES_SBOM"

echo "Done. Outputs in $OUT_DIR"
