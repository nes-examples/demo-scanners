# OpenSSF Scorecard

Free, actively maintained supply-chain health scanner from OpenSSF. Provides heuristics (CI usage, branch protection, pinned deps, etc.). Not a vulnerability scanner but a useful complementary signal.

## Prerequisites

- Install [Scorecard](https://github.com/ossf/scorecard) CLI (`scorecard` on PATH).
- Network access required because Scorecard queries Git hosting metadata.

## Usage (Spring PetClinic OSS vs NES)

Run the helper script from this folder. It clones (or reuses cached clones) of both repos/branches you specify, runs Scorecard locally against each, and writes JSON reports to `scorecard-output/`.

```bash
./run.sh
```

Defaults:
- OSS: `https://github.com/neverendingsupport/nes-spring-petclinic.git` branch `OSS`
- NES: `https://github.com/neverendingsupport/nes-spring-petclinic.git` branch `nes-2.7.x`
- Clones live under `<repo-root>/local-clones` (gitignored); override with `--workdir`.

Notes:
- Output files: `scorecard-output/oss-petclinic-scorecard.json` and `scorecard-output/nes-petclinic-scorecard.json`.
