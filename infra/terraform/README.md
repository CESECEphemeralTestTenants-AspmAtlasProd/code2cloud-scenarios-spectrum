# Terraform Infrastructure

This module creates the Azure resources for the C2C Prod lab:

- Resource group.
- Azure Container Registry with anonymous pull disabled.
- AKS cluster with managed identity.
- ACR pull permission for AKS.
- Workflow app permissions for ACR push and AKS deploy.
- Optional Defender CSPM and Defender for Containers plans.

## Local Validation

Terraform is not required for normal operation because the GitHub Actions infra workflow runs it. For local validation:

```powershell
winget install Hashicorp.Terraform
terraform init
terraform validate
terraform plan
```

Do not apply locally unless your Azure CLI is set to the Prod tenant/subscription.