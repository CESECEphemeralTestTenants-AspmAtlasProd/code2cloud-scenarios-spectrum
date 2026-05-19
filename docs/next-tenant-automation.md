# Next Tenant Automation Plan

This lab should become a repeatable workflow that a teammate can run for a fresh test tenant with a small set of parameters and one manual approval before creating Azure resources.

Current team decision: the first shareable version should be a VS Code skill plus checked-in scripts/templates. The skill runs locally under the teammate's own `gh` and `az` authentication because the GitHub organization/repository access is controlled by the teammate's personal GitHub account. Azure DevOps remains useful for storing/reviewing the shared assets, but should not be the primary bootstrap runner until the team introduces a GitHub service account or GitHub App with the required org/repo permissions.

## Current Credential Model

The GitHub workflow does not use an Azure client secret. It uses GitHub OIDC.

Stored on GitHub as `prod` environment variables:

```text
AZURE_CLIENT_ID=54979d89-dad3-4867-bdc7-3e4b7253529f
AZURE_TENANT_ID=be689950-2726-4042-9af2-2e821348b8f2
AZURE_SUBSCRIPTION_ID=abc9a611-db88-42cb-94cb-6869755a18e6
AZURE_LOCATION=eastus
RESOURCE_PREFIX=c2cprod
RESOURCE_GROUP_NAME=c2cprod-rg
ACR_NAME=c2cprodacr
AKS_CLUSTER_NAME=c2cprod-aks
K8S_NAMESPACE=c2c-scenarios
WORKFLOW_PRINCIPAL_OBJECT_ID=467e5902-5dd5-446b-9c54-9dfa0676fe59
```

No GitHub environment secrets are required for Azure login. That is intentional: Azure trusts GitHub's signed OIDC token through Entra federated credentials.

## What Should Be One-Click

Reference validation from the Prod lab: on 2026-05-18, app workflow run `26031620504` succeeded under the local-auth model after connector activation. It validated repo workflow dispatch, GitHub SARIF uploads, Azure OIDC login, ACR push, image scan, and AKS deploy. This is strong evidence for sharing the Phase 1 VS Code skill/runbook with teammates once C2C ingestion is validated and the assets are reviewed.

Target user experience for the next tenant:

1. Create or select a GitHub organization.
2. Create the Defender for Cloud GitHub connector and authorize the org with all-repository access.
3. Fill a parameter file or workflow form.
4. Invoke the local VS Code skill or run one bootstrap script from the checked-out repo.
5. Review the non-deploying Terraform plan.
6. Click approve/run `apply=true` to create ACR/AKS.
7. Run the vulnerable app workflow.
8. Optionally run the scale workflow with the requested repo/image/container counts.
9. Wait for C2C ingestion and validate the same CVE across Code, Build, Ship, and Runtime.

## Parameter Contract

Use one JSON/YAML parameter file per tenant:

```json
{
  "tenantLabel": "prod",
  "azureTenantId": "be689950-2726-4042-9af2-2e821348b8f2",
  "azureSubscriptionId": "abc9a611-db88-42cb-94cb-6869755a18e6",
  "azureSubscriptionName": "AspmAtlasProd-Subscription",
  "azureLocation": "eastus",
  "githubOrg": "CESECEphemeralTestTenants-AspmAtlasProd",
  "githubRepo": "code2cloud-scenarios",
  "githubEnvironment": "prod",
  "resourcePrefix": "c2cprod",
  "scaleRepoCount": 1,
  "scaleImageCount": 10,
  "scaleContainersPerImage": 5,
  "defenderConnectorName": "<from portal>",
  "defenderConnectorResourceGroup": "<from portal>",
  "defenderConnectorScope": "subscriptions/<sub>/resourcegroups/<rg>/providers/Microsoft.Security/securityconnectors/<name>"
}
```

For a stronger shared test environment, the automation should accept count knobs instead of forcing one fixed lab shape:

| Parameter | Purpose | Suggested default |
| --- | --- | --- |
| `scaleRepoCount` | Number of GitHub repos to create or seed under the org | `1` |
| `scaleImageCount` | Total distinct images to build across those repos | `10` |
| `scaleContainersPerImage` | AKS replicas per image | `5` |

For the current CESEC Prod scale test target, use 3 repos, about 10 images, and about 50 containers total. With the checked-in scale workflow, shard the 10-image catalog as `4 + 3 + 3` across the three repos using `image_offset` and `image_count` workflow inputs.

## Automation Building Blocks

### 1. Template Repository

Turn `code2cloud-scenarios` into a template repository for future tenants. The template contains:

