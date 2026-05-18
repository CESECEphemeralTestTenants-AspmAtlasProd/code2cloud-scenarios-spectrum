# Code2Cloud Defender Scenarios - Prod Tenant Lab

This repository contains a reusable Microsoft Defender for Cloud Code-to-Cloud
scenario lab for the Prod ephemeral tenant.

The lab is intentionally vulnerable. Do not reuse these workloads outside an
isolated test subscription.

## Target Environment

| Setting | Value |
| --- | --- |
| GitHub org | `CESECEphemeralTestTenants-AspmAtlasProd` |
| Repo | `code2cloud-scenarios` |
| GitHub environment | `prod` |
| Azure tenant ID | `be689950-2726-4042-9af2-2e821348b8f2` |
| Azure subscription ID | Pending access/input |
| Default resource prefix | `c2cprod` |
| Kubernetes namespace | `c2c-scenarios` |

## What This Lab Creates

- Azure resource group, ACR, and AKS through Terraform.
- GitHub Actions OIDC authentication through an Entra ID app/service principal.
- Vulnerable Node.js workloads with `ajv@6.12.2` / `CVE-2020-15366`.
- Build, source scan, image scan, push, and AKS deploy workflows.
- Correlation metadata for repository -> workflow -> image -> AKS workload validation.

## Deployment Order

1. Activate the Defender for Cloud GitHub connector for `CESECEphemeralTestTenants-AspmAtlasProd/code2cloud-scenarios`.
2. Record the connector scope and wait for the repo to appear in Defender DevOps inventory, or confirm inventory refresh is pending.
3. A tenant/subscription admin runs [.azure/setup-azure-auth-for-pipeline.ps1](.azure/setup-azure-auth-for-pipeline.ps1).
4. The admin or workflow configures the `prod` GitHub environment variables described in [.azure/pipeline-setup.md](.azure/pipeline-setup.md).
5. Run `.github/workflows/c2c-scenario-infra.yml` with `apply=true`.
6. Run `.github/workflows/c2c-vuln-container-build.yml` with `deploy_to_aks=true`.
7. Validate C2C Flow A, ACR/AKS findings, and the same CVE across Code, Build, Ship, and Runtime.

Detailed steps are in [docs/deployment-plan.md](docs/deployment-plan.md).
C2C Defender for Cloud vulnerable scenario lab for Prod ephemeral tenant
