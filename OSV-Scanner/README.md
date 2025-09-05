# OSV-Scanner

This section provides instructions on how to use [OSV-Scanner](https://github.com/google/osv-scanner) to check for vulnerabilities in the dependencies of the Spring PetClinic application.

## Installing OSV-Scanner

OSV-Scanner must be installed on your machine to properly use the tool.
See the [OSV-Scanner documentation](https://google.github.io/osv-scanner/installation/) for installation instructions.

[Binaries are available](https://github.com/google/osv-scanner/releases) for most platforms, as well as packages for [Homebrew](https://brew.sh/) on macOS and Linux and [Scoop](https://scoop.sh/) for Windows.

Test that the installation was successful by running:

```bash 
osv-scanner --version
```

> [!NOTE]
> The instructions in this document are for use with OSV-Scanner version 2.2.1 or greater. Command line arguments might be different for older versions.

## Scanning the SBOM Without Exclusions

To scan the SBOM for vulnerabilities, run the following commands:

```bash
osv-scanner scan source --lockfile=../oss-petclinic.sbom.cdx.json --output=oss-petclinic-output.txt
osv-scanner scan source --lockfile=../nes-petclinic.sbom.cdx.json --output=nes-petclinic-unfiltered-output.txt
```

The results produced above will show all vulnerabilities that OSV-Scanner identifies. 
OSV-Scanner does not inherently recognize HeroDevs packages, so some CVEs that have been remediated are mistakenly included in the output. 
These are false positives and should not be considered in the final security evaluation.

## Scanning the SBOM With Exclusions

OSV-Scanner has a [configuration option](https://google.github.io/osv-scanner/configuration/) to exclude certain vulnerabilities from the scan. 
This is useful when you want to ignore known vulnerabilities that have been remediated in the HeroDevs artifacts.

A configuration file named `osv-scanner.toml` has been provided. 
To run OSV-Scanner with the appropriate exclusions, run the following command from the `OSV-Scanner` directory:

```bash
osv-scanner scan source --lockfile=../nes-petclinic.sbom.cdx.json --output=nes-petclinic-output.txt --config=./osv-scanner.toml
```

> [!IMPORTANT]
> Only use the exclusion file on HeroDevs NES for Spring SBOMs. The exclusions are not applicable to OSS.

With this output, we can compare `nes-petclinic-output.txt` to `oss-petclinic-output.txt` to see the vulnerabilities that have been remediated in the HeroDevs NES for Spring artifacts.