- `.github/workflows/c2c-scenario-infra.yml`
- `.github/workflows/c2c-vuln-container-build.yml`
- `.github/workflows/c2c-scale-lab.yml`
- `.github/workflows/codeql.yml`
- `.azure/setup-azure-auth-for-pipeline.ps1`
- `infra/terraform/*`
- `scenarios/*`
- `docs/*`

Tenant-specific values must come from workflow inputs or GitHub environment variables, not hardcoded files.

### 2. Local VS Code Skill And Bootstrap Script

The primary teammate entry point should be the repo skill:

```text
.github/skills/c2c-test-tenant-bootstrap/SKILL.md
```

The skill should guide the teammate through the flow while using their local authenticated tools:

- `gh` for personal GitHub organization/repository operations.
- `az` for Azure tenant/subscription operations.
- `terraform` and GitHub Actions for repeatable infra execution.

This avoids requiring an Azure DevOps pipeline identity to have admin access to a personal GitHub organization.

### 3. Bootstrap Script

Extend `.azure/setup-azure-auth-for-pipeline.ps1` into a full orchestrator that can:

- Verify `gh` auth and repo admin permission.
- Verify `az` auth and target subscription access.
- Create GitHub repo from template if missing.
- Create GitHub environment.
- Enable vulnerability alerts and Dependabot security updates.
- Create/reuse Entra app and service principal.
- Create/reuse federated credentials for environment, main branch, and pull request.
- Assign bootstrap RBAC.
- Set GitHub environment variables.
- Trigger `apply=false` infra validation.

### 4. Optional Bootstrap Workflow

For a later team-owned model, add a separate admin-only workflow, for example `.github/workflows/bootstrap-next-tenant.yml`, in an internal bootstrap/control repo.

This workflow would accept `workflow_dispatch` inputs matching the parameter contract, then run the bootstrap script. It should require a protected GitHub environment so only approved users can run tenant setup. Do this only after the team has a GitHub service account, GitHub App, or other approved identity that can administer the target GitHub org/repo.

### 5. Approval Gates

Use two separate workflow runs:

- `apply=false`: always safe; validates credentials and Terraform plan.
- `apply=true`: creates Azure resources; require explicit approval.

Keep `enable_defender_plans=false` for validation. Enable it only when a tenant admin approves managing Defender plans as IaC.

The vulnerable app build/deploy workflow remains gated on Defender for Cloud connector setup. Azure infra can be created earlier when explicitly approved, but do not run the app workflow until the connector is connected and the repo is in scope or pending inventory refresh.

## What Cannot Be Fully Automated Yet

The Defender for Cloud GitHub connector authorization is the hardest part to make fully one-click because it includes GitHub app authorization and organization consent.

Recommended split:

- Manual once per test org/tenant: create Defender GitHub connector and authorize all repos.
- Automated after that: repo seeding, OIDC, RBAC, GitHub environment variables, Terraform validation, infra deployment, app deployment, and telemetry validation.

If a supported ARM/Bicep/Terraform/API route for GitHub connector creation plus app authorization is available and approved, add it later as a preflight step. Until then, keep connector creation as Gate 0.

## Proposed Team-Shareable Assets

Create these assets for teammates:

```text
.github/skills/c2c-test-tenant-bootstrap/SKILL.md
docs/next-tenant-automation.md
.azure/tenant-lab.params.example.json
.azure/bootstrap-c2c-lab.ps1
.github/workflows/bootstrap-next-tenant.yml
```

The skill explains and orchestrates the local process for Copilot/agents. The parameter file and bootstrap script make the process deterministic. The bootstrap workflow is a future upgrade after the team solves the GitHub identity/trust boundary.

## Distribution Plan

Phase 1 should live directly in the Azure DevOps repo as normal reviewed source:

- Skill file.
- Bootstrap scripts.
- Terraform/workflow templates.
- Parameter examples.
- Validation queries and runbook docs.

Phase 2 is a lightweight local installer, not a central pipeline. It should copy or link the skill into the expected local agent/VS Code location if needed, validate prerequisites (`gh`, `az`, `terraform`), and generate a starter parameter file for the teammate.

APM (`microsoft/apm`) is a future packaging upgrade. Use it when the skill stabilizes and the team wants manifest/lockfile-based distribution, audit, and cross-agent portability. Do not make APM a blocker for the first shared version.

## Next Implementation Slice

Recommended next changes:

1. Refactor `.azure/setup-azure-auth-for-pipeline.ps1` to accept a parameter file.
2. Add repo creation/template seeding to the script.
3. Add a lightweight local installer for the VS Code skill.
4. Add a validation script that checks GitHub variables, Azure RBAC, latest workflow run status, and C2C telemetry.
5. Add an optional bootstrap workflow only after a team-owned GitHub automation identity exists.