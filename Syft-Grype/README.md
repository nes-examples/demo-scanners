# Syft + Grype

Syft (SBOM generator) and Grype (vulnerability scanner) are free and actively maintained by Anchore. This pairing lets you regenerate SBOMs locally and scan them with the same vulnerability data.

## Prerequisites

- Install [Syft](https://github.com/anchore/syft) CLI (`syft` on PATH).
- Install [Grype](https://github.com/anchore/grype) CLI (`grype` on PATH).
- First run of each downloads a cache (kept locally).

## Usage (Spring PetClinic OSS vs NES)

Run the helper script from this folder. It clones (or reuses cached clones) of both repos/branches you specify, builds CycloneDX JSON SBOMs with Syft, scans them with Grype, and writes outputs to `syft-grype-output/`.

```bash
./run.sh
```

Defaults:
- OSS: `https://github.com/neverendingsupport/nes-spring-petclinic.git` branch `OSS`
- NES: `https://github.com/neverendingsupport/nes-spring-petclinic.git` branch `nes-2.7.x`
- Clones live under `<repo-root>/local-clones` (gitignored); override with `--workdir`.

Notes:
- SBOMs: `syft-grype-output/oss-petclinic-sbom.cdx.json` and `syft-grype-output/nes-petclinic-sbom.cdx.json`.
- Scan results: `syft-grype-output/oss-petclinic-grype.json` and `syft-grype-output/nes-petclinic-grype.json`.
