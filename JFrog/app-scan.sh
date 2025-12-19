#!/usr/bin/env bash
set -euo pipefail

# Run JFrog on-demand audit scans on OSS and NES Spring PetClinic sources.
usage() {
  cat <<'EOF'
Usage: ./JFrog/app-scan.sh [--oss-repo <url>] [--oss-branch <branch>] [--nes-repo <url>]
                           [--nes-branch <branch>] [--workdir <dir>] [--out <dir>]
                           [--server-id <id>] [--insecure-tls] [--format <fmt>]
                           [--fail <true|false>] [--exclusions <list>]

Defaults:
  --oss-repo    https://github.com/neverendingsupport/nes-spring-petclinic.git
  --oss-branch  OSS
  --nes-repo    https://github.com/neverendingsupport/nes-spring-petclinic.git
  --nes-branch  nes-2.7.x
  --workdir     <repo-root>/local-clones
  --out         <repo-root>/JFrog/output
  --format      table
  --fail        true

Example:
  ./JFrog/app-scan.sh --format table --fail false
EOF
}

log() {
  echo "[jfrog-audit] $*"
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

WORKDIR=""
OUT_DIR="$SCRIPT_DIR/output"
OSS_REPO="https://github.com/neverendingsupport/nes-spring-petclinic.git"
OSS_BRANCH="OSS"
NES_REPO="https://github.com/neverendingsupport/nes-spring-petclinic.git"
NES_BRANCH="nes-2.7.x"
SERVER_ID=""
INSECURE_TLS="false"
FORMAT="table"
FAIL="true"
EXCLUSIONS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --oss-repo) OSS_REPO="$2"; shift 2;;
    --oss-branch) OSS_BRANCH="$2"; shift 2;;
    --nes-repo) NES_REPO="$2"; shift 2;;
    --nes-branch) NES_BRANCH="$2"; shift 2;;
    --workdir) WORKDIR="$2"; shift 2;;
    --out) OUT_DIR="$2"; shift 2;;
    --server-id) SERVER_ID="$2"; shift 2;;
    --format) FORMAT="$2"; shift 2;;
    --fail) FAIL="$2"; shift 2;;
    --exclusions) EXCLUSIONS="$2"; shift 2;;
    --insecure-tls) INSECURE_TLS="true"; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1;;
  esac
done

if ! command -v jf >/dev/null 2>&1; then
  echo "jf CLI not found on PATH." >&2
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

output_extension() {
  case "$1" in
    table) echo "txt";;
    json|simple-json) echo "json";;
    sarif) echo "sarif";;
    cyclonedx) echo "cdx.json";;
    *) echo "txt";;
  esac
}

run_audit() {
  local label="$1" dir="$2"
  local ext outfile
  ext="$(output_extension "$FORMAT")"
  outfile="$OUT_DIR/${label}-petclinic-jfrog-audit.${ext}"

  local args=(audit --format "$FORMAT" --fail "$FAIL")
  if [[ -n "$SERVER_ID" ]]; then
    args+=(--server-id "$SERVER_ID")
  fi
  if [[ "$INSECURE_TLS" == "true" ]]; then
    args+=(--insecure-tls=true)
  fi
  if [[ -n "$EXCLUSIONS" ]]; then
    args+=(--exclusions "$EXCLUSIONS")
  fi

  log "Scanning $dir -> $outfile"
  (cd "$dir" && jf "${args[@]}") | tee "$outfile"
  log "Wrote $outfile"
}

OSS_DIR="$WORKDIR/oss-petclinic"
NES_DIR="$WORKDIR/nes-petclinic"

log "Using workdir $WORKDIR and output dir $OUT_DIR"
ensure_repo "$OSS_REPO" "$OSS_BRANCH" "$OSS_DIR"
ensure_repo "$NES_REPO" "$NES_BRANCH" "$NES_DIR"

# run_audit "oss" "$OSS_DIR"
run_audit "nes" "$NES_DIR"

log "Done. Reports in $OUT_DIR"
