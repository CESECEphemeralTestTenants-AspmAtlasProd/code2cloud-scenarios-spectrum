# Pipeline Setup

## Connector First Gate

Do not run Azure deployment workflows until the Defender for Cloud GitHub connector is activated for:

```text
GitHub org: CESECEphemeralTestTenants-AspmAtlasProd
Repo: code2cloud-scenarios
Tenant: be689950-2726-4042-9af2-2e821348b8f2
```

The connector should be created in Defender for Cloud > Environment settings > Add environment > GitHub. Prefer all-repository access for this dedicated lab org, or explicitly select `code2cloud-scenarios` if selected-repo access is required.

Record the connector scope before running Terraform:

```text
subscriptions/<subscription-id>/resourcegroups/<resource-group>/providers/Microsoft.Security/securityconnectors/<connector-name>
```

The workflows below are intentionally manual. Do not run `apply=true` until the connector is connected and the repo is visible or pending in Defender DevOps inventory.

## Required GitHub Environment Variables

Configure these on the `prod` GitHub environment:

```text
AZURE_CLIENT_ID=<entra-app-client-id>
AZURE_TENANT_ID=be689950-2726-4042-9af2-2e821348b8f2
AZURE_SUBSCRIPTION_ID=<target-subscription-id>
AZURE_LOCATION=eastus
RESOURCE_PREFIX=c2cprod
RESOURCE_GROUP_NAME=c2cprod-rg
ACR_NAME=c2cprodacr
AKS_CLUSTER_NAME=c2cprod-aks
K8S_NAMESPACE=c2c-scenarios
WORKFLOW_PRINCIPAL_OBJECT_ID=<service-principal-object-id>
```

These are variables, not secrets. The workflow uses OIDC and should not store an Azure client secret.

## Required Azure Roles

Bootstrap roles for the Entra app/service principal:

- `Contributor` on the target subscription during bootstrap, because Terraform creates the lab resource group.
- `User Access Administrator` on the target subscription if Terraform creates role assignments.

Runtime roles created by Terraform when `WORKFLOW_PRINCIPAL_OBJECT_ID` is set:

- `AcrPush` on ACR.
- `Azure Kubernetes Service Cluster User Role` on AKS.
- `Azure Kubernetes Service RBAC Writer` on AKS.

## Federated Credential Subjects

```text
repo:CESECEphemeralTestTenants-AspmAtlasProd/code2cloud-scenarios:environment:prod
repo:CESECEphemeralTestTenants-AspmAtlasProd/code2cloud-scenarios:ref:refs/heads/main
repo:CESECEphemeralTestTenants-AspmAtlasProd/code2cloud-scenarios:pull_request
```

Use the environment subject for workflows that declare `environment: prod`.

After the lab resources exist, reduce the workflow app scope to the lab resource group where possible.