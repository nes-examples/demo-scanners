# OWASP Dependency-Check

Free, actively maintained SCA tool from OWASP. Supports scanning source trees and CycloneDX SBOMs.

## Prerequisites

- Install [Dependency-Check](https://owasp.org/www-project-dependency-check/) CLI (`dependency-check` or `dependency-check.sh` on PATH).
- Java runtime for the analyzer.
- Internet access on first run to download the vulnerability database (cached afterward).

## Usage (Spring PetClinic OSS vs NES)

Run the helper script from this folder. It clones (or reuses cached clones) of both repos/branches you specify, runs Dependency-Check on each, and writes JSON reports to `dependency-check-output/`.

```bash
./run.sh
```

Defaults:
- OSS: `https://github.com/neverendingsupport/nes-spring-petclinic.git` branch `OSS`
- NES: `https://github.com/neverendingsupport/nes-spring-petclinic.git` branch `nes-2.7.x`
- Clones live under `<repo-root>/local-clones` (gitignored) so subsequent runs are faster; override with `--workdir`.

Key script notes:
- Adds `--failOnCVSS 0` so Dependency-Check never fails the script on findings.
- Output files: `dependency-check-output/oss-petclinic-dependency-check.json` and `dependency-check-output/nes-petclinic-dependency-check.json`.

To scan an SBOM instead of source, replace `--scan <path>` in the script call with `--scan <sbom-file>` and remove `--enableExperimental` if unused.
