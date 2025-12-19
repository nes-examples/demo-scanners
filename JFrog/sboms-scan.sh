#!/usr/bin/env bash
set -euo pipefail

# Enrich CycloneDX SBOMs via JFrog Xray.
usage() {
  cat <<'EOF'
Usage: ./JFrog/sboms-scan.sh [--sbom <path>]... [--out <dir>] [--server-id <id>] [--insecure-tls]

Defaults:
  --sbom   oss/nes petclinic CycloneDX SBOMs if present:
           oss-petclinic.sbom.cdx.json, nes-petclinic.sbom.cdx.json
  --out    ./JFrog/output

JFrog CLI command:
  jf sbom-enrich (alias: jf se)
EOF
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="$SCRIPT_DIR/output"
SERVER_ID=""
INSECURE_TLS="false"
SBOMS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sbom) SBOMS+=("$2"); shift 2;;
    --out) OUT_DIR="$2"; shift 2;;
    --server-id) SERVER_ID="$2"; shift 2;;
    --insecure-tls) INSECURE_TLS="true"; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1;;
  esac
done

if [[ ${#SBOMS[@]} -eq 0 ]]; then
  for candidate in \
    "$ROOT_DIR"/oss-petclinic.sbom.cdx.json \
    "$ROOT_DIR"/nes-petclinic.sbom.cdx.json; do
    [[ -f "$candidate" ]] && SBOMS+=("$candidate")
  done
fi

if [[ ${#SBOMS[@]} -eq 0 ]]; then
  echo "No CycloneDX SBOMs provided or found. Add --sbom <file> arguments." >&2
  exit 1
fi

if ! command -v jf >/dev/null 2>&1; then
  echo "jf CLI not installed or not on PATH" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

log() {
  echo "[jfrog-sbom-enrich] $*"
}

is_cyclonedx() {
  case "$1" in
    *.cdx.json|*.cdx.xml|*.cyclonedx.json|*.cyclonedx.xml) return 0;;
    *) return 1;;
  esac
}

for sbom in "${SBOMS[@]}"; do
  if [[ ! -f "$sbom" ]]; then
    echo "SBOM not found: $sbom" >&2
    exit 1
  fi
  if ! is_cyclonedx "$sbom"; then
    log "Skipping non-CycloneDX SBOM: $sbom"
    continue
  fi

  base="$(basename "$sbom")"
  label="${base%.*}"
  outfile="$OUT_DIR/${label}-jfrog-enriched.json"

  args=(sbom-enrich)
  if [[ -n "$SERVER_ID" ]]; then
    args+=(--server-id "$SERVER_ID")
  fi
  if [[ "$INSECURE_TLS" == "true" ]]; then
    args+=(--insecure-tls=true)
  fi
  args+=("$sbom")

  log "jf ${args[*]} -> $outfile"
  jf "${args[@]}" > "$outfile"
  if [[ ! -s "$outfile" ]]; then
    echo "Enriched SBOM output was not produced: $outfile" >&2
    exit 1
  fi
done
