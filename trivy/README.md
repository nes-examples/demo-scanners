# Trivy Scanner

This section provides and overview on using the [Trivy scanner](https://github.com/aquasecurity/trivy) by Aqua Security to check for vulnerabilities in the Spring PetClinic application.

## Setup

For this tutorial, follow the [Getting Started guide](https://trivy.dev/latest/getting-started/) for installing trivy on your machine. 

```bash
brew install trivy
```

Check the version. Note that this guide is using version Trviy version 0.65.0.

```bash
trivy --version
```

## Scanning the SBOM Without Exclusions

To scan the SBOM for vulnerabilities, run the following commands:

```bash
trivy sbom oss-petclinic.sbom.cdx.json --output trivy/oss-petclinic-output.txt
trivy sbom nes-petclinic.sbom.cdx.json --output trivy/nes-petclinic-unfiltered-output.txt
```

The results produced in the above output will show all vulnerabilities that Trivy identifies. Trivy does not inherently recognize HeroDevs packages, so some CVEs that have been remediated are mistakenly included in the output. These are false positives and should not be considered in the final security evaluation.

## Scanning the SBOM With Vex Statements

Note, at the time of this writing, Trivy's current support (version 0.65.0) of Vex is experimental. This demo will utilize the [OpenVEX](https://github.com/openvex/spec) format for VEX statements.

A series of Vex statements have been added to capture the CVE patches by HeroDevs in the `herodevs-vex.json` file.

```bash
trivy sbom nes-petclinic.sbom.cdx.json --vex trivy/herodevs-vex.json --output trivy/nes-petclinic-output.txt
```

> [!IMPORTANT]
> Only use the Vex files on HeroDevs NES for Spring SBOMs. The exclusions are not applicable to OSS versions.


With this output, we can compare `nes-petclinic-output.txt` to `oss-petclinic-output.txt` to see the vulnerabilities that have been remediated in the HeroDevs NES for Spring artifacts.

## Scanning the SBOM With Trivy Exclusions

_To do..._
