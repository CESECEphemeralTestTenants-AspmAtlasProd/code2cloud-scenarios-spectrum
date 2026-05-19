# Deployment Plan

This plan is the reusable procedure for the C2C Prod tenant lab.

## Current State

- GitHub repo exists: `CESECEphemeralTestTenants-AspmAtlasProd/code2cloud-scenarios`.
- GitHub environment exists: `prod`.
- `AZURE_TENANT_ID` is configured as `be689950-2726-4042-9af2-2e821348b8f2`.
- Defender for Cloud GitHub connector is created and authorized for all repositories in `CESECEphemeralTestTenants-AspmAtlasProd`.
- Azure subscription is `AspmAtlasProd-Subscription` / `abc9a611-db88-42cb-94cb-6869755a18e6`.
- Entra app `c2c-prod-github-actions` and GitHub Actions OIDC bootstrap are configured.
- Infra workflow run `26026137641` completed successfully and created ACR `c2cprodacr` plus AKS `c2cprod-aks`.
- App workflow run `26031620504` completed successfully after connector activation and deployed both vulnerable workloads to AKS by digest.
- C2C/Defender ingestion validation is still pending the asynchronous inventory/Synchronizer window.

## Gate 0 - Activate Defender GitHub Connector

Create or verify the Defender for Cloud GitHub connector before deploying Azure lab resources.

Connector target:

```text
Azure tenant: be689950-2726-4042-9af2-2e821348b8f2
GitHub org: CESECEphemeralTestTenants-AspmAtlasProd
GitHub repo: code2cloud-scenarios
Recommended connector name: c2c-prod-gh
Recommended connector resource group: c2cprod-security-rg
Recommended region: eastus
```

Portal flow:

1. Open Azure portal in tenant `be689950-2726-4042-9af2-2e821348b8f2`.
2. Go to Microsoft Defender for Cloud > Environment settings.
3. Select Add environment > GitHub.
4. Choose the target subscription, resource group, and region.
5. Authorize GitHub with an account that is owner/admin for `CESECEphemeralTestTenants-AspmAtlasProd`.
6. Install or verify the Defender for Cloud GitHub app on `CESECEphemeralTestTenants-AspmAtlasProd`.
7. Prefer all-repository access for this dedicated lab org. If selected repositories are required, explicitly select `code2cloud-scenarios`.
8. Create the connector and record the connector scope.

Do not continue until the repo appears in Defender DevOps inventory, or until the connector shows the org/repo is selected and inventory refresh is pending.

Record these values in the bootstrap issue:

```text
defender_connector_name=<name>
defender_connector_resource_group=<resource-group>
defender_connector_region=<region>
defender_connector_scope=subscriptions/<subscription-id>/resourcegroups/<resource-group>/providers/Microsoft.Security/securityconnectors/<connector-name>
github_app_access=all-repos | selected-repos:code2cloud-scenarios
connector_created_at=<timestamp>
```

If the org is greyed out or unavailable during connector setup, check whether the GitHub org is already onboarded to another connector in the same Azure tenant.

## Step 1 - Tenant And Subscription Access

The operator must be able to run:

```powershell
az login --tenant be689950-2726-4042-9af2-2e821348b8f2
az account list --all --query "[?tenantId=='be689950-2726-4042-9af2-2e821348b8f2']"
```

Capture the target subscription ID and choose a region supported by Defender DevOps security, for example `eastus`.

Captured Prod subscription:

```text
subscription_name=AspmAtlasProd-Subscription
subscription_id=abc9a611-db88-42cb-94cb-6869755a18e6
```

## Step 2 - Verify Connector Discovery Before Infra

Wait for Defender DevOps inventory to discover the repo. Microsoft docs say inventory can take up to 8 hours.

Expected portal checks:

- Defender for Cloud > Environment settings shows the GitHub connector as connected.
- Defender DevOps inventory includes `CESECEphemeralTestTenants-AspmAtlasProd/code2cloud-scenarios`.
- The connector access settings include the target org and repo.

When C2C telemetry is available after the Synchronizer cycle, use the Kusto starter query in Step 7 to verify `VcsScanner` sees this org/repo. If Defender inventory shows the repo but `VcsScanner` stays empty after the expected cycle, treat it as a connector/Synchronizer issue before deploying more infrastructure.

## Step 3 - Bootstrap Entra App And RBAC

Run the setup script as an admin with rights to create app registrations, service principals, federated credentials, and role assignments:

```powershell
.\.azure\setup-azure-auth-for-pipeline.ps1 `
  -TenantId be689950-2726-4042-9af2-2e821348b8f2 `
  -SubscriptionId <subscription-id> `
  -ResourceGroupName c2cprod-rg `
  -Location eastus `
  -ResourcePrefix c2cprod `
  -AssignUserAccessAdministrator
```

The script creates or reuses an Entra app named `c2c-prod-github-actions`, configures GitHub OIDC federated credentials, assigns temporary subscription-scoped bootstrap RBAC, and stores GitHub environment variables.

## Step 4 - Run Infrastructure Workflow

Run `C2C Scenario Infrastructure` from GitHub Actions with:

```text
apply=true
resource_prefix=c2cprod
location=eastus
```

This runs Terraform from `infra/terraform` and creates ACR/AKS plus role assignments needed by the workflow app.

After apply succeeds, reduce the workflow app RBAC to the lab resource group where possible.

## Step 5 - Run Vulnerable App Workflow

