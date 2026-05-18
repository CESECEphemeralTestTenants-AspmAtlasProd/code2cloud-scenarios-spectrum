# Deployment Plan

This plan is the reusable procedure for the C2C Prod tenant lab.

## Current State

- GitHub repo exists: `CESECEphemeralTestTenants-AspmAtlasProd/code2cloud-scenarios`.
- GitHub environment exists: `prod`.
- `AZURE_TENANT_ID` is configured as `be689950-2726-4042-9af2-2e821348b8f2`.
- Azure deployment is paused until the Defender for Cloud GitHub connector is activated and verified for this org/repo.
- No Azure resource deployment should run before connector activation is complete.

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

## Step 6 - Validation

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