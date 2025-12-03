# Grype

Free, actively maintained scanner from Anchore. Can scan source trees, images, and SBOMs (CycloneDX/SPDX).

## Prerequisites

- Install [Grype](https://github.com/anchore/grype) CLI (`grype` on PATH).
- First run downloads a vulnerability DB (cached locally).

## Usage (Spring PetClinic OSS vs NES)

Run the helper script from this folder. It clones (or reuses cached clones) of both repos/branches you specify, runs `grype dir:<path>` on each clone, and writes JSON reports to `grype-output/`.

```bash
./run.sh
```

Defaults:
- OSS: `https://github.com/neverendingsupport/nes-spring-petclinic.git` branch `OSS`
- NES: `https://github.com/neverendingsupport/nes-spring-petclinic.git` branch `nes-2.7.x`
- Clones live under `<repo-root>/local-clones` (gitignored); override with `--workdir`.

Notes:
- Output files: `grype-output/oss-petclinic-grype.json` and `grype-output/nes-petclinic-grype.json`.
- To scan an SBOM instead, change the scan target to `sbom:<file>` inside the script.
