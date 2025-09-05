# Trivy Scanner

This section provides and overview on using the [Trivy scanner](https://github.com/aquasecurity/trivy) by Aqua Security to check for vulnerabilities in the Spring PetClinic application.

## Setup

For this tutorial, follow the [Getting Started guide](https://trivy.dev/latest/getting-started/) for installing trivy on your machine.
Check the version.

```bash
trivy --version
```

> [!NOTE]
> The instructions in this document are for use with Trivy version 0.65.0.or greater. Command line arguments might be different for older versions.


## Scanning the SBOM Without Exclusions

To scan the SBOM for vulnerabilities, run the following commands:

```bash
trivy sbom ../oss-petclinic.sbom.cdx.json --output oss-petclinic-output.txt
trivy sbom ../nes-petclinic.sbom.cdx.json --output nes-petclinic-unfiltered-output.txt
```

The results produced in the above output will show all vulnerabilities that Trivy identifies. 
Trivy does not inherently recognize HeroDevs packages, so some CVEs that have been remediated are mistakenly included in the output. 
These are false positives and should not be considered in the final security evaluation.

## Scanning the SBOM With Vex Statements

> [!NOTE]
> At the time of this writing, Trivy's current support (version 0.65.0) of Vex is experimental. This demo will use the [OpenVEX](https://github.com/openvex/spec) format for VEX statements.

A series of Vex statements have been added to capture the CVE patches by HeroDevs in the `herodevs-vex.json` file.

```bash
trivy sbom ../nes-petclinic.sbom.cdx.json --vex herodevs-vex.json --output nes-petclinic-output.txt
```

> [!IMPORTANT]
> Only use the Vex files on HeroDevs NES for Spring SBOMs. The exclusions are not applicable to OSS versions.


With this output, we can compare `nes-petclinic-output.txt` to `oss-petclinic-output.txt` to see the vulnerabilities that have been remediated in the HeroDevs NES for Spring artifacts.

## Scanning the SBOM With Trivy Exclusions

It's possible to [filter results](https://trivy.dev/v0.48/docs/configuration/filtering/) during a Trivy scan; for example:

```bash
trivy sbom ../nes-petclinic.sbom.cdx.json --ignorefile ./.trivyignore.yaml --output nes-petclinic-output.txt
```

The output will be strictly the same as the previous example with Vex statements.

> [!NOTE]
> While the result is similar, we believe the Vex statements to be preferable for a vendor to share fixed vulnerabilities with their customers.
> Filtering / exclusions could be a good fit for local policy-based suppressions.