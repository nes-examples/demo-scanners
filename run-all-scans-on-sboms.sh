#!/usr/bin/env bash
set -euo pipefail

# Run SBOM-aware scanners against one or more SBOM files (CycloneDX or SPDX).
usage() {
  cat <<'EOF'
Usage: ./run-all-scans-on-sboms.sh [--sbom <path>]... [--out <dir>] [--osv-config <path>] [--grype-config <path>] [--trivy-vex <path>] [--trivy-ignore <path>]

Defaults:
  --sbom        Defaults to oss/nes petclinic SBOMs in both CycloneDX and SPDX if present:
                oss-petclinic.sbom.cdx.json, nes-petclinic.sbom.cdx.json,
                oss-petclinic.sbom.spdx.json, nes-petclinic.sbom.spdx.json
  --out         ./sbom-scans
  OSV_FAIL_ON_ERROR=false (env) to keep going if osv-scanner cannot reach the API (e.g., offline)
  --grype-config   Grype config file (default: ./exclusions/grype-ignore.yaml if it exists; contains ignore rules)
  --trivy-vex      OpenVEX file for trivy (default: ./exclusions/openvex-not-affected.json if it exists)
  --trivy-ignore   Trivy ignore file (default: ./exclusions/trivy.ignore if it exists)
  --osv-config     TOML config for osv-scanner (default: ./exclusions/osv-scanner.toml if it exists)

Tools used (if installed):
  - grype:  grype sbom <file> -> JSON
  - trivy:  trivy sbom <file> -> JSON
  - osv-scanner: osv-scanner scan source --lockfile <file> [--config ...] -> text
JSON outputs are pretty-printed when jq is available on PATH.
EOF
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="$SCRIPT_DIR/sbom-scans"
OSV_CONFIG=""
GRYPE_CONFIG_FILE=""
TRIVY_VEX_FILE=""
TRIVY_IGNORE_FILE=""
SBOMS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sbom) SBOMS+=("$2"); shift 2;;
    --out) OUT_DIR="$2"; shift 2;;
    --osv-config) OSV_CONFIG="$2"; shift 2;;
    --grype-config) GRYPE_CONFIG_FILE="$2"; shift 2;;
    --trivy-ignore) TRIVY_IGNORE_FILE="$2"; shift 2;;
    --trivy-vex) TRIVY_VEX_FILE="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1;;
  esac
done

# Apply defaults for ignore/config files if not provided explicitly.
DEFAULT_OSV_CONFIG="$SCRIPT_DIR/exclusions/osv-scanner.toml"
DEFAULT_VEX="$SCRIPT_DIR/exclusions/openvex-not-affected.json"
DEFAULT_GRYPE_CONFIG="$SCRIPT_DIR/exclusions/grype-ignore.yaml"
DEFAULT_TRIVY_IGNORE="$SCRIPT_DIR/exclusions/trivy.ignore"

if [[ -z "$OSV_CONFIG" && -f "$DEFAULT_OSV_CONFIG" ]]; then
  OSV_CONFIG="$DEFAULT_OSV_CONFIG"
fi
if [[ -z "$GRYPE_CONFIG_FILE" && -f "$DEFAULT_GRYPE_CONFIG" ]]; then
  GRYPE_CONFIG_FILE="$DEFAULT_GRYPE_CONFIG"
fi
if [[ -z "$TRIVY_VEX_FILE" && -f "$DEFAULT_VEX" ]]; then
  TRIVY_VEX_FILE="$DEFAULT_VEX"
fi
if [[ -z "$TRIVY_IGNORE_FILE" && -f "$DEFAULT_TRIVY_IGNORE" ]]; then
  TRIVY_IGNORE_FILE="$DEFAULT_TRIVY_IGNORE"
fi

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

warn() {
  echo "[scan-sboms][WARN] $*" >&2
}

# Pretty-print JSON outputs when jq is present.
format_json() {
  local file="$1"
  local tmp="${file}.tmp"
  if ! command -v jq >/dev/null 2>&1; then
    log "jq not installed; leaving $file compact"
    return
  fi
  if jq . "$file" > "$tmp"; then
    mv "$tmp" "$file"
  else
    log "jq failed to format $file; leaving compact"
    rm -f "$tmp"
  fi
}

# Run grype against an SBOM, applying ignore rules if provided.
run_grype() {
  local sbom="$1" label="$2"
  local outfile="$OUT_DIR/${label}-grype.json"
  if ! command -v grype >/dev/null 2>&1; then
    log "grype not installed or not on PATH"
    exit 1
  fi
  log "grype sbom -> $outfile"
  # Build args so we can append ignore rules when present.
  local source="sbom:${sbom}"
  local args=("$source" --output json)
  if [[ -n "$GRYPE_CONFIG_FILE" ]]; then
    args+=(--config "$GRYPE_CONFIG_FILE")
  fi
  GRYPE_DB_AUTO_UPDATE=${GRYPE_DB_AUTO_UPDATE:-false} \
  GRYPE_CHECK_FOR_APP_UPDATE=${GRYPE_CHECK_FOR_APP_UPDATE:-false} \
    grype "${args[@]}" > "$outfile"
  format_json "$outfile"
}

# Run trivy against an SBOM, applying VEX if provided.
run_trivy() {
  local sbom="$1" label="$2"
  local outfile="$OUT_DIR/${label}-trivy.json"
  if ! command -v trivy >/dev/null 2>&1; then
    log "trivy not installed or not on PATH"
    exit 1
  fi
  log "trivy sbom -> $outfile"
  local args=(sbom "$sbom" --format json --output "$outfile")
  if [[ -n "$TRIVY_VEX_FILE" ]]; then
    args+=(--vex "$TRIVY_VEX_FILE")
  fi
  if [[ -n "$TRIVY_IGNORE_FILE" ]]; then
    args+=(--ignorefile "$TRIVY_IGNORE_FILE")
  fi
  trivy "${args[@]}"
  format_json "$outfile"
}

# Run osv-scanner against an SBOM, applying TOML config if provided.
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
