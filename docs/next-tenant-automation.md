# Next Tenant Automation Plan

This lab should become a repeatable workflow that a teammate can run for a fresh test tenant with a small set of parameters and one manual approval before creating Azure resources.

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

Target user experience for the next tenant:

1. Create or select a GitHub organization.
2. Create the Defender for Cloud GitHub connector and authorize the org with all-repository access.
3. Fill a parameter file or workflow form.
4. Run one bootstrap workflow/script.
5. Review the non-deploying Terraform plan.
6. Click approve/run `apply=true` to create ACR/AKS.
7. Run the vulnerable app workflow.
8. Wait for C2C ingestion and validate the same CVE across Code, Build, Ship, and Runtime.

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
  "defenderConnectorName": "<from portal>",
  "defenderConnectorResourceGroup": "<from portal>",
  "defenderConnectorScope": "subscriptions/<sub>/resourcegroups/<rg>/providers/Microsoft.Security/securityconnectors/<name>"
}
```

## Automation Building Blocks

### 1. Template Repository

Turn `code2cloud-scenarios` into a template repository for future tenants. The template contains:

- `.github/workflows/c2c-scenario-infra.yml`
- `.github/workflows/c2c-vuln-container-build.yml`
- `.github/workflows/codeql.yml`
- `.azure/setup-azure-auth-for-pipeline.ps1`
- `infra/terraform/*`
- `scenarios/*`
- `docs/*`

Tenant-specific values must come from workflow inputs or GitHub environment variables, not hardcoded files.

### 2. Bootstrap Script

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

### 3. Bootstrap Workflow

For the cleanest teammate experience, add a separate admin-only workflow, for example `.github/workflows/bootstrap-next-tenant.yml`, in an internal bootstrap/control repo.

This workflow would accept `workflow_dispatch` inputs matching the parameter contract, then run the bootstrap script. It should require a protected GitHub environment so only approved users can run tenant setup.

### 4. Approval Gates

Use two separate workflow runs:

- `apply=false`: always safe; validates credentials and Terraform plan.
- `apply=true`: creates Azure resources; require explicit approval.

Keep `enable_defender_plans=false` for validation. Enable it only when a tenant admin approves managing Defender plans as IaC.

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

The skill explains the process to Copilot/agents. The parameter file and bootstrap script make the process deterministic. The bootstrap workflow turns it into a click-driven team experience.

## Next Implementation Slice

Recommended next changes:

1. Add `.azure/tenant-lab.params.example.json`.
2. Refactor `.azure/setup-azure-auth-for-pipeline.ps1` to accept a parameter file.
3. Add repo creation/template seeding to the script.
4. Add a bootstrap workflow with protected-environment approval.
5. Add a validation script that checks GitHub variables, Azure RBAC, latest workflow run status, and C2C telemetry.