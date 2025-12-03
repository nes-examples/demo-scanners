#!/usr/bin/env bash
set -euo pipefail

# Run SBOM-aware scanners against one or more SBOM files (CycloneDX or SPDX).
usage() {
  cat <<'EOF'
Usage: ./run-all-scans-on-sboms.sh [--sbom <path>]... [--out <dir>] [--osv-config <path>]

Defaults:
  --sbom        Defaults to oss/nes petclinic SBOMs in both CycloneDX and SPDX if present:
                oss-petclinic.sbom.cdx.json, nes-petclinic.sbom.cdx.json,
                oss-petclinic.sbom.spdx.json, nes-petclinic.sbom.spdx.json
  --out         ./sbom-scans
  OSV_FAIL_ON_ERROR=false (env) to keep going if osv-scanner cannot reach the API (e.g., offline)
  --osv-config  Optional TOML config for osv-scanner (e.g., exclusions for NES).

Tools used (if installed):
  - grype:  grype sbom <file> -> JSON
  - trivy:  trivy sbom <file> -> JSON
  - osv-scanner: osv-scanner scan source --lockfile <file> [--config ...] -> text
EOF
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="$SCRIPT_DIR/sbom-scans"
OSV_CONFIG=""
SBOMS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sbom) SBOMS+=("$2"); shift 2;;
    --out) OUT_DIR="$2"; shift 2;;
    --osv-config) OSV_CONFIG="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1;;
  esac
done

if [[ ${#SBOMS[@]} -eq 0 ]]; then
  for candidate in \
    "$SCRIPT_DIR"/oss-petclinic.sbom.cdx.json \
    "$SCRIPT_DIR"/nes-petclinic.sbom.cdx.json \
    "$SCRIPT_DIR"/oss-petclinic.sbom.spdx.json \
    "$SCRIPT_DIR"/nes-petclinic.sbom.spdx.json; do
    [[ -f "$candidate" ]] && SBOMS+=("$candidate")
  done
fi

if [[ ${#SBOMS[@]} -eq 0 ]]; then
  echo "No SBOMs provided or found. Add --sbom <file> arguments." >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

divider() {
  local name="$1"
  printf '\n======================================================================\n'
  printf "[scan-sboms] >> %s\n" "$name"
  printf "======================================================================\n"
}

log() {
  echo "[scan-sboms] $*"
}

run_grype() {
  local sbom="$1" label="$2"
  local outfile="$OUT_DIR/${label}-grype.json"
  if ! command -v grype >/dev/null 2>&1; then
    log "grype not installed or not on PATH"
    exit 1
  fi
  log "grype sbom -> $outfile"
  GRYPE_DB_AUTO_UPDATE=${GRYPE_DB_AUTO_UPDATE:-false} \
  GRYPE_CHECK_FOR_APP_UPDATE=${GRYPE_CHECK_FOR_APP_UPDATE:-false} \
    grype "sbom:${sbom}" --output json > "$outfile"
}

run_trivy() {
  local sbom="$1" label="$2"
  local outfile="$OUT_DIR/${label}-trivy.json"
  if ! command -v trivy >/dev/null 2>&1; then
    log "trivy not installed or not on PATH"
    exit 1
  fi
  log "trivy sbom -> $outfile"
  trivy sbom "$sbom" --format json --output "$outfile"
}

run_osv() {
  local sbom="$1" label="$2"
  local outfile="$OUT_DIR/${label}-osv.txt"
  # Use SBOM directly; no directory walk required.
  local fail_on_error="${OSV_FAIL_ON_ERROR:-false}"
  local args=(scan source
    --experimental-no-default-plugins
    --experimental-plugins sbom
    --sbom "$sbom"
    --output "$outfile"
    "$SCRIPT_DIR"
  )
  if [[ -n "$OSV_CONFIG" ]]; then
    args+=(--config "$OSV_CONFIG")
  fi
  if ! command -v osv-scanner >/dev/null 2>&1; then
    log "osv-scanner not installed or not on PATH"
    exit 1
  fi
  log "osv-scanner ${args[*]} -> $outfile"
  if ! osv-scanner "${args[@]}"; then
    if [[ "$fail_on_error" == "true" ]]; then
      exit 1
    fi
    log "osv-scanner failed (often due to restricted network). Set OSV_FAIL_ON_ERROR=true to fail fast."
  fi
}

for sbom in "${SBOMS[@]}"; do
  if [[ ! -f "$sbom" ]]; then
    echo "SBOM not found: $sbom" >&2
    exit 1
  fi
  base="$(basename "$sbom")"
  label="${base%.json}"
  divider "${base} :: grype"
  run_grype "$sbom" "$label"
  divider "${base} :: trivy"
  run_trivy "$sbom" "$label"
  divider "${base} :: osv"
  run_osv "$sbom" "$label"
done

log "Done. Outputs in $OUT_DIR"