Run `C2C Vulnerable Container Build and Deploy` with `deploy_to_aks=true`.

The workflow builds two images, scans source and images, pushes to ACR, captures digests, and deploys by digest to AKS.

## Step 5b - Optional Scale Lab Workflow

Run `C2C Scale Lab Build and Deploy` when the environment needs stronger signal volume than the baseline two-workload scenario.

Default single-repo scale target:

```text
image_count=10
containers_per_image=5
image_offset=0
deploy_to_aks=true
```

This builds and pushes 10 distinct image repositories under the configured ACR prefix, then deploys 10 AKS deployments with 5 replicas each for about 50 runtime containers. Workload names are intentionally distinct so Defender, Resource Graph, and C2C correlation checks are easier to scan:

```text
nebula-ledger
quartz-gateway
ember-cache
saffron-api
cobalt-worker
opal-portal
atlas-broker
marble-events
cinder-cron
verdant-sync
```

For the org-level target of 3 repos, about 10 images, and about 50 containers total, shard the catalog across repos instead of creating 30 images:

```text
repo 1: image_offset=0, image_count=4, containers_per_image=5
repo 2: image_offset=4, image_count=3, containers_per_image=5
repo 3: image_offset=7, image_count=3, containers_per_image=5
```

Each repo should keep the same Azure environment variables if sharing the same ACR/AKS lab, but each repo still needs its own GitHub OIDC federated credential subject and should be included in the Defender GitHub connector scope.

## Step 6 - Validation

Validation captured on 2026-05-18:

```text
app_workflow_run=https://github.com/CESECEphemeralTestTenants-AspmAtlasProd/code2cloud-scenarios/actions/runs/26031620504
commit=04fd6c35aaf766af26128ac1019f32af026f1e28
vuln_app_digest=c2cprodacr.azurecr.io/c2cprod/vuln-app@sha256:feaff8a7b59ddaca3be31aa9ac49b275cfc297fba85553dcd9e5206c22d6331c
vuln_api_digest=c2cprodacr.azurecr.io/c2cprod/vuln-api@sha256:e3c1f098ad98e7f5e26e8a968729b738c538631eebaf2e32ee412ba227149c62
aks_namespace=c2c-scenarios
aks_deployments=vuln-app 1/1, vuln-api 1/1
```

Direct Azure validation showed ACR repositories `c2cprod/vuln-app` and `c2cprod/vuln-api` with `latest`, `run-26031620504`, commit, and CVE tags. Direct AKS validation showed both deployments available `1/1` and pods running with zero restarts.

Immediate C2C telemetry check did not yet show Prod `EyalGithubConnector` or `CESECEphemeralTestTenants-AspmAtlasProd` repo activity. This is expected while ingestion is fresh; Flow A telemetry can take up to 48 hours after connector activation/repo discovery. Rows for `morad-prsnl-gh-conn` are unrelated older Prod connector activity from a connector created earlier. Wait for Defender DevOps inventory and Synchronizer before treating this as a C2C failure.

Immediate GitHub code scanning check showed open Trivy alerts for `CVE-2020-15366` / `ajv` and `CVE-2020-8203` / `lodash` under `container-scanning-vuln-api`. User-reported GitHub Dependabot UI counts on 2026-05-18 show open source dependency evidence: `ajv` = 4 alerts, `lodash` = 6 alerts, `CVE-2020-15366` = 2 alerts, and `CVE-2020-8203` = 1 alert. Code-phase source evidence is now observed in the GitHub UI; Defender/C2C ingestion remains pending.

Runtime container validation on 2026-05-19: Defender Resource Graph shows unhealthy Kubernetes container recommendations for the target CVEs on the running AKS workloads. `Update ajv` is present on `vuln-app` and `vuln-api`; `Update lodash` is present on `vuln-api`. These records reference namespace `c2c-scenarios` and the exact digest-pinned image URIs deployed by workflow run `26031620504`. Runtime container vulnerability evidence is now observed; C2C Flow A mapping/correlation remains pending.

Validate in this order:

1. GitHub repo appears in Defender DevOps inventory.
2. `VcsScanner` sees this repo after Synchronizer emits Flow A.
3. `BuildLogCollector` collects infra and app workflow logs.
4. `TerraformExtractorWorker` writes `RepositoryToResourceMapping` rows.
5. `ContainerImageV2ExtractorWorker` writes `DockerFilePathToImageMapping` rows.
6. Defender for Containers reports `CVE-2020-15366` on ACR image digests.
7. AKS workloads run the same vulnerable image digests.
8. Portal shows or explains Code, Build, Ship, and Runtime phase state.

Starter Kusto query:

```kql
Span
| where TIMESTAMP > ago(7d)
| where env_name in ('VcsScanner','BuildLogCollector','TerraformExtractorWorker','ContainerImageV2ExtractorWorker','IaCExtractor','IntelligentMapper')
| where customData has 'CESECEphemeralTestTenants-AspmAtlasProd'
    or customData has 'code2cloud-scenarios'
    or customData has 'c2cprod'
| summarize total=count(), failures=countif(success == false), last=max(TIMESTAMP) by env_name, name
| order by env_name asc, name asc
```

## Step 7 - Teardown

Use Terraform destroy or delete the resource group only after capturing:

- Connector scope.
- Workflow run IDs.
- Image digests.
- AKS deployment names.
- Kusto validation output.

Do not delete the Defender connector while debugging ingestion unless that is intentional.