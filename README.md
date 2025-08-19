# Security Scanning for Spring PetClinic

This repository demonstrates how the [Spring PetClinic](https://github.com/spring-projects/spring-petclinic) application looks when analyzed through a security lens. It includes baseline SBOMs for two versions of the application: one built with the final OSS release of Spring Boot 2.7.x and one built with HeroDevs Never Ending Support (NES) for Spring as a drop-in replacement.

## Repository Structure

```yaml
demo-scanners/
├── oss-petclinic.sbom.cdx.json   # CycloneDX SBOM from the OSS Spring PetClinic
├── nes-petclinic.sbom.cdx.json   # CycloneDX SBOM with HeroDevs NES for Spring drop-in replacements
└── <scanner>/               # Individual scanner integrations

```

## Regenerating the SBOMs

### Source Code

To obtain the source code for Spring PetClinic we found the [last commit](https://github.com/spring-projects/spring-petclinic/tree/9ecdc1111e3da388a750ace41a125287d9620534) that Spring PetClinic was using Spring Boot 2.7.x. From there we upgraded to the latest Spring Boot version (2.7.18) and checked in the OSS code to [this branch](https://github.com/neverendingsupport/nes-spring-petclinic/tree/OSS). We then created [another branch](https://github.com/neverendingsupport/nes-spring-petclinic/tree/nes-2.7.x) and dropped in HeroDevs NES for Spring.

### SBOM Generation

The OSS and NES branches in the Spring PetClinic were then used to generate a CycloneDX SBOM in the JSON format. To generate an SBOM, reference the branches mentioned above and run the following command:

```bash
./mvnw org.cyclonedx:cyclonedx-maven-plugin:makeAggregateBom
```

This command will generate the SBOM files in the `target` directory. The files have been renamed to `oss-petclinic.sbom.json` and `nes-petclinic.sbom.json` respectively and are available in this repository.