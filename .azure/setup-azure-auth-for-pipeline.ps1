param(
    [Parameter(Mandatory = $true)] [string] $TenantId,
    [Parameter(Mandatory = $true)] [string] $SubscriptionId,
    [string] $Location = "eastus",
    [string] $ResourcePrefix = "c2cprod",
    [string] $ResourceGroupName = "c2cprod-rg",
    [string] $AppDisplayName = "c2c-prod-github-actions",
    [string] $GitHubRepo = "CESECEphemeralTestTenants-AspmAtlasProd/code2cloud-scenarios",
    [string] $GitHubEnvironment = "prod",
    [switch] $SkipLogin,
    [switch] $AssignUserAccessAdministrator
)

$ErrorActionPreference = "Stop"

function ConvertFrom-AzJson($ScriptBlock) {
    $result = & $ScriptBlock
    if (-not $result) { return $null }
    return $result | ConvertFrom-Json
}

if (-not $SkipLogin) {
    Write-Host "Logging in to tenant $TenantId"
    az login --tenant $TenantId --allow-no-subscriptions | Out-Null
}

az account set --subscription $SubscriptionId

$app = ConvertFrom-AzJson { az ad app list --display-name $AppDisplayName --query "[0]" -o json }
if (-not $app) {
    Write-Host "Creating app registration $AppDisplayName"
    $app = ConvertFrom-AzJson { az ad app create --display-name $AppDisplayName --sign-in-audience AzureADMyOrg -o json }
}

$clientId = $app.appId
$appObjectId = $app.id

$sp = ConvertFrom-AzJson { az ad sp list --filter "appId eq '$clientId'" --query "[0]" -o json }
if (-not $sp) {
    Write-Host "Creating service principal for $AppDisplayName"
    $sp = ConvertFrom-AzJson { az ad sp create --id $clientId -o json }
}

$spObjectId = $sp.id

function Ensure-FederatedCredential($Name, $Subject) {
    $credentials = ConvertFrom-AzJson { az ad app federated-credential list --id $clientId -o json }
    $existing = $credentials | Where-Object { $_.name -eq $Name } | Select-Object -First 1
    if ($existing) {
        Write-Host "Federated credential $Name already exists"
        return
    }

    $parameters = @{
        name = $Name
        issuer = "https://token.actions.githubusercontent.com"
        subject = $Subject
        audiences = @("api://AzureADTokenExchange")
    } | ConvertTo-Json -Depth 5

    $tempFile = New-TemporaryFile
    Set-Content -Path $tempFile -Value $parameters -Encoding utf8
    try {
        Write-Host "Creating federated credential $Name"
        az ad app federated-credential create --id $clientId --parameters "@$tempFile" | Out-Null
    }
    finally {
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    }
}

Ensure-FederatedCredential `
    -Name "github-prod-environment" `
    -Subject "repo:$GitHubRepo`:environment:$GitHubEnvironment"

Ensure-FederatedCredential `
    -Name "github-main-branch" `
    -Subject "repo:$GitHubRepo`:ref:refs/heads/main"

Ensure-FederatedCredential `
    -Name "github-pull-request" `
    -Subject "repo:$GitHubRepo`:pull_request"

$scope = "/subscriptions/$SubscriptionId"

Write-Host "Assigning Contributor on $scope"
az role assignment create `
    --assignee-object-id $spObjectId `
    --assignee-principal-type ServicePrincipal `
    --role Contributor `
    --scope $scope | Out-Null

if ($AssignUserAccessAdministrator) {
    Write-Host "Assigning User Access Administrator on $scope"
    az role assignment create `
        --assignee-object-id $spObjectId `
        --assignee-principal-type ServicePrincipal `
        --role "User Access Administrator" `
        --scope $scope | Out-Null
}

Write-Host "Setting GitHub environment variables"
gh variable set AZURE_CLIENT_ID --repo $GitHubRepo --env $GitHubEnvironment --body $clientId
gh variable set AZURE_TENANT_ID --repo $GitHubRepo --env $GitHubEnvironment --body $TenantId
gh variable set AZURE_SUBSCRIPTION_ID --repo $GitHubRepo --env $GitHubEnvironment --body $SubscriptionId
gh variable set AZURE_LOCATION --repo $GitHubRepo --env $GitHubEnvironment --body $Location
gh variable set RESOURCE_PREFIX --repo $GitHubRepo --env $GitHubEnvironment --body $ResourcePrefix
gh variable set RESOURCE_GROUP_NAME --repo $GitHubRepo --env $GitHubEnvironment --body $ResourceGroupName
gh variable set ACR_NAME --repo $GitHubRepo --env $GitHubEnvironment --body "$($ResourcePrefix)acr"
gh variable set AKS_CLUSTER_NAME --repo $GitHubRepo --env $GitHubEnvironment --body "$($ResourcePrefix)-aks"
gh variable set K8S_NAMESPACE --repo $GitHubRepo --env $GitHubEnvironment --body "c2c-scenarios"
gh variable set WORKFLOW_PRINCIPAL_OBJECT_ID --repo $GitHubRepo --env $GitHubEnvironment --body $spObjectId

Write-Host "Bootstrap complete"
Write-Host "AZURE_CLIENT_ID=$clientId"
Write-Host "AZURE_TENANT_ID=$TenantId"
Write-Host "AZURE_SUBSCRIPTION_ID=$SubscriptionId"
Write-Host "APP_OBJECT_ID=$appObjectId"
Write-Host "SERVICE_PRINCIPAL_OBJECT_ID=$spObjectId"
Write-Host "RESOURCE_GROUP_NAME=$ResourceGroupName"
Write-Host "RBAC_SCOPE=$scope"