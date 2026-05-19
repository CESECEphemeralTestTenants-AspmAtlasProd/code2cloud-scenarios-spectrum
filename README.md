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
| Azure subscription ID | `abc9a611-db88-42cb-94cb-6869755a18e6` |
| Azure subscription name | `AspmAtlasProd-Subscription` |
| Default resource prefix | `c2cprod` |
| Kubernetes namespace | `c2c-scenarios` |

## What This Lab Creates

- Azure resource group, ACR, and AKS through Terraform.
- GitHub Actions OIDC authentication through an Entra ID app/service principal.
- Vulnerable Node.js workloads with `ajv@6.12.2` / `CVE-2020-15366`.
- Build, source scan, image scan, push, and AKS deploy workflows.
- A scale-lab workflow that can build up to 10 distinct image names and deploy a configurable number of runtime containers.
- Correlation metadata for repository -> workflow -> image -> AKS workload validation.

## Deployment Order

1. Activate the Defender for Cloud GitHub connector for `CESECEphemeralTestTenants-AspmAtlasProd/code2cloud-scenarios`.
2. Record the connector scope and wait for the repo to appear in Defender DevOps inventory, or confirm inventory refresh is pending.
3. A tenant/subscription admin runs [.azure/setup-azure-auth-for-pipeline.ps1](.azure/setup-azure-auth-for-pipeline.ps1).
4. The admin or workflow configures the `prod` GitHub environment variables described in [.azure/pipeline-setup.md](.azure/pipeline-setup.md).
5. Run `.github/workflows/c2c-scenario-infra.yml` with `apply=true`.
6. Run `.github/workflows/c2c-vuln-container-build.yml` with `deploy_to_aks=true`.
7. Optionally run `.github/workflows/c2c-scale-lab.yml` to create a stronger test shape.
8. Validate C2C Flow A, ACR/AKS findings, and the same CVE across Code, Build, Ship, and Runtime.

Current bootstrap status: the Defender connector is active, the repo/workflows are pushed, the `prod` environment has Azure OIDC variables configured, and the infra workflow has created ACR `c2cprodacr` plus AKS `c2cprod-aks`. App workflow run `26031620504` completed successfully on 2026-05-18: source scans, image scans, SARIF uploads, ACR pushes, and digest-pinned AKS deployment all succeeded. AKS is running `vuln-app` and `vuln-api` in namespace `c2c-scenarios`.

Current validation status: GitHub/Azure/ACR/AKS execution is proven for the Phase 1 teammate process. C2C/Defender ingestion still needs the asynchronous inventory/Synchronizer window, which can take up to 48 hours, before Flow A and end-to-end Code/Build/Ship/Runtime correlation can be claimed.

## Scale Lab

Use `C2C Scale Lab Build and Deploy` when the test needs more data volume than the baseline two-workload scenario. The workflow builds a catalog of creatively named images and deploys each as a separate AKS deployment with one container per pod.

Default single-repo run:

```text
image_count=10
containers_per_image=5
image_offset=0
deploy_to_aks=true
```

This creates 10 image names and requests 50 runtime containers in namespace `c2c-scenarios`.

For a three-repo org-level test with roughly 10 images and 50 containers total, shard the image catalog across repos:

```text
repo 1: image_offset=0, image_count=4, containers_per_image=5
repo 2: image_offset=4, image_count=3, containers_per_image=5
repo 3: image_offset=7, image_count=3, containers_per_image=5
```

The current catalog names are `nebula-ledger`, `quartz-gateway`, `ember-cache`, `saffron-api`, `cobalt-worker`, `opal-portal`, `atlas-broker`, `marble-events`, `cinder-cron`, and `verdant-sync`.

Detailed steps are in [docs/deployment-plan.md](docs/deployment-plan.md).
C2C Defender for Cloud vulnerable scenario lab for Prod ephemeral tenant
